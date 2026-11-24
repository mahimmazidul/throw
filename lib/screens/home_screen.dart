import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/share_inbox_provider.dart';
import '../providers/transfer_provider.dart';

/// Home screen for quick text/clipboard and file sharing.
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
    _textController.clear();
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

    if (_selectedDevice != null && !connected.contains(_selectedDevice)) {
      _selectedDevice = connected.isNotEmpty ? connected.first : null;
    } else if (_selectedDevice == null && connected.isNotEmpty) {
      _selectedDevice = connected.first;
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              // Flat tint, no gradient — one token, one edge, no radiant wash.
              color: theme.colorScheme.primaryContainer,
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/logo.png', width: 44, height: 44),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Throw', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            'Send files and text directly to nearby devices.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      icon: connected.isNotEmpty ? Icons.link_rounded : Icons.link_off_rounded,
                      label: connected.isNotEmpty ? '${connected.length} connected' : 'No device connected',
                      active: connected.isNotEmpty,
                    ),
                    const _StatusChip(icon: Icons.wifi_tethering_rounded, label: 'WiFi Direct / Bluetooth', active: true),
                    const _StatusChip(icon: Icons.shield_outlined, label: 'Direct local sharing', active: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (connected.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                      child: Icon(Icons.devices_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.stateNoDevices,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            DropdownButtonFormField<DeviceModel>(
              initialValue: _selectedDevice,
              decoration: InputDecoration(
                labelText: l10n.stateConnected,
                prefixIcon: const Icon(Icons.devices_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: connected.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
              onChanged: (value) => setState(() => _selectedDevice = value),
            ),
          if (shareInbox.hasPending) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inbox_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Shared to Throw (${shareInbox.sharedFiles.length})', style: theme.textTheme.titleMedium)),
                        IconButton(tooltip: 'Clear', onPressed: shareInbox.clear, icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...shareInbox.sharedFiles.take(3).map((f) {
                      final isText = f.type == SharedMediaType.text || f.type == SharedMediaType.url;
                      final label = isText ? f.path : f.path.split(RegExp(r'[/\\]')).last;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      );
                    }),
                    if (shareInbox.sharedFiles.length > 3)
                      Text('+${shareInbox.sharedFiles.length - 3} more',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _selectedDevice == null ? null : () => _sendSharedInbox(transferProvider, shareInbox),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Send shared items'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send text', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.sendClipboardHint,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded),
                        tooltip: l10n.actionPaste,
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selectedDevice == null ? null : () => _sendText(transferProvider),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(l10n.actionSend),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.14),
                    child: Icon(Icons.insert_drive_file_rounded, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Send files', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Pick multiple files and send directly to the selected device.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _selectedDevice == null ? null : () => _pickAndSendFiles(transferProvider),
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Pick'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label, required this.active});
  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = active
        ? theme.colorScheme.primary.withValues(alpha: 0.14)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final fg = active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
