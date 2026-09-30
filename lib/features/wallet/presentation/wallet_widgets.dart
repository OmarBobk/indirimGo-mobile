import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:indirimgo_mobile/core/theme/app_theme.dart';
import 'package:indirimgo_mobile/features/wallet/domain/wallet_models.dart';
import 'package:intl/intl.dart' hide TextDirection;

enum WalletStatusTone { success, pending, rejected, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final WalletStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (foreground, background) = switch (tone) {
      WalletStatusTone.success => (
        const Color(0xFF15803D),
        isDark
            ? const Color(0xFF15803D).withValues(alpha: 0.18)
            : const Color(0xFFF0FDF4),
      ),
      WalletStatusTone.pending => (
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        isDark
            ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
            : const Color(0xFFFEF3C7),
      ),
      WalletStatusTone.rejected => (
        isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        isDark
            ? const Color(0xFFFCA5A5).withValues(alpha: 0.14)
            : const Color(0xFFFEF2F2),
      ),
      WalletStatusTone.neutral => (
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
        isDark
            ? const Color(0xFFCBD5E1).withValues(alpha: 0.12)
            : const Color(0xFFF1F5F9),
      ),
    };

    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class CopyableField extends StatelessWidget {
  const CopyableField({
    super.key,
    required this.label,
    required this.value,
    required this.copyTooltip,
    required this.copiedMessage,
  });

  final String label;
  final String value;
  final String copyTooltip;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    final valueDirection = Bidi.detectRtlDirectionality(value)
        ? TextDirection.rtl
        : TextDirection.ltr;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: BrandColors.mutedSlate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    textDirection: valueDirection,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: copyTooltip,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(copiedMessage)));
              },
              icon: const Icon(Icons.content_copy_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class BankOptionCard extends StatelessWidget {
  const BankOptionCard({
    super.key,
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.accountLabel,
    required this.instructionsLabel,
    required this.copyTooltip,
    required this.copiedMessage,
  });

  final PaymentMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String accountLabel;
  final String instructionsLabel;
  final String copyTooltip;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected
              ? BrandColors.yellow.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
                )
              : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? BrandColors.yellow : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected && theme.brightness == Brightness.light
              ? const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? BrandColors.yellow
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.account_balance_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        method.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Radio<int>(
                      value: method.id,
                      groupValue: selected ? method.id : null,
                      onChanged: enabled ? (_) => onTap() : null,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            children: [
                              CopyableField(
                                label: accountLabel,
                                value: method.name,
                                copyTooltip: copyTooltip,
                                copiedMessage: copiedMessage,
                              ),
                              if (method.instructions case final details?) ...[
                                const SizedBox(height: 10),
                                CopyableField(
                                  label: instructionsLabel,
                                  value: details,
                                  copyTooltip: copyTooltip,
                                  copiedMessage: copiedMessage,
                                ),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FileUploadDropzone extends StatelessWidget {
  const FileUploadDropzone({
    super.key,
    required this.proof,
    required this.enabled,
    required this.title,
    required this.body,
    required this.takePhotoLabel,
    required this.chooseLibraryLabel,
    required this.removeTooltip,
    required this.onTakePhoto,
    required this.onChooseLibrary,
    required this.onRemove,
  });

  final SelectedTopupProof? proof;
  final bool enabled;
  final String title;
  final String body;
  final String takePhotoLabel;
  final String chooseLibraryLabel;
  final String removeTooltip;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseLibrary;
  final VoidCallback onRemove;

  bool get _isImage {
    final filename = proof?.filename.toLowerCase() ?? '';
    return proof?.bytes != null &&
        (filename.endsWith('.jpg') ||
            filename.endsWith('.jpeg') ||
            filename.endsWith('.png') ||
            filename.endsWith('.webp'));
  }

  @override
  Widget build(BuildContext context) {
    final selectedProof = proof;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedProof == null
              ? Theme.of(context).dividerColor
              : BrandColors.yellow,
        ),
      ),
      child: selectedProof == null
          ? Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: BrandColors.yellow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrandColors.mutedSlate,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('topup-take-photo'),
                      onPressed: enabled ? onTakePhoto : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(takePhotoLabel),
                    ),
                    OutlinedButton.icon(
                      key: const Key('topup-choose-proof'),
                      onPressed: enabled ? onChooseLibrary : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(chooseLibraryLabel),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: _isImage
                        ? Image.memory(
                            Uint8List.fromList(selectedProof.bytes!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_outlined, size: 32),
                          )
                        : ColoredBox(
                            color: BrandColors.yellow.withValues(alpha: 0.12),
                            child: const Icon(
                              Icons.insert_drive_file_outlined,
                              size: 32,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedProof.filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('topup-remove-proof'),
                  tooltip: removeTooltip,
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
    );
  }
}
