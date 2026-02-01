import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/text_styles.dart';
import '../utils/note_utils.dart';
import '../widgets/icon_button.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(notesProvider);
    final notes = controller.trashedNotes;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  SparkIconButton(
                    icon: LucideIcons.arrowLeft,
                    onPressed: () => Navigator.of(context).pop(),
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                  const Spacer(),
                  Text('Recycle bin', style: AppTextStyles.section),
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
                              style: AppTextStyles.secondary,
                            ),
                          )
                        : ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              return _RecycleNoteCard(note: notes[index]);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.shadow1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.type == NoteType.voice ? 'Voice note' : note.content,
            style: AppTextStyles.primary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            formatNoteDate(note.updatedAt),
            style: AppTextStyles.metadata,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(notesProvider).restore(note),
                  icon: const Icon(LucideIcons.undo2, size: 16),
                  label: const Text('Restore'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: AppTextStyles.button,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(notesProvider).deleteForever(note),
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: AppTextStyles.button.copyWith(color: AppColors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
