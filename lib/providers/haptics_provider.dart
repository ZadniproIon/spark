import 'package:flutter_riverpod/flutter_riverpod.dart';

class HapticsController extends StateNotifier<bool> {
  HapticsController() : super(true);

  void setEnabled(bool value) => state = value;
}

final hapticsProvider = StateNotifierProvider<HapticsController, bool>(
  (ref) => HapticsController(),
);
