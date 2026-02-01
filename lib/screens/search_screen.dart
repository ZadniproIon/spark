import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import '../widgets/note_card.dart';
import '../widgets/search_bar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesController = ref.watch(notesProvider);
    final results = notesController.search(_query);

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
                    isCircular: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SparkSearchBar(
                controller: _controller,
                onChanged: (value) {
                  setState(() => _query = value);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notesController.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? Center(
                            child: Text(
                              _query.isEmpty
                                  ? 'Search your notes'
                                  : 'No results found',
                              style: AppTextStyles.secondary,
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              return NoteCard(note: results[index], maxLines: 3);
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
