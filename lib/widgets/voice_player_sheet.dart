import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../utils/audio_download.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import 'icon_button.dart';

class VoicePlayerSheet extends StatefulWidget {
  const VoicePlayerSheet({
    super.key,
    required this.source,
  });

  final String source;

  @override
  State<VoicePlayerSheet> createState() => _VoicePlayerSheetState();
}

class _VoicePlayerSheetState extends State<VoicePlayerSheet> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    final isRemote = widget.source.startsWith('http://') ||
        widget.source.startsWith('https://');
    if (isRemote) {
      _player.setSourceUrl(widget.source);
    } else {
      _player.setSourceDeviceFile(widget.source);
    }

    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration);
      }
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _seek(Duration position) async {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _duration ? _duration : position);
    await _player.seek(clamped);
  }

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      await saveVoiceNoteToDownloads(
        context: context,
        source: widget.source,
        fileNameBase: 'spark-voice-${DateTime.now().millisecondsSinceEpoch}',
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    final maxSeconds = _duration.inMilliseconds == 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final currentSeconds = _position.inMilliseconds
        .toDouble()
        .clamp(0.0, maxSeconds);

    return SafeArea(
      bottom: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                SparkIconButton(
                  icon: LucideIcons.x,
                  onPressed: () => Navigator.of(context).pop(),
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  haptic: HapticLevel.light,
                ),
                const Spacer(),
                SparkIconButton(
                  icon: _isDownloading ? LucideIcons.loader : LucideIcons.download,
                  onPressed: _isDownloading ? null : _download,
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  haptic: HapticLevel.light,
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${_format(_position)} / ${_format(_duration)}',
              style: AppTextStyles.secondary.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Slider(
              value: currentSeconds,
              min: 0,
              max: maxSeconds,
              onChanged: (value) => _seek(Duration(milliseconds: value.round())),
              activeColor: colors.textPrimary,
              inactiveColor: colors.border,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SparkIconButton(
                  icon: LucideIcons.rewind,
                  onPressed: () => _seek(_position - const Duration(seconds: 3)),
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  haptic: HapticLevel.selection,
                ),
                const SizedBox(width: 12),
                SparkIconButton(
                  icon: _isPlaying ? LucideIcons.pause : LucideIcons.play,
                  onPressed: _togglePlay,
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  padding: 16,
                  size: 28,
                  haptic: HapticLevel.light,
                ),
                const SizedBox(width: 12),
                SparkIconButton(
                  icon: LucideIcons.fastForward,
                  onPressed: () => _seek(_position + const Duration(seconds: 3)),
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  haptic: HapticLevel.selection,
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
