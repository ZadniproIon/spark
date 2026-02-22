import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/audio_download.dart';
import '../utils/haptics.dart';
import '../utils/note_utils.dart';

Future<void> showNoteContextMenu(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final rootContext = context;
  final urls = extractUrls(note.content);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = sheetContext.sparkColors;
      return SafeArea(
        bottom: false,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(
                icon: note.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                label: note.isPinned ? 'Unpin' : 'Pin',
                onTap: () async {
                  triggerHapticFromContext(
                    sheetContext,
                    note.isPinned ? HapticLevel.light : HapticLevel.medium,
                  );
                  Navigator.of(sheetContext).pop();
                  await ref.read(notesProvider).togglePin(note);
                },
              ),
              _MenuItem(
                icon: LucideIcons.edit,
                label: 'Edit',
                onTap: () {
                  triggerHapticFromContext(sheetContext, HapticLevel.light);
                  Navigator.of(sheetContext).pop();
                  Navigator.of(rootContext).pushNamed('/edit', arguments: note);
                },
              ),
              _MenuItem(
                icon: LucideIcons.copy,
                label: 'Copy',
                onTap: () async {
                  triggerHapticFromContext(sheetContext, HapticLevel.selection);
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: note.content));
                },
              ),
              if (note.type == NoteType.voice &&
                  (note.audioPath != null || note.audioUrl != null))
                _MenuItem(
                  icon: LucideIcons.download,
                  label: 'Save to Downloads',
                  onTap: () async {
                    triggerHapticFromContext(sheetContext, HapticLevel.light);
                    Navigator.of(sheetContext).pop();
                    final source = await ref
                        .read(notesProvider)
                        .resolveVoiceSource(note);
                    if (!rootContext.mounted) {
                      return;
                    }
                    if (source == null || source.isEmpty) {
                      return;
                    }
                    await saveVoiceNoteToDownloads(
                      context: rootContext,
                      source: source,
                      fileNameBase: 'spark-voice-${note.id}',
                    );
                  },
                ),
              if (urls.isNotEmpty) _LinkSection(urls: urls),
              _MenuItem(
                icon: LucideIcons.trash2,
                label: 'Move to trash',
                isDestructive: true,
                showDivider: false,
                onTap: () async {
                  triggerHapticFromContext(sheetContext, HapticLevel.heavy);
                  Navigator.of(sheetContext).pop();
                  await ref.read(notesProvider).moveToTrash(note);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({required this.urls});

  final List<String> urls;

  String _labelForUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : url;
      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return host;
      }
      final trimmed = path.length > 18 ? '${path.substring(0, 18)}…' : path;
      return '$host$trimmed';
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < urls.length; i++) ...[
          _LinkRow(url: urls[i], label: _labelForUrl(urls[i])),
          Divider(height: 1, thickness: 1, color: colors.border),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.secondary.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          _LinkAction(
            icon: LucideIcons.copy,
            onTap: () async {
              triggerHapticFromContext(context, HapticLevel.selection);
              await Clipboard.setData(ClipboardData(text: url));
            },
          ),
          const SizedBox(width: 8),
          _LinkAction(
            icon: LucideIcons.externalLink,
            onTap: () async {
              triggerHapticFromContext(context, HapticLevel.light);
              final uri = Uri.parse(url);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final color = isDestructive ? colors.red : colors.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: AppTextStyles.primary.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, thickness: 1, color: colors.border),
      ],
    );
  }
}
