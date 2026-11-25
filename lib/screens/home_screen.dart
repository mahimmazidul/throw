import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/atmosphere.dart';
import '../core/constants.dart';
import '../core/incoming_store.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';
import '../providers/device_provider.dart';
import '../providers/share_inbox_provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/depth_button.dart';
import '../widgets/entrance.dart';
import '../widgets/error_banner.dart';
import '../widgets/no_peer_hint.dart';
import '../widgets/panel.dart';
import '../widgets/received_items_list.dart';
import '../widgets/screen_header.dart';

/// Home: pick who receives it, then send text or files.
///
/// The flow a person actually has in their head:
///
///  1. *Who am I sending to?* — the connected devices, always visible at the
///     top, multi-selectable. Nothing is hidden behind a dropdown, and nothing
///     is preselected on the user's behalf.
///  2. *What am I sending?* — one writing area with one send button, and one
///     attach action. There used to be a "Send" button for text *and* a
///     separate "Pick" button in a row underneath, which read as two competing
///     primaries and wrapped to two lines on a phone.
///  3. *Did it arrive?* — the newest receipts appear directly under the send
///     area, with the folder they were saved in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final Set<String> _selectedIds = {};

  /// Devices the user explicitly unticked. Without this, an auto-selection
  /// rule would fight the user: they deselect a phone, the next rebuild puts
  /// it straight back.
  final Set<String> _deselected = {};

  String? _folderLabel;

  @override
  void initState() {
    super.initState();
    _resolveFolder();
  }

  Future<void> _resolveFolder() async {
    try {
      final path = await IncomingStore().folderPath();
      if (!mounted) return;
      setState(() {
        _folderLabel = displayFolder(path, isAndroid: Platform.isAndroid);
      });
    } catch (_) {
      // The folder label is a convenience; failing to resolve it must not stop
      // sending.
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Keeps the selection honest when devices connect and disconnect.
  ///
  /// A device that has just become available is selected automatically. This
  /// is the whole reason someone connects a phone — to send it something — and
  /// leaving the Send button dead until they find the tick circle is a dead
  /// end, not a choice. An explicit untick is remembered and respected.
  void _syncSelection(List<DeviceModel> connected) {
    final ids = connected.map((d) => d.id).toSet();
    // Forget devices that went away, so a later reconnection starts fresh.
    _selectedIds.removeWhere((id) => !ids.contains(id));
    _deselected.removeWhere((id) => !ids.contains(id));

    for (final device in connected) {
      if (_deselected.contains(device.id)) continue;
      _selectedIds.add(device.id);
    }
  }

  List<DeviceModel> _selectedDevices(List<DeviceModel> connected) =>
      connected.where((d) => _selectedIds.contains(d.id)).toList();

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _textController.text = data.text!;
    }
  }

  Future<void> _sendText(
    TransferProvider transfers,
    List<DeviceModel> targets,
  ) async {
    final text = _textController.text.trim();
    if (targets.isEmpty || text.isEmpty) return;
    final sent = await transfers.sendTextTo(targets, text);
    if (!mounted) return;
    if (sent > 0) _textController.clear();
    _reportFanOut(context, sent, targets.length);
  }

  Future<void> _pickAndSendFiles(
    TransferProvider transfers,
    List<DeviceModel> targets,
  ) async {
    if (targets.isEmpty) return;

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    final files = <({String path, String name, int size})>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      files.add((path: file.path!, name: file.name, size: file.size));
    }
    if (files.isEmpty) return;

    final sent = await transfers.sendFilesTo(targets, files: files);
    if (!mounted) return;
    _reportFanOut(context, sent, targets.length * files.length);
  }

  void _reportFanOut(BuildContext context, int sent, int total) {
    if (sent == total || total == 0) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            sent == 0 ? l10n.sendPartlyFailed : l10n.sentToCount(sent, total),
          ),
        ),
      );
  }

  Future<void> _sendSharedInbox(
    TransferProvider transfers,
    ShareInboxProvider shareInbox,
    List<DeviceModel> targets,
  ) async {
    if (targets.isEmpty || !shareInbox.hasPending) return;

    final items = List<SharedMediaFile>.from(shareInbox.sharedFiles);
    for (final item in items) {
      if (item.type == SharedMediaType.text ||
          item.type == SharedMediaType.url) {
        final text = item.path.trim();
        if (text.isNotEmpty) await transfers.sendTextTo(targets, text);
        continue;
      }

      final file = File(item.path);
      if (!await file.exists()) continue;
      final size = await file.length();
      final name = item.path.split(RegExp(r'[/\\]')).last;
      await transfers.sendFileTo(
        targets,
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
    final transfers = context.watch<TransferProvider>();
    final shareInbox = context.watch<ShareInboxProvider>();

    final connected = deviceProvider.connectedDevices;
    _syncSelection(connected);
    final selected = _selectedDevices(connected);
    final canSend = selected.isNotEmpty;
    final receipts = transfers.receivedPayloads;

    // The canvas drifts while the screen is at rest. It is switched off the
    // moment there is something to read (an error), because ambient motion
    // behind a message is noise competing with the message.
    return AmbientBackdrop(
      intensity: transfers.error != null ? 0 : 1,
      child: SafeArea(
      child: Center(
        // One measure for the whole screen. Without it the composer and its
        // Send button ran the full width of a 1280dp desktop window — the
        // button sat a thousand pixels from the text just typed — and prose
        // lines were 1200px long. 720dp holds a comfortable measure and keeps
        // a control next to the thing it acts on. Every screen uses the same
        // value so the app has one column width, not four.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.contentMax),
          child: Column(
            // `stretch` so children get a bounded cross-axis constraint; without
            // it a `Text(maxLines: 1)` in the header can size the row to its
            // intrinsic width and overflow a narrow window.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.space5,
                  AppConstants.space5,
                  AppConstants.space5,
                  AppConstants.space3,
                ),
                child: ScreenHeader(
                  title: connected.isEmpty ? l10n.appTitle : l10n.sendTo,
                  subtitle: connected.isEmpty ? l10n.homeTagline : null,
                  trailing: connected.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => setState(() {
                            _selectedIds.clear();
                          }),
                          child: Text(l10n.actionClear),
                        ),
                ),
              ),
              Expanded(
                child: Center(
                  // Without a measure limit the composer ran the full width of a
                  // 1280dp desktop window, so the Send button sat a thousand
                  // pixels away from the text just typed, and prose lines were
                  // 1200px long. A single readable column is what every desktop
                  // app worth copying does.
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: AppConstants.contentMax),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.space4,
                        0,
                        AppConstants.space4,
                        AppConstants.space6,
                      ),
                      children: [
                        // 1 — who.
                        if (connected.isEmpty)
                          const NoPeerHint()
                        else
                          Entrance(
                            child: _PeerSection(
                              devices: connected,
                              selectedIds: _selectedIds,
                              onToggle: (device) => setState(() {
                                if (_selectedIds.remove(device.id)) {
                                  _deselected.add(device.id);
                                } else {
                                  _selectedIds.add(device.id);
                                  _deselected.remove(device.id);
                                }
                              }),
                            ),
                          ),
                        const SizedBox(height: AppConstants.space5),

                        // 2 — what.
                        Entrance(
                          delay: Motion.stagger,
                          child: _SendSection(
                            l10n: l10n,
                            controller: _textController,
                            canSend: canSend,
                            hasPeers: connected.isNotEmpty,
                            targetCount: selected.length,
                            onPaste: _pasteFromClipboard,
                            onSendText: () => _sendText(transfers, selected),
                            onPickFiles: () =>
                                _pickAndSendFiles(transfers, selected),
                          ),
                        ),

                        if (shareInbox.hasPending) ...[
                          const SizedBox(height: AppConstants.space4),
                          Entrance(
                            delay: Motion.stagger * 2,
                            child: Section(
                              header: l10n.shareInboxTitle(
                                  shareInbox.sharedFiles.length),
                              children: [
                                FlatRow(
                                  leading: const Icon(Icons.inbox_rounded),
                                  title: shareInbox.sharedFiles
                                      .take(2)
                                      .map((f) =>
                                          f.path.split(RegExp(r'[/\\]')).last)
                                      .join(' · '),
                                  subtitle: canSend ? null : l10n.sendTo,
                                  trailing: Pressable(
                                    child: IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: l10n.actionClear,
                                      onPressed: shareInbox.clear,
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18),
                                    ),
                                  ),
                                  onTap: canSend
                                      ? () => _sendSharedInbox(
                                            transfers,
                                            shareInbox,
                                            selected,
                                          )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (transfers.error != null) ...[
                          const SizedBox(height: AppConstants.space4),
                          ErrorBanner(
                            error: transfers.error!,
                            onDismiss: transfers.clearError,
                          ),
                        ],

                        // 3 — did it arrive, and where.
                        const SizedBox(height: AppConstants.space5),
                        Entrance(
                          delay: Motion.stagger * 3,
                          child: Section(
                            header: l10n.receivedTitle,
                            footer:
                                receipts.isEmpty ? null : l10n.receivedCaption,
                            children: [
                              if (receipts.isEmpty)
                                FlatRow(
                                  leading: const Icon(Icons.inbox_rounded),
                                  title: l10n.receivedEmptyTitle,
                                  subtitle: _folderLabel == null
                                      ? l10n.receivedEmptyBody
                                      : l10n.receivedEmptyWhere(_folderLabel!),
                                  titleMaxLines: 2,
                                  subtitleMaxLines: 3,
                                )
                              else
                                for (final payload
                                    in receipts.reversed.take(4).toList())
                                  _ReceiptRow(payload: payload),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Connected peers, selectable, always in view.
class _PeerSection extends StatelessWidget {
  const _PeerSection({
    required this.devices,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<DeviceModel> devices;
  final Set<String> selectedIds;
  final ValueChanged<DeviceModel> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Section(
      header: devices.length > 1
          ? l10n.selectedCount(selectedIds.length)
          : l10n.stateConnected,
      footer: devices.length > 1 ? l10n.selectPeersHint : null,
      children: [
        for (final device in devices)
          FlatRow(
            leading: Icon(switch (device.platform) {
              DevicePlatform.android => Icons.phone_android_rounded,
              DevicePlatform.windows => Icons.desktop_windows_rounded,
              DevicePlatform.linux => Icons.laptop_mac_rounded,
              DevicePlatform.unknown => Icons.devices_other_rounded,
            }),
            title: device.displayName,
            subtitle: device.channel == TransferChannel.wifiDirect
                ? l10n.speedWifi
                : l10n.speedBluetooth,
            trailing: _SelectMark(selected: selectedIds.contains(device.id)),
            onTap: () => onToggle(device),
          ),
      ],
    );
  }
}

/// A check that animates in and out — the affordance and the feedback are the
/// same object, so there is nothing to explain.
class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Motion.adapt(context, Motion.fast),
      curve: Motion.curve,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: Motion.adapt(context, Motion.fast),
        curve: Motion.curve,
        child: Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
      ),
    );
  }
}

/// One writing area, one primary action, one attach action.
class _SendSection extends StatelessWidget {
  const _SendSection({
    required this.l10n,
    required this.controller,
    required this.canSend,
    required this.hasPeers,
    required this.targetCount,
    required this.onPaste,
    required this.onSendText,
    required this.onPickFiles,
  });

  final AppLocalizations l10n;
  final TextEditingController controller;
  final bool canSend;
  final bool hasPeers;
  final int targetCount;
  final VoidCallback onPaste;
  final VoidCallback onSendText;
  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The composer is a text field, not a filled shape: no surface, no
        // outline, no competing rectangle.
        TextField(
          controller: controller,
          maxLines: 6,
          minLines: 3,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          decoration: InputDecoration(
            hintText: l10n.composerHint,
            filled: false,
            isCollapsed: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space1,
              vertical: AppConstants.space2,
            ),
            suffixIcon: Pressable(
              child: IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 19),
                tooltip: l10n.actionPaste,
                color: ThrowTheme.accentFg(context),
                onPressed: onPaste,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.space2),
        Row(
          children: [
            // Attach: icon + label in one control, and *only* this control in
            // its row, so it can never be squeezed into a two-line label.
            Pressable(
              enabled: canSend,
              child: TextButton.icon(
                onPressed: canSend ? onPickFiles : null,
                icon: const Icon(Icons.attach_file_rounded, size: 19),
                label: Text(l10n.sendFilesTitle),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.space3,
                    vertical: AppConstants.space2,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Pressable(
              enabled: canSend,
              child: DepthButton(
                onPressed: canSend ? onSendText : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                child: Text(
                  targetCount > 1
                      ? l10n.sendToCount(targetCount)
                      : l10n.actionSend,
                ),
              ),
            ),
          ],
        ),
        // When there is genuinely no peer, `NoPeerHint` above already says
        // how to get one — repeating the same sentence here was noise. This
        // line only covers the case the hint cannot: peers exist, none is
        // ticked.
        if (!canSend && hasPeers)
          Padding(
            padding: const EdgeInsets.only(top: AppConstants.space1),
            child: Text(
              l10n.homePickDeviceFirst,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// A compact receipt on Home: what arrived, from whom, and where it is.
class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.payload});

  final PayloadModel payload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final folder = payload.path == null
        ? null
        : displayFolder(
            AppUtils.folderOf(payload.path!),
            isAndroid: Platform.isAndroid,
          );

    return FlatRow(
      leading: Icon(
        payload.isFile ? Icons.insert_drive_file_rounded : Icons.notes_rounded,
      ),
      title: payload.label,
      subtitle: [
        if (payload.senderName != null && payload.senderName!.isNotEmpty)
          l10n.fromDevice(payload.senderName!),
        if (folder != null) l10n.savedToFolder(folder),
      ].join(' · '),
      titleMaxLines: payload.isFile ? 1 : 2,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: null,
    );
  }
}
