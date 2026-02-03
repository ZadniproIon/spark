import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
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
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Note> _items = [];
  String _query = '';
  bool _hasFocus = false;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _items.addAll(ref.read(notesProvider).activeNotes);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final focus = _focusNode.hasFocus;
    final normalized = _query.trim();
    bool nextOpen = _searchOpen;
    if (focus) {
      nextOpen = true;
    } else if (normalized.isEmpty) {
      nextOpen = false;
    }
    if (_hasFocus != focus || _searchOpen != nextOpen) {
      setState(() {
        _hasFocus = focus;
        _searchOpen = nextOpen;
      });
    }
  }

  void _updateQuery(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _controller.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _query = '';
      _searchOpen = false;
    });
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _focusNode.requestFocus();
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
        padding: EdgeInsets.zero,
        primary: false,
        itemBuilder: (context, index, animation) {
          final note = _items[index];
          return _buildAnimatedItem(note, animation);
        },
      );
    } else {
      content = ListView.builder(
        key: ValueKey(query),
        itemCount: notes.length,
        padding: EdgeInsets.zero,
        primary: false,
        itemBuilder: (context, index) {
          return NoteCard(note: notes[index]);
        },
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              SizedBox(
                height: 48,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final isEmpty = query.isEmpty;
                    final iconColor = _searchOpen && isEmpty
                        ? colors.textSecondary
                        : colors.textPrimary;
                    return Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedContainer(
                            duration: Motion.fast,
                            curve: Motion.easeOut,
                            width: _searchOpen ? maxWidth : 48,
                            height: 48,
                            decoration: _searchOpen
                                ? BoxDecoration(
                                    color: colors.bgCard,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: colors.border),
                                  )
                                : null,
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _searchOpen ? 1 : 0,
                            duration: Motion.fast,
                            curve: Motion.easeOut,
                            child: IgnorePointer(
                              ignoring: !_searchOpen,
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(
                                    LucideIcons.search,
                                    size: 24,
                                    color: iconColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      onChanged: _updateQuery,
                                      textInputAction: TextInputAction.search,
                                      textCapitalization:
                                          TextCapitalization.none,
                                      decoration: InputDecoration(
                                        hintText: 'Search...',
                                        hintStyle:
                                            AppTextStyles.secondary.copyWith(
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
                                  GestureDetector(
                                    onTap: () {
                                      triggerHaptic(
                                        ref,
                                        HapticLevel.selection,
                                      );
                                      _clearSearch();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        LucideIcons.x,
                                        size: 24,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IgnorePointer(
                            ignoring: _searchOpen,
                            child: AnimatedOpacity(
                              opacity: _searchOpen ? 0 : 1,
                              duration: Motion.fast,
                              curve: Motion.easeOut,
                              child: SparkIconButton(
                                icon: LucideIcons.search,
                                onPressed: _openSearch,
                                isCircular: true,
                                borderColor: colors.border,
                                backgroundColor: colors.bgCard,
                                iconColor: colors.textPrimary,
                                size: 24,
                                haptic: HapticLevel.selection,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: MediaQuery.removeViewInsets(
                    context: context,
                    removeBottom: true,
                    child: AnimatedSwitcher(
                      duration: Motion.fast,
                      switchInCurve: Motion.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
