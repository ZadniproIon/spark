import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/haptics_provider.dart';

enum HapticLevel { selection, light, medium, heavy }

void triggerHaptic(WidgetRef ref, HapticLevel level) {
  if (!ref.read(hapticsProvider)) {
    return;
  }
  _perform(level);
}

void triggerHapticFromContext(BuildContext context, HapticLevel level) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(hapticsProvider)) {
    return;
  }
  _perform(level);
}

void _perform(HapticLevel level) {
  switch (level) {
    case HapticLevel.selection:
      HapticFeedback.selectionClick();
      break;
    case HapticLevel.light:
      HapticFeedback.lightImpact();
      break;
    case HapticLevel.medium:
      HapticFeedback.mediumImpact();
      break;
    case HapticLevel.heavy:
      HapticFeedback.heavyImpact();
      break;
  }
}
