import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../data/audio_recorder.dart';
import '../providers/auth_provider.dart';
import '../providers/notes_provider.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import '../utils/motion.dart';
import '../widgets/auth_sheet.dart';
import '../widgets/icon_button.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _hasFocus = false;
  bool _guestBannerPressed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleFocusChange() {
    if (_hasFocus != _focusNode.hasFocus) {
      setState(() => _hasFocus = _focusNode.hasFocus);
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

  Future<void> _openVoiceSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VoiceRecorderSheet(),
    );
  }

  Future<void> _showGuestInfoSheet() async {
    final colors = context.sparkColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Guest account',
                  style: AppTextStyles.primary.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Column(
                  children: const [
                    _InfoRow(
                      icon: LucideIcons.info,
                      text:
                          'Notes are stored only on this device while you’re a guest.',
                    ),
                    SizedBox(height: 12),
                    _InfoRow(
                      icon: LucideIcons.merge,
                      text:
                          'When you sign in, guest notes are merged into your account.',
                    ),
                    SizedBox(height: 12),
                    _InfoRow(
                      icon: LucideIcons.logOut,
                      text:
                          'Logging out returns you to guest mode and keeps notes local.',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    triggerHaptic(ref, HapticLevel.medium);
                    Navigator.of(sheetContext).pop();
                    showAuthSheet(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.logIn,
                          size: 20,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sign in to sync',
                          style: AppTextStyles.primary.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;
    final isGuest = ref.watch(authStateProvider).valueOrNull == null;

    return Scaffold(
      backgroundColor: colors.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              switchInCurve: Motion.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final fade = Tween<double>(begin: 0, end: 1).animate(animation);
                final slide = Tween<Offset>(
                  begin: const Offset(0, -0.1),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: isGuest
                  ? Align(
                      key: const ValueKey('guest-banner'),
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) =>
                              setState(() => _guestBannerPressed = true),
                          onTapCancel: () =>
                              setState(() => _guestBannerPressed = false),
                          onTapUp: (_) =>
                              setState(() => _guestBannerPressed = false),
                          onTap: () {
                            triggerHaptic(ref, HapticLevel.light);
                            _showGuestInfoSheet();
                          },
                          child: AnimatedScale(
                            duration: Motion.fast,
                            curve: Motion.easeOut,
                            scale: _guestBannerPressed ? 0.98 : 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colors.bgCard,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.info,
                                    size: 16,
                                    color: colors.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'You’re on a guest account',
                                    style: AppTextStyles.secondary.copyWith(
                                      fontSize: 12,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('guest-banner-empty')),
            ),
            Align(
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: Motion.fast,
                switchInCurve: Motion.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final fade = Tween<double>(
                    begin: 0,
                    end: 1,
                  ).animate(animation);
                  final scale = Tween<double>(
                    begin: 0.96,
                    end: 1,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: fade,
                    child: ScaleTransition(scale: scale, child: child),
                  );
                },
                child: keyboardVisible
                    ? const SizedBox.shrink(key: ValueKey('hidden'))
                    : Padding(
                        key: const ValueKey('visible'),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hello, there ✌🏻',
                              style: AppTextStyles.primary.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Settings to the left, notes to the right',
                              style: AppTextStyles.secondary.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedPadding(
                duration: Motion.keyboard,
                curve: Motion.easeOut,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  (keyboardVisible ? 16 : 32) + bottomInset,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.bgCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.newline,
                            minLines: 1,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.center,
                            onSubmitted: (_) => _submitText(),
                            decoration: InputDecoration(
                              hintText: 'Type here...',
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
                        duration: Motion.fast,
                        switchInCurve: Motion.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          final fade = Tween<double>(
                            begin: 0,
                            end: 1,
                          ).animate(animation);
                          final scale = Tween<double>(
                            begin: 0.94,
                            end: 1,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: fade,
                            child: ScaleTransition(scale: scale, child: child),
                          );
                        },
                        child: SparkIconButton(
                          key: ValueKey(_hasText),
                          icon: LucideIcons.mic,
                          onPressed: _hasText ? _submitText : _openVoiceSheet,
                          isCircular: true,
                          backgroundColor: colors.bgCard,
                          borderColor: colors.border,
                          iconColor: colors.textPrimary,
                          padding: 12,
                          haptic: _hasText
                              ? HapticLevel.medium
                              : HapticLevel.light,
                          child: _hasText
                              ? SvgPicture.asset(
                                  'assets/icons/send-horizontal.svg',
                                  width: 24,
                                  height: 24,
                                  colorFilter: ColorFilter.mode(
                                    colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceRecorderSheet extends ConsumerStatefulWidget {
  const _VoiceRecorderSheet();

  @override
  ConsumerState<_VoiceRecorderSheet> createState() =>
      _VoiceRecorderSheetState();
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: colors.textPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.secondary.copyWith(
              fontSize: 16,
              color: colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceRecorderSheetState extends ConsumerState<_VoiceRecorderSheet> {
  late final SparkAudioRecorder _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _elapsed = Duration.zero;
  double _level = 0.0;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isSaving = false;
  bool _hasStartedRecording = false;

  @override
  void initState() {
    super.initState();
    _recorder = SparkAudioRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final startedPath = await _recorder.start();
    if (!mounted) return;
    if (startedPath == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _hasStartedRecording = true;
      _isRecording = true;
      _isPaused = false;
    });
    _stopwatch.start();
    _tick();
  }

  void _tick() async {
    while (mounted && _stopwatch.isRunning) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted || !_stopwatch.isRunning) {
        break;
      }
      double nextLevel = _level;
      try {
        final amplitude = await _recorder.getAmplitude();
        nextLevel = _normalizeAmplitude(amplitude.current);
      } catch (_) {
        nextLevel = 0;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed = _stopwatch.elapsed;
        _level = (_level * 0.7) + (nextLevel * 0.3);
      });
    }
  }

  Future<void> _togglePause() async {
    if (!_isRecording) return;
    if (_isPaused) {
      await _recorder.resume();
      _stopwatch.start();
      setState(() => _isPaused = false);
      _tick();
    } else {
      await _recorder.pause();
      _stopwatch.stop();
      setState(() {
        _isPaused = true;
        _level = 0;
      });
    }
  }

  Future<void> _discard() async {
    await _recorder.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final path = await _recorder.stop();
    if (path != null) {
      await ref.read(notesProvider).addVoiceNote(path);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double _normalizeAmplitude(double db) {
    const minDb = -60.0;
    if (db.isNaN) {
      return 0;
    }
    final clamped = db.clamp(minDb, 0.0);
    return (clamped - minDb) / (0 - minDb);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    const double modalHorizontalInset = 24;
    const double modalVerticalInset = 24;
    const double modalRadius = 32;
    const double controlPadding = 8;
    return PopScope(
      canPop: !_hasStartedRecording && !_isSaving,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(modalRadius),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: modalHorizontalInset,
            vertical: modalVerticalInset,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SparkIconButton(
                    icon: LucideIcons.x,
                    onPressed: _discard,
                    isCircular: true,
                    borderColor: colors.border,
                    backgroundColor: colors.bgCard,
                    iconColor: colors.textPrimary,
                    haptic: HapticLevel.light,
                  ),
                  const Spacer(),
                  SparkIconButton(
                    icon: LucideIcons.check,
                    onPressed: _isPaused ? _save : null,
                    isCircular: true,
                    borderColor: colors.border,
                    backgroundColor: colors.bgCard,
                    iconColor: colors.textPrimary,
                    haptic: HapticLevel.medium,
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(controlPadding),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: Motion.fast,
                      switchInCurve: Motion.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Text(
                        _format(_elapsed),
                        key: ValueKey(_elapsed.inMilliseconds ~/ 50),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WaveformMeter(level: _level, color: colors.textSecondary),
                    const SizedBox(height: 16),
                    AnimatedScale(
                      scale: _isRecording ? 1.0 : 0.95,
                      duration: Motion.fast,
                      curve: Motion.easeOut,
                      child: SparkIconButton(
                        icon: _isPaused ? LucideIcons.play : LucideIcons.pause,
                        onPressed: _togglePause,
                        isCircular: true,
                        backgroundColor: colors.bgCard,
                        borderColor: colors.border,
                        iconColor: colors.textPrimary,
                        padding: 18,
                        size: 28,
                        haptic: HapticLevel.light,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isPaused ? 'Paused' : 'Recording...',
                      style: AppTextStyles.secondary.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformMeter extends StatelessWidget {
  const _WaveformMeter({required this.level, required this.color});

  final double level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(level: level, color: color),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.level, required this.color});

  final double level;
  final Color color;

  static const List<double> _pattern = [
    0.2,
    0.35,
    0.5,
    0.3,
    0.6,
    0.4,
    0.75,
    0.45,
    0.7,
    0.4,
    0.85,
    0.5,
    0.7,
    0.45,
    0.8,
    0.4,
    0.6,
    0.35,
    0.5,
    0.3,
    0.4,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final midY = size.height / 2;
    final maxAmp = size.height / 2;
    final clamped = level.clamp(0.0, 1.0);
    final step = size.width / (_pattern.length - 1);

    for (int i = 0; i < _pattern.length; i++) {
      final amp = maxAmp * clamped * _pattern[i];
      final x = step * i;
      canvas.drawLine(Offset(x, midY - amp), Offset(x, midY + amp), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.color != color;
  }
}
