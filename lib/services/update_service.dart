import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';

/// What GitHub says the newest release is.
class ReleaseInfo {
  const ReleaseInfo({required this.tag, required this.url});

  /// The raw tag, e.g. `v1.3.2`.
  final String tag;

  /// The release page, for the "Open release" action.
  final String url;

  /// The tag without its leading `v`.
  String get version => tag.startsWith('v') ? tag.substring(1) : tag;
}

/// Why an update check did not produce an answer.
enum UpdateFailure {
  /// The device has no usable network. Not an error, an answer.
  offline,

  /// GitHub answered, but not with something we can read.
  badResponse,

  /// Everything else.
  unknown,
}

/// The outcome of a check: either a release, or a reason there isn't one.
class UpdateResult {
  const UpdateResult.found(this.release) : failure = null;
  const UpdateResult.failed(this.failure) : release = null;

  final ReleaseInfo? release;
  final UpdateFailure? failure;

  bool get ok => release != null;
}

/// Checks GitHub for a newer release.
///
/// ## Why this exists as its own class
///
/// The check used to be forty lines inside the settings screen, built around a
/// bare `HttpClient`. Three things were wrong with that, and together they are
/// "update is broken even when connected":
///
///  1. **Only the connect was timed out.** `connectionTimeout` covers the TCP
///     handshake. Once connected, `request.close()` and reading the body had no
///     deadline at all. On a slow or captive network — a hotel portal, a phone
///     tether, mobile data that accepted the connection then stalled — the
///     spinner stayed up indefinitely and the check never resolved. Standing
///     there "connected" with an infinite spinner is exactly the report.
///
///  2. **One attempt, no retry.** GitHub's API returns 5xx under load and
///     rate-limits bursts of anonymous requests. A single transient failure was
///     reported to the user as a permanent defect. This build's own release CD
///     hit a 502 from that same API, so it is not hypothetical.
///
///  3. **Untestable.** It lived in `build()`-adjacent UI code, so the only way
///     to exercise it was to run the app and watch. Every failure mode here is
///     now driven by an injected [HttpClient] in tests.
///
/// [check] never throws: every failure is classified, so the caller renders a
/// human sentence rather than an exception string.
class UpdateService {
  UpdateService({
    HttpClient Function()? clientFactory,
    this.endpoint,
    this.timeout = const Duration(seconds: 12),
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 600),
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  /// Full endpoint. Overridden in tests.
  final String? endpoint;

  /// Deadline for the *whole* exchange, connect included. This is the fix for
  /// the endless spinner: no matter what the network does, the check resolves.
  final Duration timeout;

  /// How many times to try before giving up. Retries only transient faults.
  final int attempts;

  /// Base delay between attempts; grows linearly so a struggling API is not
  /// hammered.
  final Duration retryDelay;

  final HttpClient Function() _clientFactory;

  String get _url =>
      endpoint ??
      'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest';

  /// Ask GitHub for the latest release. Never throws.
  Future<UpdateResult> check() async {
    UpdateFailure? lastFailure;

    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(retryDelay * attempt);
      }

      final result = await _attemptOnce();
      if (result.ok) return result;

      lastFailure = result.failure;
      // Offline means offline: retrying a missing network just makes the user
      // wait three times as long for the same true answer.
      if (lastFailure == UpdateFailure.offline) return result;
      // A bad body will be equally bad next time; only transient faults retry.
      if (lastFailure == UpdateFailure.badResponse) return result;
    }

    return UpdateResult.failed(lastFailure ?? UpdateFailure.unknown);
  }

  Future<UpdateResult> _attemptOnce() async {
    final client = _clientFactory();
    try {
      // `.timeout` wraps the entire future, not just the connection. This is
      // the line that makes the spinner stop.
      final response = await () async {
        final request = await client.getUrl(Uri.parse(_url));
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        // GitHub rejects requests without one.
        request.headers.set(HttpHeaders.userAgentHeader, 'Throw-App');
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        return (response.statusCode, body);
      }()
          .timeout(timeout);

      final (status, body) = response;

      if (status == 200) {
        final parsed = _parse(body);
        return parsed == null
            ? const UpdateResult.failed(UpdateFailure.badResponse)
            : UpdateResult.found(parsed);
      }

      // 5xx and 429 are worth another try; 404 means the release genuinely is
      // not there and a retry cannot change that.
      if (status >= 500 || status == 429) {
        return const UpdateResult.failed(UpdateFailure.unknown);
      }
      return const UpdateResult.failed(UpdateFailure.badResponse);
    } on TimeoutException {
      return const UpdateResult.failed(UpdateFailure.unknown);
    } on SocketException {
      // No route, no DNS, no host. This is the offline answer.
      return const UpdateResult.failed(UpdateFailure.offline);
    } on HandshakeException {
      // A captive portal intercepting TLS. Reads to the user as "no network".
      return const UpdateResult.failed(UpdateFailure.offline);
    } on HttpException {
      return const UpdateResult.failed(UpdateFailure.unknown);
    } on FormatException {
      // jsonDecode on a non-JSON body.
      return const UpdateResult.failed(UpdateFailure.badResponse);
    } catch (_) {
      return const UpdateResult.failed(UpdateFailure.unknown);
    } finally {
      client.close(force: true);
    }
  }

  ReleaseInfo? _parse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      // A captive portal's HTML login page, a truncated response, anything that
      // is not JSON. Classified by the caller as a bad response, not a crash.
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final tag = (decoded['tag_name'] as String?)?.trim() ?? '';
    if (tag.isEmpty) return null;
    final url =
        (decoded['html_url'] as String?)?.trim() ?? AppConstants.releasesUrl;
    // Refuse to guess at a version we cannot read: an unparsable tag would make
    // the comparison silently report "up to date" forever.
    if (RegExp(r'^\d').firstMatch(tag.replaceFirst(RegExp('^v'), '')) == null) {
      return null;
    }
    return ReleaseInfo(tag: tag, url: url);
  }
}
