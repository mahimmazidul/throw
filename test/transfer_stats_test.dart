import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/transfer_stats.dart';

/// A clock the test drives by hand.
class Clock {
  DateTime now = DateTime(2026, 11, 24, 12);
  DateTime call() => now;
  void advance(Duration d) => now = now.add(d);
}

/// Speed and ETA are the numbers a user judges a transfer by, and the ones
/// easiest to get wrong: divide by a zero interval and you show "Infinity
/// MB/s"; trust a rewinding counter and you show a negative speed.
void main() {
  group('rate', () {
    test('is zero until a second sample arrives', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call);
      tracker.sample(1000);
      // One sample anchors the clock; reporting a rate here would be invented.
      expect(tracker.bytesPerSecond, 0);
    });

    test('measures bytes per second across an interval', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call, smoothing: 1.0);
      tracker.sample(0);
      clock.advance(const Duration(seconds: 1));
      tracker.sample(2 * 1024 * 1024);
      expect(tracker.bytesPerSecond, closeTo(2 * 1024 * 1024, 1));
    });

    test('samples inside the minimum interval are folded, not divided by ~0',
        () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call, smoothing: 1.0);
      tracker.sample(0);
      // 1 ms is too short to divide by; this used to produce absurd rates.
      clock.advance(const Duration(milliseconds: 1));
      tracker.sample(999999);
      expect(tracker.bytesPerSecond, 0);
      expect(tracker.bytesPerSecond.isFinite, isTrue);

      // The next real sample measures the bytes moved since the folded one.
      clock.advance(const Duration(seconds: 1));
      tracker.sample(999999 + 1024);
      expect(tracker.bytesPerSecond, closeTo(1024, 2));
    });

    test('a rewinding counter never yields a negative rate', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call, smoothing: 1.0);
      tracker.sample(0);
      clock.advance(const Duration(seconds: 1));
      tracker.sample(5000);
      expect(tracker.bytesPerSecond, greaterThan(0));

      // The transport restarted the payload and reports from zero.
      clock.advance(const Duration(seconds: 1));
      tracker.sample(0);
      expect(tracker.bytesPerSecond, greaterThanOrEqualTo(0));

      clock.advance(const Duration(seconds: 1));
      tracker.sample(1000);
      expect(tracker.bytesPerSecond, closeTo(1000, 1));
    });

    test('smoothing damps a single slow chunk', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call, smoothing: 0.35);
      tracker.sample(0);
      clock.advance(const Duration(seconds: 1));
      tracker.sample(1000);
      final afterFast = tracker.bytesPerSecond;

      // One very slow second does not collapse the displayed rate to ~0.
      clock.advance(const Duration(seconds: 1));
      tracker.sample(1010);
      expect(tracker.bytesPerSecond, greaterThan(afterFast * 0.5));
    });

    test('negative byte counts are clamped', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call, smoothing: 1.0);
      tracker.sample(-500);
      clock.advance(const Duration(seconds: 1));
      tracker.sample(-100);
      expect(tracker.bytesPerSecond, 0);
    });
  });

  group('ETA', () {
    test('is null before a rate is known', () {
      final tracker = TransferRateTracker(clock: Clock().call);
      expect(tracker.etaFor(1000), isNull);
      expect(TransferRateTracker.etaFrom(1000, 0), isNull);
    });

    test('is null at or past the end', () {
      expect(TransferRateTracker.etaFrom(0, 1000), isNull);
      expect(TransferRateTracker.etaFrom(-5, 1000), isNull);
    });

    test('divides remaining bytes by the rate', () {
      final eta = TransferRateTracker.etaFrom(500, 100);
      expect(eta, const Duration(seconds: 5));
    });

    test('refuses an absurd ETA rather than showing a day and a half', () {
      // 1 byte/second with 1 GB left would be 34 years.
      expect(TransferRateTracker.etaFrom(1024 * 1024 * 1024, 1), isNull);
    });
  });

  group('average', () {
    test('uses the whole elapsed window, not the last burst', () {
      final clock = Clock();
      final tracker = TransferRateTracker(clock: clock.call);
      tracker.sample(0);
      clock.advance(const Duration(seconds: 4));
      tracker.sample(4000);
      expect(tracker.averageBytesPerSecond(4000), closeTo(1000, 1));
    });

    test('is zero with no elapsed time', () {
      final tracker = TransferRateTracker(clock: Clock().call);
      expect(tracker.averageBytesPerSecond(100), 0);
    });
  });

  group('estimateRate', () {
    test('derives a rate from size and duration', () {
      expect(estimateRate(2048, const Duration(seconds: 2)), closeTo(1024, 0.01));
    });

    test('is zero for a zero-length transfer', () {
      expect(estimateRate(0, const Duration(seconds: 2)), 0);
      expect(estimateRate(1000, Duration.zero), 0);
    });
  });
}
