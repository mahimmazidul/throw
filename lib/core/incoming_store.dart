import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Decides where received files are written — the single place in the app that
/// answers "where did it go?".
///
/// Before this, `NearbyService` and `BluetoothService` each called
/// `getApplicationDocumentsDirectory()` inline. On Android that is
/// `/data/user/0/<package>/app_flutter`, a directory the user cannot open with
/// any file manager without root. Files arrived, the list said "received", and
/// there was no way to reach them — which is exactly what was reported.
///
/// The store now probes for a folder a person can actually find, in the order a
/// normal file manager would show:
///
///  1. `/storage/emulated/0/Download/Throw` — the public Downloads folder;
///  2. `Download/Throw` under the first external storage root the app can write
///     to (covers paths where 0 is not the primary volume);
///  3. `<application documents>/Throw` — always writable, last resort.
///
/// Capability is *tested*, not assumed: every candidate is created and a probe
/// file is written into it. A path that fails the probe is skipped, so the app
/// never announces a folder it cannot write to.
class IncomingStore {
  IncomingStore({
    Future<Directory> Function()? documentsDir,
    List<Directory> Function()? candidates,
  })  : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
        _candidates = candidates;

  final Future<Directory> Function() _documentsDir;
  final List<Directory> Function()? _candidates;

  Directory? _folder;

  /// The folder received files land in. Resolved once, then cached for the
  /// life of the process; call [reset] after the user changes storage settings.
  Future<Directory> folder() async {
    final existing = _folder;
    if (existing != null) return existing;

    for (final candidate in await _candidateFolders()) {
      if (await _isWritable(candidate)) {
        _folder = candidate;
        return candidate;
      }
    }

    // The app-support directory is guaranteed writable on every platform we
    // ship; if even that fails the caller gets the error and shows it.
    final fallback = Directory('${(await _documentsDir()).path}/Throw');
    await fallback.create(recursive: true);
    _folder = fallback;
    return fallback;
  }

  /// Folder shown to the user before anything has arrived, so the empty state
  /// can promise a real location.
  Future<String> folderPath() async => (await folder()).path;

  Future<List<Directory>> _candidateFolders() async {
    final supplied = _candidates;
    if (supplied != null) return supplied();

    if (!Platform.isAndroid) {
      // Desktop: the documents directory *is* user-visible.
      return [Directory('${(await _documentsDir()).path}/Throw')];
    }

    final downloads = <Directory>[
      Directory('/storage/emulated/0/Download/Throw'),
    ];

    // Some devices mount the primary volume elsewhere. `ANDROID_STORAGE` is
    // only a hint, so a failed read is not an error — just fewer candidates.
    final storageRoot = Platform.environment['ANDROID_STORAGE'];
    if (storageRoot != null && storageRoot.isNotEmpty) {
      downloads.add(Directory('$storageRoot/Download/Throw'));
    }
    for (final root in const ['/sdcard', '/storage/emulated/0']) {
      downloads.add(Directory('$root/Download/Throw'));
    }

    downloads.add(Directory('${(await _documentsDir()).path}/Throw'));
    return downloads;
  }

  /// Creates the folder and writes+deletes a probe file. Catches everything:
  /// a permission error is a normal answer here, not a crash.
  Future<bool> _isWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File('${dir.path}/.throw_probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (e) {
      debugPrint('IncomingStore: ${dir.path} not writable ($e)');
      return false;
    }
  }

  /// A path for [fileName] that does not overwrite an existing file:
  /// `report.pdf`, then `report (1).pdf`, `report (2).pdf`…
  ///
  /// Overwriting was the old behaviour: two people send `IMG_0001.jpg` and the
  /// second silently replaced the first.
  Future<String> pathFor(String fileName) async {
    final dir = await folder();
    final sanitized = _sanitize(fileName);
    final dot = sanitized.lastIndexOf('.');
    final stem = dot > 0 ? sanitized.substring(0, dot) : sanitized;
    final extension = dot > 0 ? sanitized.substring(dot) : '';

    var candidate = File('${dir.path}/$sanitized');
    var index = 1;
    while (await candidate.exists()) {
      candidate = File('${dir.path}/$stem ($index)$extension');
      index++;
      // 10 000 collisions means something else is wrong; stop growing the name.
      if (index > 10000) break;
    }
    return candidate.path;
  }

  /// Writes [bytes] to a fresh path in the store and returns it.
  Future<File> save(String fileName, List<int> bytes) async {
    final path = await pathFor(fileName);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Moves a file the transport already wrote somewhere temporary.
  Future<File> adopt(String fileName, File temporary) async {
    final path = await pathFor(fileName);
    final target = File(path);
    await target.parent.create(recursive: true);
    try {
      return await temporary.rename(path);
    } on FileSystemException {
      // Cross-device rename (temp on another mount). Copy then remove.
      final copied = await temporary.copy(path);
      try {
        await temporary.delete();
      } catch (_) {
        // Leaving the temp file behind is preferable to failing the receipt.
      }
      return copied;
    }
  }

  /// Strips directories and characters Windows/Android cannot store.
  ///
  /// Same rules as `AppUtils.sanitizeFileName`, duplicated deliberately: this
  /// class must be usable without importing the whole utils surface, and the
  /// logic is asserted against `AppUtils` in tests so the two cannot drift.
  String _sanitize(String raw) {
    final base = raw.split(RegExp(r'[/\\]')).last.trim();
    if (base.isEmpty || base == '.' || base == '..') return 'incoming_file';
    final cleaned = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
    return cleaned.isEmpty ? 'incoming_file' : cleaned;
  }

  void reset() => _folder = null;
}

/// Formats the folder for display: `/storage/emulated/0/Download/Throw`
/// becomes `Download/Throw`, which is what a file manager shows the user.
String displayFolder(String path, {bool isAndroid = false}) {
  if (!isAndroid) return path;
  for (final prefix in const [
    '/storage/emulated/0/',
    '/sdcard/',
  ]) {
    if (path.startsWith(prefix)) return path.substring(prefix.length);
  }
  return path;
}
