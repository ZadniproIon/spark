import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/note_utils.dart';
import '../utils/motion.dart';
import '../widgets/icon_button.dart';

class RecycleBinScreen extends ConsumerStatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  ConsumerState<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends ConsumerState<RecycleBinScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Note> _items = [];

  @override
  void initState() {
    super.initState();
    _items.addAll(ref.read(notesProvider).trashedNotes);
  }

  void _syncNotes(List<Note> updated) {
    if (_listKey.currentState == null) {
      _items
        ..clear()
        ..addAll(updated);
      return;
    }

    final newIds = updated.map((note) => note.id).toSet();
    for (int i = _items.length - 1; i >= 0; i--) {
      final note = _items[i];
      if (!newIds.contains(note.id)) {
        final removed = _items.removeAt(i);
        _listKey.currentState!.removeItem(
          i,
          (context, animation) => _buildAnimatedItem(removed, animation),
          duration: Motion.fast,
        );
      }
    }

    for (int i = 0; i < updated.length; i++) {
      final note = updated[i];
      final currentIndex = _items.indexWhere((item) => item.id == note.id);
      if (currentIndex == -1) {
        _items.insert(i, note);
        _listKey.currentState!.insertItem(
          i,
          duration: Motion.fast,
        );
      } else {
        _items[currentIndex] = note;
        if (currentIndex != i) {
          final moved = _items.removeAt(currentIndex);
          _items.insert(i, moved);
          _listKey.currentState!.removeItem(
            currentIndex,
            (context, animation) => _buildAnimatedItem(moved, animation),
            duration: Motion.fast,
          );
          _listKey.currentState!.insertItem(
            i,
            duration: Motion.fast,
          );
        }
      }
    }
  }

  Widget _buildAnimatedItem(Note note, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: animation,
        child: _RecycleNoteCard(note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final controller = ref.watch(notesProvider);
    ref.listen(notesProvider, (previous, next) {
      _syncNotes(next.trashedNotes);
    });
    final notes = controller.trashedNotes;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  SparkIconButton(
                    icon: LucideIcons.arrowLeft,
                    onPressed: () => Navigator.of(context).pop(),
                    isCircular: true,
                    borderColor: colors.border,
                    backgroundColor: colors.bgCard,
                    iconColor: colors.textPrimary,
                    haptic: HapticLevel.light,
                  ),
                  const Spacer(),
                  Text(
                    'Recycle bin',
                    style: AppTextStyles.section.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                        ? Center(
                            child: Text(
                              'Recycle bin is empty',
                              style: AppTextStyles.secondary.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : AnimatedList(
                            key: _listKey,
                            initialItemCount: _items.length,
                            padding: EdgeInsets.zero,
                            primary: false,
                            itemBuilder: (context, index, animation) {
                              final note = _items[index];
                              return _buildAnimatedItem(note, animation);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecycleNoteCard extends ConsumerWidget {
  const _RecycleNoteCard({required this.note});

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
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.sparkColors;
    final baseTextStyle = AppTextStyles.primary.copyWith(
      height: 1.2,
      color: colors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: colors.bgCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: colors.border),
          ),
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
                            ? Text(
                                'Voice note',
                                style: baseTextStyle,
                              )
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
                Text(
                  formatNoteDate(note.updatedAt),
                  style: AppTextStyles.metadata.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  triggerHaptic(ref, HapticLevel.light);
                  ref.read(notesProvider).restore(note);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  backgroundColor: colors.bgCard,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: AppTextStyles.button,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
                child: const _RecycleButtonContent(
                  icon: LucideIcons.undo2,
                  label: 'Restore',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  triggerHaptic(ref, HapticLevel.heavy);
                  ref.read(notesProvider).deleteForever(note);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.red,
                  backgroundColor: colors.bgCard,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: AppTextStyles.button.copyWith(color: colors.red),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                ),
                child: const _RecycleButtonContent(
                  icon: LucideIcons.trash2,
                  label: 'Delete',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RecycleButtonContent extends StatelessWidget {
  const _RecycleButtonContent({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
