import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/payload_model.dart';
import 'accent_icon_badge.dart';
import 'empty_state.dart';

/// The receive side of the product.
///
/// `TransferProvider.receivedPayloads` was filled correctly and rendered
/// nowhere: a file arrived, finished, and the user had no way to find it,
/// copy arrived text, or open the file. `open_file` was in the manifest's
/// dependency list and never called. This list is the missing surface — newest
/// first, copy for text, save/open for files, and an honest message when a
/// file's path is gone.
class ReceivedItemsList extends StatelessWidget {
  const ReceivedItemsList({super.key, required this.payloads});

  final List<PayloadModel> payloads;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (payloads.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_rounded,
        title: l10n.receivedEmptyTitle,
        body: l10n.receivedEmptyBody,
      );
    }

    final newestFirst = payloads.reversed.toList(growable: false);

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppConstants.space4),
      itemCount: newestFirst.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppConstants.space2),
      itemBuilder: (context, index) =>
          _ReceivedTile(payload: newestFirst[index]),
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({required this.payload});

  final PayloadModel payload;

  bool get _isText =>
      payload.kind == PayloadKind.text || payload.kind == PayloadKind.clipboard;

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: payload.text ?? ''));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.receivedActionCopied)));
  }

  Future<void> _openFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final path = payload.path;

    if (path == null || path.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.receivedShareMissing)));
      return;
    }
    if (!await File(path).exists()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.receivedShareMissing)));
      return;
    }

    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.receivedOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final title = _isText
        ? (payload.text ?? '').trim()
        : (payload.name ?? l10n.receivedTypeFile);
    final kindLabel = _isText ? l10n.receivedTypeText : l10n.receivedTypeFile;
    final sizeLabel = !_isText && payload.sizeBytes > 0
        ? AppUtils.formatBytes(payload.sizeBytes)
        : null;
    final meta = [
      kindLabel,
      if (sizeLabel != null) sizeLabel,
      AppUtils.formatRelativeTime(payload.createdAt, DateTime.now()),
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: ThrowRadius.card,
        onTap: _isText ? () => _copy(context) : () => _openFile(context),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccentIconBadge(
                icon: _isText
                    ? Icons.notes_rounded
                    : Icons.insert_drive_file_rounded,
                size: 40,
              ),
              const SizedBox(width: AppConstants.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: _isText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.space1),
              if (_isText)
                IconButton(
                  tooltip: l10n.receivedActionCopy,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  color: ThrowTheme.accentFg(context),
                  onPressed: () => _copy(context),
                )
              else
                IconButton(
                  tooltip: l10n.receivedActionOpenFile,
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  color: ThrowTheme.accentFg(context),
                  onPressed: () => _openFile(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
