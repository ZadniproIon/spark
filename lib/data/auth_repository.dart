import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<User?> authStateChanges() {
    return _client.auth.onAuthStateChange.map(
      (data) => data.session?.user,
    );
  }

  User? get currentUser => _client.auth.currentUser;

  Future<void> ensureGuest() async {
    // Guest mode is local-only; no remote auth needed.
    return;
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      Provider.google,
      redirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
