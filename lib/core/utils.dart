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

  /// Compact relative timestamp for received items: `now`, `3 min ago`,
  /// `2 hr ago`, `5 d ago`, then a `dd MMM` date for anything older.
  ///
  /// Received payloads always carried a `createdAt` and no surface ever showed
  /// it — without a timestamp a list of received files cannot answer "is this
  /// the one from today?".
  static String formatRelativeTime(DateTime time, DateTime now) {
    final delta = now.difference(time);
    if (delta.isNegative || delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
    if (delta.inHours < 24) return '${delta.inHours} hr ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${time.day} ${months[time.month - 1]}';
  }

  /// True when [latest] is a strictly newer dotted version than [current].
  ///
  /// Lived as a private method inside `SettingsScreen`, where no test could
  /// reach it. Version comparison is the one piece of logic in the update
  /// checker that can silently un-ship a release, so it lives here now.
  /// Tolerates `v` prefixes, build metadata and non-numeric tails (`1.2.3+4`).
  static bool isNewerVersion(String latest, String current) {
    // Build metadata and any leading `v` are not part of the dotted version.
    // Splitting on '.' first used to turn `1.0.16+3` into patch `16`, which
    // silently compared equal to `1.0.16` — a release tagged with a build
    // number would never be offered as an update.
    List<int> parse(String v) => v
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0)
        .toList();
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
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
