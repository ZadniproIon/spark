import 'package:flutter/material.dart';

class LoadingService extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> show({Duration minDuration = const Duration(seconds: 2)}) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(minDuration);
  }

  void hide() {
    _isLoading = false;
    notifyListeners();
  }
}
