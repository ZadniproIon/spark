import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({
    super.key,
    required this.onOpenNotes,
    required this.onOpenMenu,
  });

  final VoidCallback onOpenNotes;
  final VoidCallback onOpenMenu;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    await ref.read(notesProvider).addTextNote(text);
    _controller.clear();
    _focusNode.requestFocus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: LucideIcons.menu,
                    onPressed: widget.onOpenMenu,
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                  const Spacer(),
                  SparkIconButton(
                    icon: LucideIcons.list,
                    onPressed: widget.onOpenNotes,
                    showShadow: true,
                    borderColor: AppColors.border,
                    backgroundColor: AppColors.bgCard,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Hello, there 👋',
                style: AppTextStyles.title,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [AppShadows.shadow1],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitText(),
                        decoration: InputDecoration(
                          hintText: 'Type here…',
                          hintStyle: AppTextStyles.secondary,
                          border: InputBorder.none,
                        ),
                        style: AppTextStyles.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
