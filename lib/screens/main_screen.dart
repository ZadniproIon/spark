import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../data/audio_recorder.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import 'menu_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({
    super.key,
    required this.onOpenNotes,
  });

  final VoidCallback onOpenNotes;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final SparkAudioRecorder _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _recorder = SparkAudioRecorder();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await ref.read(notesProvider).addVoiceNote(path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice note added')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed')),
          );
        }
      }
      return;
    }

    final startedPath = await _recorder.start();
    if (startedPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available')),
        );
      }
      return;
    }
    setState(() => _isRecording = true);
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MenuScreen()),
                      );
                    },
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
                    SparkIconButton(
                      icon: _isRecording ? LucideIcons.micOff : LucideIcons.mic,
                      onPressed: _toggleRecording,
                      isCircular: true,
                      backgroundColor:
                          _isRecording ? AppColors.red : AppColors.flame,
                      iconColor: Colors.white,
                      padding: 10,
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
