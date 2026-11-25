import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/incoming_store.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/payload_model.dart';

/// The receive side of the product.
///
/// The complaint that drove this file's second rewrite: "it shows received but
/// saved where." Each receipt now states its folder in plain words, offers
/// open / save-a-copy / copy-path, and the empty state names the folder that
/// future files will land in — so the answer exists before the first transfer.
class ReceivedItemsList extends StatelessWidget {
  const ReceivedItemsList({
    super.key,
    required this.payloads,
    this.folderLabel,
    this.onShowFolder,
  });

  final List<PayloadModel> payloads;

  /// User-facing folder name, e.g. `Download/Throw`. Resolved by the caller
  /// (async) and passed down; null while it is still resolving.
  final String? folderLabel;

  /// Opens the folder in the platform file manager, when the platform allows.
  final VoidCallback? onShowFolder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (payloads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: AppConstants.space4),
        children: [
          const SizedBox(height: AppConstants.space6),
          Icon(
            Icons.inbox_rounded,
            size: 34,
            color: ThrowTheme.accentFg(context),
          ),
          const SizedBox(height: AppConstants.space4),
          Text(
            l10n.receivedEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppConstants.space2),
          if (folderLabel != null)
            Text(
              l10n.receivedEmptyWhere(folderLabel!),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.45),
            ),
        ],
      );
    }

    final newestFirst = payloads.reversed.toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppConstants.space4),
      children: [
        if (folderLabel != null)
          Padding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.space3,
              top: AppConstants.space1,
            ),
            child: Pressable(
              enabled: onShowFolder != null,
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 17,
                    color: ThrowTheme.accentFg(context),
                  ),
                  const SizedBox(width: AppConstants.space2),
                  Expanded(
                    child: Text(
                      l10n.receivedSavedIn(folderLabel!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  if (onShowFolder != null) ...[
                    const SizedBox(width: AppConstants.space2),
                    Text(
                      l10n.actionOpenFolder,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ThrowTheme.accentFg(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        for (var i = 0; i < newestFirst.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          _ReceivedRow(payload: newestFirst[i]),
        ],
      ],
    );
  }
}

class _ReceivedRow extends StatelessWidget {
  const _ReceivedRow({required this.payload});

  final PayloadModel payload;

  bool get _isText => !payload.isFile;

  Future<void> _copyText(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: payload.text ?? ''));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.receivedActionCopied)));
  }

  Future<void> _copyPath(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (payload.path == null) return;
    await Clipboard.setData(ClipboardData(text: payload.path!));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.receivedPathCopied)));
  }

  Future<void> _openFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final path = payload.path;

    if (path == null || path.isEmpty || !await File(path).exists()) {
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

  /// Hands the file (or the text) to the system share sheet.
  ///
  /// This is the other half of "can it share with other apps": Throw has always
  /// been able to *receive* a share, but a file that arrived had no way out to
  /// a chat app, a mail draft or a cloud client except by finding it in the
  /// filesystem first. `open_file` covers "show me this"; this covers "send it
  /// on", which is what people actually do with a file they just received.
  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (_isText) {
      await SharePlus.instance.share(ShareParams(text: payload.text ?? ''));
      return;
    }

    final path = payload.path;
    if (path == null || path.isEmpty || !await File(path).exists()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.receivedShareMissing)));
      return;
    }
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: payload.label),
      );
      if (result.status == ShareResultStatus.unavailable) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(l10n.receivedShareNoTarget)),
          );
      }
    } catch (_) {
      // A platform with no share sheet (some Linux desktops) throws rather
      // than reporting `unavailable`.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.receivedShareNoTarget)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final title = payload.label;
    final kindLabel = _isText ? l10n.receivedTypeText : l10n.receivedTypeFile;
    final sizeLabel = !_isText && payload.sizeBytes > 0
        ? AppUtils.formatBytes(payload.sizeBytes)
        : null;

    final meta = [
      if (payload.senderName != null && payload.senderName!.isNotEmpty)
        l10n.fromDevice(payload.senderName!),
      kindLabel,
      if (sizeLabel != null) sizeLabel,
      AppUtils.formatRelativeTime(payload.createdAt, DateTime.now()),
    ].join(' · ');

    return InkWell(
      splashColor: cs.primary.withValues(alpha: 0.08),
      onTap: _isText ? () => _copyText(context) : () => _openFile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.space1,
          vertical: AppConstants.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                _isText ? Icons.notes_rounded : Icons.insert_drive_file_rounded,
                size: 22,
                color: ThrowTheme.accentFg(context),
              ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ThrowColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.space1),
            // Two actions for a file — open and copy its location — because
            // "I can see it but I cannot find it" was the actual complaint.
            Pressable(
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _isText
                    ? l10n.receivedActionCopy
                    : l10n.receivedActionCopyPath,
                icon: Icon(
                  _isText ? Icons.copy_rounded : Icons.link_rounded,
                  size: 19,
                ),
                color: ThrowTheme.accentFg(context),
                onPressed:
                    _isText ? () => _copyText(context) : () => _copyPath(context),
              ),
            ),
            // "Send it on" — the share sheet, for text and files alike.
            Pressable(
              child: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.receivedActionShare,
                icon: const Icon(Icons.ios_share_rounded, size: 19),
                color: ThrowTheme.accentFg(context),
                onPressed: () => _share(context),
              ),
            ),
            if (!_isText)
              Pressable(
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.receivedActionOpenFile,
                  icon: const Icon(Icons.open_in_new_rounded, size: 19),
                  color: ThrowTheme.accentFg(context),
                  onPressed: () => _openFile(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Display helper re-exported for the Home screen's receipt strip.
String receiptFolderLabel(String path) => displayFolder(
      AppUtils.folderOf(path),
      isAndroid: Platform.isAndroid,
    );
