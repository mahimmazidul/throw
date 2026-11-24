import 'dart:math' as math;

/// Measures bytes/second and estimates time remaining.
///
/// The transfer services report cumulative byte counts in bursts (Nearby sends
/// an update per chunk, BLE per write). A rate taken from the last two numbers
/// would flicker between 0 and 40 MB/s, so this keeps an exponentially smoothed
/// rate over a short window and a monotonic clock.
///
/// Pure Dart with an injectable clock: the arithmetic is where an ETA goes
/// wrong (divide by a near-zero elapsed, negative bytes after a rewind), and
/// tests can drive it without sleeping.
class TransferRateTracker {
  TransferRateTracker({
    DateTime Function()? clock,
    this.smoothing = 0.35,
    this.minElapsed = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Weight of each new sample. 0.35 settles in roughly a second without
  /// jumping on a single slow chunk.
  final double smoothing;

  /// A sample taken sooner than this is folded into the next one — at 60 Hz
  /// the elapsed time is too small to divide by.
  final Duration minElapsed;

  DateTime? _startedAt;
  DateTime? _sampleAt;
  int _lastBytes = 0;
  double _rate = 0;

  /// Bytes/second, smoothed. Zero until at least one usable sample exists.
  double get bytesPerSecond => _rate;

  /// Monotonic byte count; a transport that reports a lower number than last
  /// time (reconnect, resend) must not produce a negative speed.
  int _clampBytes(int bytes) => bytes < 0 ? 0 : bytes;

  /// Feeds a cumulative byte count. Safe to call as often as you like.
  void sample(int bytes) {
    final now = _clock();
    final value = _clampBytes(bytes);
    _startedAt ??= now;
    final last = _sampleAt;
    if (last == null) {
      // First sample only anchors the clock: there is no interval to divide by
      // yet, and reporting a rate here would mean inventing one.
      _sampleAt = now;
      _lastBytes = value;
      return;
    }

    final elapsed = now.difference(last);
    if (elapsed < minElapsed) {
      _lastBytes = value;
      return;
    }

    final deltaBytes = value - _lastBytes;
    // A rewind (peer resent from zero) resets the baseline rather than
    // producing a negative rate.
    if (deltaBytes < 0) {
      _lastBytes = value;
      _sampleAt = now;
      return;
    }

    final instant = deltaBytes / (elapsed.inMicroseconds / 1e6);
    _rate = _rate == 0 ? instant : _rate + smoothing * (instant - _rate);
    _lastBytes = value;
    _sampleAt = now;
  }

  /// Seconds remaining to move [remainingBytes] at the current rate, or null
  /// when the rate is not known yet. Never negative, never infinite.
  Duration? etaFor(int remainingBytes) =>
      etaFrom(remainingBytes, _rate);

  /// The same arithmetic without an instance — used by widgets that hold a
  /// rate on the model rather than a tracker.
  static Duration? etaFrom(int remainingBytes, double bytesPerSecond) {
    if (bytesPerSecond <= 0 || remainingBytes <= 0) return null;
    final seconds = remainingBytes / bytesPerSecond;
    if (!seconds.isFinite || seconds > const Duration(hours: 12).inSeconds) {
      return null;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Elapsed time since the first sample.
  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    return _clock().difference(start);
  }

  /// Average over the whole transfer — the number worth showing once it is
  /// finished, when an instantaneous rate means nothing.
  double averageBytesPerSecond(int totalBytes) {
    final seconds = elapsed.inMicroseconds / 1e6;
    if (seconds <= 0 || totalBytes <= 0) return 0;
    return math.min(totalBytes / seconds, double.infinity);
  }
}

/// Rolling estimate used by the UI when a service could not measure one (for
/// example receiving a payload where the transport only reports completion).
///
/// Derives a rate from the payload size and the transfer's wall-clock duration
/// so the user still sees a number rather than a blank.
double estimateRate(int bytes, Duration elapsed) {
  final seconds = elapsed.inMicroseconds / 1e6;
  if (seconds <= 0 || bytes <= 0) return 0;
  return bytes / seconds;
}
