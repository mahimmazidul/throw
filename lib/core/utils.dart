/// Shared formatting and sanitization utilities for Throw.
class AppUtils {
  AppUtils._();

  /// Formats a byte count into a human-readable string (e.g. `12.4 MB`).
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024.0;
    var unitIndex = 0;
    while (value >= 1024.0 && unitIndex < units.length - 1) {
      value /= 1024.0;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unitIndex]}';
  }

  /// Formats transfer speed in bytes/second (e.g. `24.5 MB/s`).
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// Formats a [Duration] into `mm:ss` or `hh:mm:ss`.
  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Sanitizes an incoming file name to prevent path traversal.
  static String sanitizeFileName(String raw) {
    final base = raw.split(RegExp(r'[/\\]')).last.trim();
    if (base.isEmpty || base == '.' || base == '..') {
      return 'incoming_file';
    }
    return base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
  }
}
