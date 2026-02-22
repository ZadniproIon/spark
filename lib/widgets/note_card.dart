import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import '../utils/note_utils.dart';
import 'context_menu.dart';
import 'voice_player_sheet.dart';

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note});

  final Note note;

  List<TextSpan> _buildLinkSpans(
    String text,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    final matches = urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      final linkText = text.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: linkText,
          style: baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final hasAudioSource =
        (note.audioPath != null && note.audioPath!.isNotEmpty) ||
        (note.audioUrl != null && note.audioUrl!.isNotEmpty);
    final baseTextStyle = AppTextStyles.primary.copyWith(
      height: 1.2,
      color: colors.textPrimary,
    );
    final user = ref.watch(authStateProvider).valueOrNull;
    final showSyncDot = user != null;
    return AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.easeOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: note.isPinned ? colors.flame : colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () {
            triggerHapticFromContext(context, HapticLevel.medium);
            showNoteContextMenu(context, ref, note);
          },
          onTap: note.type == NoteType.voice && hasAudioSource
              ? () async {
                  final source = await ref
                      .read(notesProvider)
                      .resolveVoiceSource(note);
                  if (!context.mounted || source == null || source.isEmpty) {
                    return;
                  }
                  triggerHapticFromContext(context, HapticLevel.light);
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => VoicePlayerSheet(source: source),
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
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: note.content.trim().isEmpty
                            ? Text('Voice note', style: baseTextStyle)
                            : RichText(
                                text: TextSpan(
                                  children: _buildLinkSpans(
                                    note.content,
                                    baseTextStyle,
                                    colors.flame,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  )
                else
                  RichText(
                    text: TextSpan(
                      children: _buildLinkSpans(
                        note.content,
                        baseTextStyle,
                        colors.flame,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatNoteDateWithLocal(
                          dateTime: note.updatedAt,
                          localOverride: note.updatedAtLocal,
                        ),
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
                    if (showSyncDot)
                      Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.only(left: note.isPinned ? 8 : 0),
                        decoration: BoxDecoration(
                          color: note.isSynced ? Colors.green : colors.flame,
                          shape: BoxShape.circle,
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
