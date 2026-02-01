import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import '../widgets/note_card.dart';
import 'search_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({
    super.key,
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(notesProvider);
    final notes = controller.activeNotes;

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
                    onPressed: onBack,
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                  const Spacer(),
                  SparkIconButton(
                    icon: LucideIcons.search,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(),
                        ),
                      );
                    },
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : notes.isEmpty
                        ? Center(
                            child: Text(
                              'No notes yet',
                              style: AppTextStyles.secondary,
                            ),
                          )
                        : ListView.builder(
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              return NoteCard(note: notes[index]);
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
