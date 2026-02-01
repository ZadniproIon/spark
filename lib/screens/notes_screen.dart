import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/note.dart';
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
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Note> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _items.addAll(ref.read(notesProvider).activeNotes);
  }

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
          duration: const Duration(milliseconds: 220),
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
          duration: const Duration(milliseconds: 220),
        );
      } else {
        _items[currentIndex] = note;
        if (currentIndex != i) {
          final moved = _items.removeAt(currentIndex);
          _items.insert(i, moved);
          _listKey.currentState!.removeItem(
            currentIndex,
            (context, animation) => _buildAnimatedItem(moved, animation),
            duration: const Duration(milliseconds: 180),
          );
          _listKey.currentState!.insertItem(
            i,
            duration: const Duration(milliseconds: 180),
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
        child: NoteCard(note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notesProvider, (previous, next) {
      _syncNotes(next.activeNotes);
    });
    final colors = context.sparkColors;
    final controller = ref.watch(notesProvider);
    final query = _query.trim();
    final notes = query.isEmpty ? _items : controller.search(query);

    Widget content;
    if (controller.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (notes.isEmpty) {
      content = Center(
        child: Text(
          query.isEmpty ? 'No notes yet' : 'No results found',
          style: AppTextStyles.secondary.copyWith(color: colors.textSecondary),
        ),
      );
    } else if (query.isEmpty) {
      content = AnimatedList(
        key: _listKey,
        initialItemCount: _items.length,
        itemBuilder: (context, index, animation) {
          final note = _items[index];
          return _buildAnimatedItem(note, animation);
        },
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
      backgroundColor: colors.bg,
      body: SafeArea(bottom: false,
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
                        color: colors.bgCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onChanged: _updateQuery,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: AppTextStyles.secondary.copyWith(
                                  color: colors.textSecondary,
                                ),
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                              ),
                              style: AppTextStyles.primary.copyWith(
                                height: 1.2,
                                color: colors.textPrimary,
                              ),
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
                              borderColor: colors.border,
                              backgroundColor: colors.bgCard,
                              iconColor: colors.textPrimary,
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
