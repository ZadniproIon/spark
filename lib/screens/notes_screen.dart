import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import '../widgets/note_card.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({
    super.key,
  });

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(notesProvider);
    final query = _query.trim();
    final notes = query.isEmpty ? controller.activeNotes : controller.search(query);

    Widget content;
    if (controller.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (notes.isEmpty) {
      content = Center(
        child: Text(
          query.isEmpty ? 'No notes yet' : 'No results found',
          style: AppTextStyles.secondary,
        ),
      );
    } else {
      content = ListView.builder(
        key: ValueKey(query),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          return NoteCard(note: notes[index]);
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.search,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _updateQuery,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: AppTextStyles.secondary,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              style: AppTextStyles.primary.copyWith(height: 1.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        axisAlignment: -1,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: query.isEmpty
                        ? const SizedBox.shrink(key: ValueKey('empty'))
                        : Padding(
                            key: const ValueKey('clear'),
                            padding: const EdgeInsets.only(left: 8),
                            child: SparkIconButton(
                              icon: LucideIcons.x,
                              onPressed: _clearSearch,
                              isCircular: true,
                              borderColor: AppColors.border,
                              backgroundColor: AppColors.bgCard,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
