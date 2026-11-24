import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/share_inbox_provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/device_picker.dart';
import '../widgets/entrance.dart';
import '../widgets/error_banner.dart';
import '../widgets/panel.dart';
import '../widgets/received_items_list.dart';
import '../widgets/screen_header.dart';

/// Home: pick a peer, then throw something at it.
///
/// Layout rules this screen follows, all taken from the references rather than
/// invented:
///
///  * no app icon — the window already says which app this is;
///  * no filled header band, no card around a card;
///  * grouping comes from spacing and one tinted surface per section
///    (Musify's settings runs, LocalSend's flush device tiles);
///  * the peer is the first object on the screen, not a dropdown;
///  * everything that can be tapped reacts to press (LocalSend's InkWell
///    feedback, Musify's AnimatedContainer selection), and sections enter
///    with a short stagger instead of appearing fully formed.
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
    final cs = theme.colorScheme;
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
                AppConstants.space2,
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
                    const NoPeerHint()
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
            const SizedBox(height: AppConstants.space2),
            TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.send_rounded, size: 17),
                  text: l10n.actionSend,
                ),
                Tab(
                  icon: const Icon(Icons.inbox_rounded, size: 17),
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
                    cs: cs,
                    canSend: canSend,
                    textController: _textController,
                    onPaste: _pasteFromClipboard,
                    onSendText: () => _sendText(transferProvider),
                    onPickFiles: () => _pickAndSendFiles(transferProvider),
                    shareInbox: shareInbox,
                    onSendInbox: () =>
                        _sendSharedInbox(transferProvider, shareInbox),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.space5,
                      AppConstants.space4,
                      AppConstants.space5,
                      0,
                    ),
                    child: ReceivedItemsList(
                      payloads: transferProvider.receivedPayloads,
                    ),
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

class _SendTab extends StatelessWidget {
  const _SendTab({
    required this.l10n,
    required this.theme,
    required this.cs,
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
  final ColorScheme cs;
  final bool canSend;
  final TextEditingController textController;
  final VoidCallback onPaste;
  final VoidCallback onSendText;
  final VoidCallback onPickFiles;
  final ShareInboxProvider shareInbox;
  final VoidCallback onSendInbox;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.space5,
        AppConstants.space4,
        AppConstants.space5,
        AppConstants.space6,
      ),
      children: [
        if (shareInbox.hasPending) ...[
          Entrance(
            child: _ShareInboxPanel(
              l10n: l10n,
              theme: theme,
              cs: cs,
              shareInbox: shareInbox,
              enabled: canSend,
              onSend: onSendInbox,
            ),
          ),
          const SizedBox(height: AppConstants.space4),
        ],
        // The three actions are rows on one surface, not three boxes: the
        // text composer, then two one-tap actions underneath.
        Entrance(
          delay: Motion.stagger * (shareInbox.hasPending ? 1 : 0),
          child: PanelGroup(
            header: l10n.homeSectionThrow,
            children: [
              _Composer(
                l10n: l10n,
                theme: theme,
                cs: cs,
                controller: textController,
                onPaste: onPaste,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.space4,
                  0,
                  AppConstants.space4,
                  AppConstants.space3,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _PrimaryAction(
                      enabled: canSend,
                      label: l10n.actionSend,
                      icon: Icons.send_rounded,
                      onPressed: onSendText,
                    ),
                  ],
                ),
              ),
              FlatRow(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: l10n.sendFilesTitle,
                subtitle: l10n.sendFilesHint,
                trailing: _PrimaryAction(
                  enabled: canSend,
                  label: l10n.actionPick,
                  icon: Icons.attach_file_rounded,
                  onPressed: onPickFiles,
                  tonal: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.controller,
    required this.onPaste,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final TextEditingController controller;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.space3),
      child: TextField(
        controller: controller,
        maxLines: 5,
        minLines: 2,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: l10n.sendClipboardHint,
          // No fill and no outline: the composer sits inside the panel as a
          // writing area, not as another filled shape competing with it. A
          // subtle underline on focus is all the affordance it needs.
          filled: false,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.space1,
            vertical: AppConstants.space2,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: cs.primary.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          suffixIcon: Pressable(
            child: IconButton(
              icon: const Icon(Icons.paste_rounded, size: 20),
              tooltip: l10n.actionPaste,
              color: ThrowTheme.accentFg(context),
              onPressed: onPaste,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one filled action per row, with press feedback on top of the button's
/// own state layer.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.enabled,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tonal = false,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? FilledButton(
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          )
        : (tonal
            ? FilledButton.tonalIcon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(icon, size: 17),
                label: Text(label),
              )
            : FilledButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(icon, size: 17),
                label: Text(label),
              ));
    return Pressable(enabled: enabled, child: child);
  }
}

class _ShareInboxPanel extends StatelessWidget {
  const _ShareInboxPanel({
    required this.l10n,
    required this.theme,
    required this.cs,
    required this.shareInbox,
    required this.enabled,
    required this.onSend,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final ColorScheme cs;
  final ShareInboxProvider shareInbox;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final files = shareInbox.sharedFiles;

    return PanelGroup(
      children: [
        FlatRow(
          leading: Icon(Icons.inbox_rounded, color: cs.onPrimaryContainer),
          title: l10n.shareInboxTitle(files.length),
          subtitle: files
              .take(2)
              .map((f) => f.type == SharedMediaType.text ||
                      f.type == SharedMediaType.url
                  ? f.path
                  : f.path.split(RegExp(r'[/\\]')).last)
              .join(' · '),
          trailing: Pressable(
            child: IconButton(
              tooltip: l10n.actionClear,
              visualDensity: VisualDensity.compact,
              onPressed: shareInbox.clear,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppConstants.space3),
          child: Pressable(
            enabled: enabled,
            child: FilledButton.icon(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded, size: 17),
              label: Text(l10n.shareInboxSend),
            ),
          ),
        ),
      ],
    );
  }
}
