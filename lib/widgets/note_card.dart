import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/note.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/text_styles.dart';
import '../utils/note_utils.dart';
import 'context_menu.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({
    super.key,
    required this.note,
    this.maxLines = 4,
  });

  final Note note;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.shadow1],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onLongPress: () => showNoteContextMenu(context, ref, note),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.type == NoteType.voice)
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mic,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text('Voice note', style: AppTextStyles.primary),
                    ],
                  )
                else
                  Text(
                    note.content,
                    style: AppTextStyles.primary,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Text(
                  formatNoteDate(note.updatedAt),
                  style: AppTextStyles.metadata,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
