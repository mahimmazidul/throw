import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Owns every temporary copy Throw is responsible for, and guarantees each one
/// is deleted once the transfer that needed it is over.
///
/// ## The leak this exists to fix
///
/// Sending a file from the Android share sheet does not hand the app the user's
/// file. `receive_sharing_intent` copies it into the app's cache directory
/// first — its own documentation says "All files are copied to a temp cache
/// folder" — and nothing in Throw ever deleted that copy. The File Picker does
/// the same into `cacheDir/file_picker/…`, and its `clearTemporaryFiles()` was
/// never called. So every shared photo left a second full-size copy behind,
/// forever, whether the transfer succeeded or failed. A phone that shared a
/// 200 MB video five times was 1 GB down with nothing to show for it.
///
/// ## The rule
///
/// A copy is kept **only while a transfer that uses it is alive**:
///
///  * a path is registered when the share or pick is accepted;
///  * it is released the moment its transfer reaches a terminal state —
///    completed, failed, cancelled or rejected. Failure is the case that
///    matters: it used to leak exactly like success;
///  * anything still registered at launch is released, because nothing can be
///    in flight before the app has started.
///
/// ## The safety rule
///
/// [takeOwnership] registers a path **only if it lives inside a cache
/// directory**. A path the user actually owns — the real `DCIM/Camera/x.jpg`
/// that the desktop pickers return, or a file in Documents — is never
/// registered and therefore can never be deleted by this class. Deleting a
/// user's original would be a far worse bug than the leak.
class TempFileRegistry {
  TempFileRegistry({
    Future<Directory> Function()? cacheDir,
    Future<Directory> Function()? supportDir,
  })  : _cacheDir = cacheDir ?? getTemporaryDirectory,
        _supportDir = supportDir ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _cacheDir;
  final Future<Directory> Function() _supportDir;

  static const String _registryName = 'throw_temp_files.json';

  /// path → (byte size, live claims). A path is deleted when its claim count
  /// reaches zero, which is what lets the share inbox and an in-flight send
  /// both hold the same copy without either one deleting it underneath the
  /// other.
  final Map<String, ({int size, int claims})> _entries = {};
  bool _loaded = false;

  Future<File> _registryFile() async =>
      File('${(await _supportDir()).path}/$_registryName');

  /// Loads the registry from disk. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _registryFile();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final size = entry.value;
        if (size is int) _entries[entry.key] = (size: size, claims: 0);
      }
    } catch (_) {
      // A corrupt registry must not stop the app; the files it would have
      // named are cache files, and a failed read just means one startup sweep
      // is less precise.
    }
  }

  Future<void> _persist() async {
    try {
      final file = await _registryFile();
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({for (final e in _entries.entries) e.key: e.value.size}),
        flush: true,
      );
      await tmp.rename(file.path);
    } catch (_) {
      // Best effort: the in-memory copy still drives deletion this run.
    }
  }

  /// True when [path] sits inside a cache directory and is therefore ours to
  /// delete.
  ///
  /// Checked with a resolved path prefix, not a name heuristic, so a user file
  /// that merely *looks* temporary is never touched.
  Future<bool> isThrowOwned(String path) async {
    try {
      final cache = (await _cacheDir()).absolute.path;
      final target = File(path).absolute.path;
      return target.startsWith('$cache/');
    } catch (_) {
      return false;
    }
  }

  /// Registers [path] for deletion later, if and only if Throw owns it.
  ///
  /// Returns true when the path was taken over. A false return means the file
  /// belongs to the user and this class will never delete it.
  Future<bool> takeOwnership(String path) async {
    await load();
    if (!await isThrowOwned(path)) return false;
    final existing = _entries[path];
    if (existing != null) {
      // Another holder (the inbox, or a second device in a fan-out) already
      // claimed it; one more claim means it survives until both are done.
      _entries[path] = (size: existing.size, claims: existing.claims + 1);
      await _persist();
      return true;
    }
    int size;
    try {
      final file = File(path);
      size = await file.exists() ? await file.length() : 0;
    } catch (_) {
      size = 0;
    }
    _entries[path] = (size: size, claims: 1);
    await _persist();
    return true;
  }

  /// Drops one claim on [path], deleting the file once no claims remain. A
  /// path that is no longer registered, or whose file is already gone, is not
  /// an error.
  Future<void> release(String path) async {
    await load();
    final entry = _entries[path];
    if (entry == null) return;
    if (entry.claims > 1) {
      _entries[path] = (size: entry.size, claims: entry.claims - 1);
      await _persist();
      return;
    }
    _entries.remove(path);
    await _deleteQuietly(path);
    await _persist();
  }

  /// Deletes every copy registered for [paths], ignoring any that were never
  /// ours.
  Future<void> releaseAll(Iterable<String> paths) async {
    if (paths.isEmpty) return;
    await load();
    var changed = false;
    for (final path in paths.toSet()) {
      final entry = _entries[path];
      if (entry == null) continue;
      if (entry.claims > 1) {
        _entries[path] = (size: entry.size, claims: entry.claims - 1);
      } else {
        _entries.remove(path);
        await _deleteQuietly(path);
      }
      changed = true;
    }
    if (changed) await _persist();
  }

  /// Deletes everything registered. Called once at launch: nothing can be
  /// mid-transfer before the process has started, so every survivor is debris
  /// from a previous run.
  Future<int> releaseEverything() async {
    await load();
    final paths = _entries.keys.toList();
    _entries.clear();
    for (final path in paths) {
      await _deleteQuietly(path);
    }
    await _persist();
    return paths.length;
  }

  /// Empties the File Picker's own cache directory.
  ///
  /// The plugin writes every picked file into `cacheDir/file_picker/<ts>/…`
  /// and exposes `clearTemporaryFiles()` for exactly this. It also catches
  /// picks made by versions of Throw that never called it, which is how an
  /// upgraded install gets its space back.
  Future<int> clearPickerCache() async {
    try {
      final dir = Directory('${(await _cacheDir()).path}/file_picker');
      if (!await dir.exists()) return 0;
      final bytes = await _sizeOfTree(dir);
      await dir.delete(recursive: true);
      return bytes;
    } catch (e) {
      debugPrint('TempFileRegistry: could not clear picker cache ($e)');
      return 0;
    }
  }

  /// Bytes held by this registry plus the File Picker cache — what the Storage
  /// row in Settings reports.
  Future<int> usedBytes() async {
    await load();
    var total = _entries.values.fold<int>(0, (sum, e) => sum + e.size);
    try {
      final dir = Directory('${(await _cacheDir()).path}/file_picker');
      if (await dir.exists()) total += await _sizeOfTree(dir);
    } catch (_) {
      // Reporting is advisory; a failed measurement is just a smaller number.
    }
    return total;
  }

  /// Paths currently held. Exposed for tests and for the Storage row.
  List<String> get trackedPaths => List.unmodifiable(_entries.keys);

  Future<int> _sizeOfTree(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // A file that vanished mid-walk simply contributes nothing.
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      // The picker nests each pick in its own timestamped directory; removing
      // the file leaves an empty folder behind for every send.
      final parent = file.parent;
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (e) {
      debugPrint('TempFileRegistry: could not delete $path ($e)');
    }
  }
}
