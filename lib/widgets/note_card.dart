import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/note.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/note_utils.dart';
import 'context_menu.dart';
import 'voice_player_sheet.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({
    super.key,
    required this.note,
  });

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => showNoteContextMenu(context, ref, note),
          onTap: note.type == NoteType.voice && note.audioPath != null
              ? () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => VoicePlayerSheet(
                      filePath: note.audioPath!,
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.type == NoteType.voice)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.mic,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.content.trim().isEmpty
                              ? 'Voice note'
                              : note.content,
                          style: AppTextStyles.primary.copyWith(
                            height: 1.2,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    note.content,
                    style: AppTextStyles.primary.copyWith(
                      height: 1.2,
                      color: colors.textPrimary,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatNoteDate(note.updatedAt),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    if (note.isPinned)
                      Text(
                        'Pinned',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
