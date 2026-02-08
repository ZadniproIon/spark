import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<User?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) => data.session?.user);
  }

  User? get currentUser => _client.auth.currentUser;

  Future<void> ensureGuest() async {
    // Guest mode is local-only; no remote auth needed.
    return;
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.authRedirectUrl,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> deleteCurrentAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException('No signed-in user.');
    }

    final rpcNames = <String>[
      SupabaseConfig.deleteAccountRpc,
      'delete_user',
      'delete_my_account',
    ];

    PostgrestException? lastRpcError;
    for (final rpcName in rpcNames) {
      try {
        await _client.rpc(rpcName);
        return;
      } on PostgrestException catch (error) {
        lastRpcError = error;
        final message = error.message.toLowerCase();
        final functionMissing =
            message.contains('does not exist') ||
            message.contains('could not find the function');
        if (functionMissing) {
          continue;
        }
        rethrow;
      }
    }

    throw AuthException(
      'Account deletion RPC not found. Deploy `${SupabaseConfig.deleteAccountRpc}` in Supabase.',
      statusCode: lastRpcError?.code,
    );
  }
}
