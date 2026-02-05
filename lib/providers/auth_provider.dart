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

  Future<void> signOutToGuest() async {
    await _repository.signOut();
    await _repository.ensureGuest();
  }
}
