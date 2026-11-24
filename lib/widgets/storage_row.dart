import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/temp_files.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import 'panel.dart';

/// Shows what Throw is currently holding in temporary copies, and lets the
/// user clear them.
///
/// This is the visible half of the storage fix. A transfer now releases its
/// copy the moment it ends, so the honest steady state is "Nothing held" — but
/// a user who just lost a large file to a failed send should be able to
/// confirm the space came back rather than take it on faith.
class StorageRow extends StatefulWidget {
  const StorageRow({super.key});

  @override
  State<StorageRow> createState() => _StorageRowState();
}

class _StorageRowState extends State<StorageRow> {
  int? _bytes;

  /// The nav bar keeps every tab alive in an `IndexedStack`, so this widget is
  /// built once and never disposed. Without re-measuring on each visit the row
  /// would keep showing the number it read the first time Settings was opened —
  /// stale the moment a transfer ends.
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `TickerMode` is false for the tabs the IndexedStack is hiding, which is
    // exactly the signal for "the user just came back to this screen".
    final visible = TickerMode.of(context);
    if (visible && !_visible) {
      _visible = true;
      _measure();
    } else if (!visible) {
      _visible = false;
    }
  }

  Future<void> _measure() async {
    final registry = context.read<TempFileRegistry>();
    final bytes = await registry.usedBytes();
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  Future<void> _clear() async {
    final registry = context.read<TempFileRegistry>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await registry.releaseEverything();
    await registry.clearPickerCache();
    if (!mounted) return;
    setState(() => _bytes = 0);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.settingsStorageCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bytes = _bytes;
    final held = bytes != null && bytes > 0;

    return FlatRow(
      leading: const Icon(Icons.storage_rounded),
      title: l10n.settingsStorage,
      subtitle: bytes == null
          ? l10n.settingsStorageEmpty
          : held
              ? l10n.settingsStorageInUse(AppUtils.formatBytes(bytes))
              : l10n.settingsStorageEmpty,
      trailingText: held ? l10n.settingsStorageClear : null,
      onTap: held ? _clear : null,
    );
  }
}
