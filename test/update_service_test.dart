import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/services/update_service.dart';

/// An [HttpClient] whose behaviour each test dictates.
///
/// The update check used to be untestable because the client was constructed
/// inline. Every failure mode here — a dead network, a stalled read, a 502, a
/// captive portal returning HTML — is reproduced by a fake rather than by
/// hoping a real network misbehaves at the right moment.
class _FakeClient implements HttpClient {
  _FakeClient({
    this.status = 200,
    this.body = '',
    this.throws,
    this.stall = false,
  });

  final int status;
  final String body;

  /// Thrown from `close()` instead of returning a response.
  final Object? throws;

  /// When true, the request never completes — the "connected but frozen" case.
  final bool stall;

  int calls = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    calls++;
    return _FakeRequest(this);
  }

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.client);

  final _FakeClient client;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Future<HttpClientResponse> close() async {
    if (client.stall) {
      // Never completes: models a connection that opened and then went quiet.
      return Completer<HttpClientResponse>().future;
    }
    if (client.throws != null) throw client.throws!;
    return _FakeResponse(client.status, client.body);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, String body)
      : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([_bytes]).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _releaseBody(String tag) => jsonEncode({
      'tag_name': tag,
      'html_url': 'https://github.com/mahimmazidul/throw/releases/tag/$tag',
    });

void main() {
  final shortDelay = const Duration(milliseconds: 1);

  UpdateService serviceWith(
    _FakeClient client, {
    Duration timeout = const Duration(milliseconds: 120),
    int attempts = 3,
  }) =>
      UpdateService(
        clientFactory: () => client,
        endpoint: 'https://example.test/releases/latest',
        timeout: timeout,
        attempts: attempts,
        retryDelay: shortDelay,
      );

  group('a healthy connection', () {
    test('returns the release', () async {
      final client = _FakeClient(body: _releaseBody('v1.4.0'));
      final result = await serviceWith(client).check();

      expect(result.ok, isTrue);
      expect(result.release!.tag, 'v1.4.0');
      // The leading v is stripped for comparison, not shown in the dialog.
      expect(result.release!.version, '1.4.0');
      expect(result.release!.url, contains('v1.4.0'));
    });
  });

  group('a stalled connection', () {
    test('resolves instead of hanging forever', () async {
      // THE reported bug: "update is broken even when connected". The old code
      // set `connectionTimeout` only, which covers the TCP handshake. Once
      // connected, reading the response had no deadline, so on a network that
      // opened a connection and then went quiet the spinner never stopped.
      final client = _FakeClient(stall: true);
      final result =
          await serviceWith(client, attempts: 1).check();

      expect(result.ok, isFalse,
          reason: 'a stalled check must produce an answer, not hang');
      expect(result.failure, isNotNull);
    });

    test('gives up after the configured number of attempts', () async {
      final client = _FakeClient(stall: true);
      await serviceWith(client, attempts: 3).check();

      // One initial attempt plus two retries.
      expect(client.calls, 3);
    });
  });

  group('transient failures', () {
    test('a 502 is retried, because a single bad minute is not a defect',
        () async {
      final client = _FakeClient(status: 502, body: '');
      await serviceWith(client, attempts: 3).check();
      expect(client.calls, 3);
    });

    test('a 429 rate limit is retried', () async {
      final client = _FakeClient(status: 429, body: '');
      await serviceWith(client, attempts: 2).check();
      expect(client.calls, 2);
    });
  });

  group('failures that will not improve with retrying', () {
    test('a missing release (404) is not retried', () async {
      final client = _FakeClient(status: 404, body: '');
      final result = await serviceWith(client).check();

      expect(client.calls, 1, reason: 'a 404 cannot become a 200');
      expect(result.failure, UpdateFailure.badResponse);
    });

    test('no network is reported as offline, once, without retrying',
        () async {
      final client = _FakeClient(throws: const SocketException('no route'));
      final result = await serviceWith(client).check();

      expect(client.calls, 1, reason: 'offline is an answer, not a fault');
      expect(result.failure, UpdateFailure.offline);
    });

    test('a captive portal returning HTML is a bad response, not a crash',
        () async {
      final client = _FakeClient(
        body: '<html><body>Sign in to the network</body></html>',
      );
      final result = await serviceWith(client).check();

      expect(result.ok, isFalse);
      expect(result.failure, UpdateFailure.badResponse);
    });

    test('JSON without a tag is rejected rather than read as up to date',
        () async {
      // An unreadable tag must never be treated as "no update available": that
      // would silently tell every user they are current forever.
      final client = _FakeClient(body: jsonEncode({'html_url': 'x'}));
      final result = await serviceWith(client).check();

      expect(result.ok, isFalse);
      expect(result.failure, UpdateFailure.badResponse);
    });

    test('a tag that is not a version is rejected', () async {
      final client = _FakeClient(body: _releaseBody('nightly-build'));
      final result = await serviceWith(client).check();
      expect(result.failure, UpdateFailure.badResponse);
    });
  });

  group('check() never throws', () {
    for (final failure in <Object>[
      const SocketException('down'),
      const HandshakeException('portal'),
      TimeoutException('slow'),
      const FormatException('bad json'),
      StateError('unexpected'),
    ]) {
      test('${failure.runtimeType} is classified', () async {
        final client = _FakeClient(throws: failure);
        final result = await serviceWith(client, attempts: 2).check();
        expect(result.ok, isFalse);
        expect(result.failure, isNotNull);
      });
    }
  });
}
