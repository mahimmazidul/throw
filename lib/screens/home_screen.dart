import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deviceProvider = context.watch<DeviceProvider>();
    final transferProvider = context.watch<TransferProvider>();
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
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.navHome,
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (connected.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.devices_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.stateNoDevices,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                border: const OutlineInputBorder(),
              ),
              items: connected
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedDevice = value),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.sendClipboardHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste_rounded),
                        tooltip: l10n.actionPaste,
                        onPressed: _pasteFromClipboard,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _selectedDevice == null
                        ? null
                        : () => _sendText(transferProvider),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(l10n.actionSend),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.16),
                child: Icon(
                  Icons.folder_open_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(l10n.actionSend),
              subtitle: Text(
                l10n.speedWifi,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: FilledButton.tonalIcon(
                onPressed: _selectedDevice == null
                    ? null
                    : () => _pickAndSendFiles(transferProvider),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(l10n.actionSend),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
