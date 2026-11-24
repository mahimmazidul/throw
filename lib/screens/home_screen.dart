import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/share_inbox_provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/accent_icon_badge.dart';
import '../widgets/device_picker.dart';
import '../widgets/error_banner.dart';
import '../widgets/received_items_list.dart';
import '../widgets/screen_header.dart';

/// Home: pick a peer, then throw something at it.
///
/// Structure follows the reference apps rather than the previous revision:
///
///  * the **peer** is the first object on the screen (LocalSend's device grid,
///    Android's share sheet), not a dropdown;
///  * the three payload kinds — text, files, share-sheet inbox — are peers of
///    each other under it, each with one primary action;
///  * what you **received** is one tab away, with copy/save/open, instead of
///    being collected into a provider nobody reads.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  DeviceModel? _selectedDevice;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _syncSelection(List<DeviceModel> connected) {
    if (_selectedDevice != null && !connected.contains(_selectedDevice)) {
      _selectedDevice = connected.isNotEmpty ? connected.first : null;
    } else if (_selectedDevice == null && connected.isNotEmpty) {
      _selectedDevice = connected.first;
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
    }
  }

  Future<void> _sendText(TransferProvider transferProvider) async {
    final target = _selectedDevice;
    final text = _textController.text.trim();
    if (target == null || text.isEmpty) return;
    await transferProvider.sendText(target, text);
    if (mounted) _textController.clear();
  }

  Future<void> _pickAndSendFiles(TransferProvider transferProvider) async {
    final target = _selectedDevice;
    if (target == null) return;

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      await transferProvider.sendFile(
        target,
        filePath: file.path!,
        fileName: file.name,
        sizeBytes: file.size,
      );
    }
  }

  Future<void> _sendSharedInbox(
    TransferProvider transferProvider,
    ShareInboxProvider shareInbox,
  ) async {
    final target = _selectedDevice;
    if (target == null || !shareInbox.hasPending) return;

    final items = List<SharedMediaFile>.from(shareInbox.sharedFiles);
    for (final item in items) {
      if (item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url) {
        final text = item.path.trim();
        if (text.isNotEmpty) await transferProvider.sendText(target, text);
        continue;
      }

      final file = File(item.path);
      if (!await file.exists()) continue;
      final size = await file.length();
      final name = item.path.split(RegExp(r'[/\\]')).last;
      await transferProvider.sendFile(
        target,
        filePath: file.path,
        fileName: name,
        sizeBytes: size,
      );
    }
    shareInbox.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deviceProvider = context.watch<DeviceProvider>();
    final transferProvider = context.watch<TransferProvider>();
    final shareInbox = context.watch<ShareInboxProvider>();
    final connected = deviceProvider.connectedDevices;

    _syncSelection(connected);
    final canSend = _selectedDevice != null;

    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.space5,
                AppConstants.space5,
                AppConstants.space5,
                AppConstants.space3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    title: l10n.appTitle,
                    subtitle: l10n.homeTagline,
                  ),
                  const SizedBox(height: AppConstants.space4),
                  if (connected.isEmpty)
                    _NoPeersCard(message: l10n.stateNoDevices)
                  else
                    DevicePicker(
                      devices: connected,
                      selected: _selectedDevice,
                      onSelected: (device) =>
                          setState(() => _selectedDevice = device),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.space3),
            TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.send_rounded, size: 18),
                  text: l10n.actionSend,
                ),
                Tab(
                  icon: const Icon(Icons.inbox_rounded, size: 18),
                  text: l10n.receivedTitle,
                ),
              ],
            ),
            if (transferProvider.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.space5,
                  AppConstants.space3,
                  AppConstants.space5,
                  0,
                ),
                child: ErrorBanner(
                  error: transferProvider.error!,
                  onDismiss: transferProvider.clearError,
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  _SendTab(
                    l10n: l10n,
                    theme: theme,
                    canSend: canSend,
                    textController: _textController,
                    onPaste: _pasteFromClipboard,
                    onSendText: () => _sendText(transferProvider),
                    onPickFiles: () => _pickAndSendFiles(transferProvider),
                    shareInbox: shareInbox,
                    onSendInbox: () =>
                        _sendSharedInbox(transferProvider, shareInbox),
                  ),
                  ReceivedItemsList(
                    payloads: transferProvider.receivedPayloads,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when nothing is connected: a single tile that says what to do next.
class _NoPeersCard extends StatelessWidget {
  const _NoPeersCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: ThrowRadius.card,
      ),
      child: Row(
        children: [
          const AccentIconBadge(icon: Icons.devices_rounded, size: 34),
          const SizedBox(width: AppConstants.space3),
          Expanded(
            child: Text(
              message,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendTab extends StatelessWidget {
  const _SendTab({
    required this.l10n,
    required this.theme,
    required this.canSend,
    required this.textController,
    required this.onPaste,
    required this.onSendText,
    required this.onPickFiles,
    required this.shareInbox,
    required this.onSendInbox,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool canSend;
  final TextEditingController textController;
  final VoidCallback onPaste;
  final VoidCallback onSendText;
  final VoidCallback onPickFiles;
  final ShareInboxProvider shareInbox;
  final VoidCallback onSendInbox;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.space5,
        AppConstants.space4,
        AppConstants.space5,
        AppConstants.space5,
      ),
      children: [
        if (!canSend) ...[
          const NoPeerHint(),
          const SizedBox(height: AppConstants.space3),
        ],
        if (shareInbox.hasPending) ...[
          _ShareInboxCard(
            l10n: l10n,
            theme: theme,
            shareInbox: shareInbox,
            enabled: canSend,
            onSend: onSendInbox,
          ),
          const SizedBox(height: AppConstants.space3),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.sendTextTitle,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppConstants.space2),
                TextField(
                  controller: textController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: l10n.sendClipboardHint,
                    filled: true,
                    fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.all(AppConstants.space3),
                    border: OutlineInputBorder(
                      borderRadius: ThrowRadius.card,
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.paste_rounded, size: 20),
                      tooltip: l10n.actionPaste,
                      onPressed: onPaste,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.space3),
                FilledButton.icon(
                  onPressed: canSend ? onSendText : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(l10n.actionSend),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.space3),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.space4),
            child: Row(
              children: [
                const AccentIconBadge(
                  icon: Icons.insert_drive_file_rounded,
                  size: 46,
                ),
                const SizedBox(width: AppConstants.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sendFilesTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.sendFilesHint,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.space2),
                FilledButton.tonalIcon(
                  onPressed: canSend ? onPickFiles : null,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(l10n.actionPick),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareInboxCard extends StatelessWidget {
  const _ShareInboxCard({
    required this.l10n,
    required this.theme,
    required this.shareInbox,
    required this.enabled,
    required this.onSend,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final ShareInboxProvider shareInbox;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final files = shareInbox.sharedFiles;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AccentIconBadge(
                  icon: Icons.inbox_rounded,
                  size: 34,
                  emphasis: BadgeEmphasis.solid,
                ),
                const SizedBox(width: AppConstants.space3),
                Expanded(
                  child: Text(
                    l10n.shareInboxTitle(files.length),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: l10n.actionClear,
                  visualDensity: VisualDensity.compact,
                  onPressed: shareInbox.clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.space2),
            ...files.take(3).map((f) {
              final isText =
                  f.type == SharedMediaType.text || f.type == SharedMediaType.url;
              final label = isText ? f.path : f.path.split(RegExp(r'[/\\]')).last;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppConstants.space1),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              );
            }),
            if (files.length > 3)
              Text(
                l10n.shareInboxMore(files.length - 3),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: AppConstants.space3),
            FilledButton.icon(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(l10n.shareInboxSend),
            ),
          ],
        ),
      ),
    );
  }
}
