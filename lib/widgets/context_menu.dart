import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/note_utils.dart';

Future<void> showNoteContextMenu(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final rootContext = context;
  final url = extractFirstUrl(note.content);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colors = sheetContext.sparkColors;
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuItem(
                icon: note.isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                label: note.isPinned ? 'Unpin' : 'Pin',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(notesProvider).togglePin(note);
                },
              ),
              _MenuItem(
                icon: LucideIcons.edit,
                label: 'Edit',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(rootContext).pushNamed('/edit', arguments: note);
                },
              ),
              _MenuItem(
                icon: LucideIcons.copy,
                label: 'Copy',
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Clipboard.setData(ClipboardData(text: note.content));
                },
              ),
              if (url != null) ...[
                _MenuItem(
                  icon: LucideIcons.link,
                  label: 'Copy link',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Clipboard.setData(ClipboardData(text: url));
                  },
                ),
                _MenuItem(
                  icon: LucideIcons.externalLink,
                  label: 'Open link',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final uri = Uri.parse(url);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              _MenuItem(
                icon: LucideIcons.trash2,
                label: 'Move to trash',
                isDestructive: true,
                showDivider: false,
                onTap: () async {
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
        InkWell(
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
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.border,
          ),
      ],
    );
  }
}
