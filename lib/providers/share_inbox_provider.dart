import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Holds files/text shared into Throw from other apps (Android share sheet).
class ShareInboxProvider extends ChangeNotifier {
  final List<SharedMediaFile> _sharedFiles = [];
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;
  bool _initialized = false;

  List<SharedMediaFile> get sharedFiles => List.unmodifiable(_sharedFiles);
  bool get hasPending => _sharedFiles.isNotEmpty;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (values) {
        if (values.isEmpty) return;
        _sharedFiles
          ..clear()
          ..addAll(values);
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Share intent media stream error: $err');
      },
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((values) {
      if (values.isEmpty) return;
      _sharedFiles
        ..clear()
        ..addAll(values);
      notifyListeners();
      ReceiveSharingIntent.instance.reset();
    }).catchError((err) {
      debugPrint('Share intent initial media error: $err');
    });
  }

  void clear() {
    if (_sharedFiles.isEmpty) return;
    _sharedFiles.clear();
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _sharedFiles.length) return;
    _sharedFiles.removeAt(index);
    notifyListeners();
  }

  @override
  void dispose() {
    _mediaSub?.cancel();
    super.dispose();
  }
}
