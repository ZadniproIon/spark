import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../utils/audio_download.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../utils/haptics.dart';
import 'icon_button.dart';

class VoicePlayerSheet extends StatefulWidget {
  const VoicePlayerSheet({super.key, required this.source});

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
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);

    final isRemote =
        widget.source.startsWith('http://') ||
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
        setState(() {
          final shouldIgnoreCompletionReset =
              _isCompleted &&
              !_isPlaying &&
              _duration > Duration.zero &&
              position == Duration.zero;
          if (shouldIgnoreCompletionReset) {
            return;
          }
          _position = position;
          if (_duration > Duration.zero && position < _duration) {
            _isCompleted = false;
          }
        });
      }
    });
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = false;
        _isCompleted = true;
        if (_duration > Duration.zero) {
          _position = _duration;
        }
      });
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
      return;
    }

    final isAtEnd =
        _duration > Duration.zero &&
        _position >= _duration - const Duration(milliseconds: 200);
    if (_isCompleted || isAtEnd) {
      await _player.seek(Duration.zero);
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _isCompleted = false;
        });
      }
    }
    await _player.resume();
  }

  Future<void> _seek(Duration position) async {
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > _duration ? _duration : position);
    await _player.seek(clamped);
    if (!mounted) {
      return;
    }
    setState(() {
      _position = clamped;
      _isCompleted = _duration > Duration.zero && clamped >= _duration;
    });
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
    final currentSeconds = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxSeconds,
    );

    return SafeArea(
      bottom: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                  icon: _isDownloading
                      ? LucideIcons.loader
                      : LucideIcons.download,
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
              style: AppTextStyles.secondary.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: currentSeconds,
              min: 0,
              max: maxSeconds,
              onChanged: (value) =>
                  _seek(Duration(milliseconds: value.round())),
              activeColor: colors.textPrimary,
              inactiveColor: colors.border,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SparkIconButton(
                  icon: LucideIcons.rewind,
                  onPressed: () =>
                      _seek(_position - const Duration(seconds: 3)),
                  isCircular: true,
                  borderColor: colors.border,
                  backgroundColor: colors.bgCard,
                  iconColor: colors.textPrimary,
                  haptic: HapticLevel.selection,
                ),
                const SizedBox(width: 12),
                SparkIconButton(
                  icon: _isPlaying
                      ? LucideIcons.pause
                      : (_isCompleted
                            ? LucideIcons.rotateCcw
                            : LucideIcons.play),
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
                  onPressed: () =>
                      _seek(_position + const Duration(seconds: 3)),
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
