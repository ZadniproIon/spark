import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/icon_button.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../data/audio_recorder.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({
    super.key,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  late final SparkAudioRecorder _recorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
    _recorder = SparkAudioRecorder();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    if (hasText && _isRecording) {
      _stopRecordingAndSave();
    }
  }

  Future<void> _stopRecordingAndSave() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path != null) {
      await ref.read(notesProvider).addVoiceNote(path);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndSave();
      return;
    }

    final startedPath = await _recorder.start();
    if (startedPath == null) {
      return;
    }
    if (mounted) {
      setState(() => _isRecording = true);
    }
  }

  Future<void> _submitText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    await ref.read(notesProvider).addTextNote(text);
    _controller.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 48),
              const Spacer(),
              Column(
                children: [
                  Text(
                    'Hello, there 👋',
                    style: AppTextStyles.primary.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Settings to the left, notes on the right',
                    style: AppTextStyles.secondary.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.bgCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colors.border),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: (_) => _submitText(),
                          decoration: InputDecoration(
                            hintText: 'Type here…',
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
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0.2, 0),
                          end: Offset.zero,
                        ).animate(animation);
                        final fade =
                            Tween<double>(begin: 0, end: 1).animate(animation);
                        return SlideTransition(
                          position: slide,
                          child: FadeTransition(opacity: fade, child: child),
                        );
                      },
                      child: SparkIconButton(
                        key: ValueKey(_hasText),
                        icon: _hasText
                            ? LucideIcons.send
                            : (_isRecording
                                ? LucideIcons.micOff
                                : LucideIcons.mic),
                        onPressed: _hasText ? _submitText : _toggleRecording,
                        isCircular: true,
                        backgroundColor: colors.bgCard,
                        borderColor: colors.border,
                        iconColor: _isRecording && !_hasText
                            ? colors.red
                            : colors.textPrimary,
                        padding: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
