import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
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
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [AppShadows.shadow1],
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
                  if (!rootContext.mounted) return;
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (url != null) ...[
                _MenuItem(
                  icon: LucideIcons.link,
                  label: 'Copy link',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!rootContext.mounted) return;
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                ),
                _MenuItem(
                  icon: LucideIcons.externalLink,
                  label: 'Open link',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final uri = Uri.parse(url);
                    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                      if (!rootContext.mounted) return;
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        const SnackBar(content: Text('Could not open link')),
                      );
                    }
                  },
                ),
              ],
              _MenuItem(
                icon: LucideIcons.trash2,
                label: 'Move to trash',
                isDestructive: true,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(notesProvider).moveToTrash(note);
                  if (!rootContext.mounted) return;
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: const Text('Moved to trash'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          ref.read(notesProvider).restore(note);
                        },
                      ),
                    ),
                  );
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.red : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.primary.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
