import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController {
  AuthController(this._repository);

  final AuthRepository _repository;

  User? get currentUser => _repository.currentUser;

  Future<void> ensureGuest() => _repository.ensureGuest();

  Future<void> signInWithGoogle() => _repository.signInWithGoogle();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _repository.signInWithEmail(email: email, password: password);

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) => _repository.signUpWithEmail(email: email, password: password);

  Future<void> signOutToGuest() async {
    try {
      await _repository.signOut();
    } catch (_) {
      // If the session is already invalidated (e.g., account deleted), continue.
    }
    await _repository.ensureGuest();
  }

  Future<void> deleteCurrentAccount() async {
    await _repository.deleteCurrentAccount();
  }
}
