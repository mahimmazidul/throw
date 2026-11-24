import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/temp_files.dart';

/// Holds files/text shared into Throw from other apps (Android share sheet).
///
/// ## Owns the copies
///
/// `receive_sharing_intent` writes every shared file into the app's cache
/// directory before handing over a path — its own API docs say so. Those copies
/// are the sender's storage, and until now nothing ever removed them: sharing a
/// video left a second full-size copy behind even when the transfer failed.
///
/// This provider therefore reports the paths it is holding ([pendingPaths])
/// so the transfer that uses them can release them when it reaches any
/// terminal state, and it releases them itself when the user clears the inbox
/// or the app shuts down. Nothing outside a cache directory is ever registered
/// (see [TempFileRegistry.takeOwnership]).
class ShareInboxProvider extends ChangeNotifier {
  ShareInboxProvider({TempFileRegistry? tempFiles})
      : _tempFiles = tempFiles ?? TempFileRegistry();

  final TempFileRegistry _tempFiles;

  final List<SharedMediaFile> _sharedFiles = [];
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;
  bool _initialized = false;

  List<SharedMediaFile> get sharedFiles => List.unmodifiable(_sharedFiles);
  bool get hasPending => _sharedFiles.isNotEmpty;

  /// Cache paths currently held for these shared items.
  List<String> get pendingPaths => [
        for (final file in _sharedFiles)
          if (file.type != SharedMediaType.text &&
              file.type != SharedMediaType.url)
            file.path,
      ];

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (values) {
        if (values.isEmpty) return;
        accept(values);
      },
      onError: (err) {
        debugPrint('Share intent media stream error: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((values) {
      if (values.isEmpty) return;
      accept(values);
      ReceiveSharingIntent.instance.reset();
    }).catchError((err) {
      debugPrint('Share intent initial media error: $err');
    });
  }

  /// Takes in a share. The plugin calls this through [initialize]; it is
  /// public so the intake path — including the cleanup of a previous share —
  /// can be tested without an Android device.
  ///
  /// Swaps in the new share, releasing the copies of the previous one unless
  /// they are still being sent, in which case the transfer's own release
  /// claims. Holding the old list would strand its files.
  void accept(List<SharedMediaFile> values) {
    final previous = pendingPaths;
    _sharedFiles
      ..clear()
      ..addAll(values);
    unawaited(_register(values));
    if (previous.isNotEmpty) {
      // releaseAll is a no-op for anything the transfer already released, and
      // for anything that was never ours.
      unawaited(_tempFiles.releaseAll(previous));
    }
    notifyListeners();
  }

  Future<void> _register(List<SharedMediaFile> values) async {
    for (final file in values) {
      if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
        continue;
      }
      await _tempFiles.takeOwnership(file.path);
    }
  }

  /// Drops the inbox *and* deletes the copies behind it.
  ///
  /// Ownership is reference-counted: if a send is still reading one of these
  /// paths it keeps its claim and the file survives until that send ends.
  void clear() {
    if (_sharedFiles.isEmpty) return;
    final paths = pendingPaths;
    _sharedFiles.clear();
    unawaited(_tempFiles.releaseAll(paths));
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _sharedFiles.length) return;
    final removed = _sharedFiles.removeAt(index);
    if (removed.type != SharedMediaType.text &&
        removed.type != SharedMediaType.url) {
      unawaited(_tempFiles.release(removed.path));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // The app is going away with un-sent items: delete the copies rather than
    // leaving them for the next launch (which would release them anyway, but
    // doing it now returns the space immediately).
    unawaited(_tempFiles.releaseAll(pendingPaths));
    _mediaSub?.cancel();
    super.dispose();
  }
}
