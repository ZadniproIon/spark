import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

class LoadingOverlay extends StatefulWidget {
  const LoadingOverlay({super.key, required this.label});

  final String label;

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  int _dotCount = 1;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = _dotCount % 3 + 1);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.sparkColors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Text(
          '${widget.label}${'.' * _dotCount}',
          style: AppTextStyles.primary.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}

/// Pushes a full-screen [LoadingOverlay] on the root navigator, runs [action],
/// then pops the overlay regardless of success or failure.
Future<T> withLoadingOverlay<T>(
  BuildContext context, {
  required String label,
  required Future<T> Function() action,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  navigator.push<void>(
    PageRouteBuilder(
      opaque: true,
      barrierDismissible: false,
      pageBuilder: (_, _, _) => LoadingOverlay(label: label),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    ),
  );
  try {
    final actionFuture = action();
    final minDelay = Future<void>.delayed(const Duration(seconds: 2));
    final result = await actionFuture;
    await minDelay;
    return result;
  } finally {
    if (navigator.canPop()) navigator.pop();
  }
}
