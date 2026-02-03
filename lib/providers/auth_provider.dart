import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
  );
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

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final user = _repository.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await _repository.upgradeAnonymousWithEmail(email, password);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'email-already-in-use') {
          return _repository.signInWithEmail(email, password);
        }
        rethrow;
      }
    }
    return _repository.signInWithEmail(email, password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    final user = _repository.currentUser;
    if (user != null && user.isAnonymous) {
      return _repository.upgradeAnonymousWithEmail(email, password);
    }
    return _repository.registerWithEmail(email, password);
  }

  Future<UserCredential> signInWithGoogle() async {
    final user = _repository.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        return await _repository.upgradeAnonymousWithGoogle();
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'account-exists-with-different-credential') {
          return _repository.signInWithGoogle();
        }
        rethrow;
      }
    }
    return _repository.signInWithGoogle();
  }

  Future<void> signOutToGuest() async {
    await _repository.signOut();
    await _repository.ensureGuest();
  }

  Future<void> reauthenticateWithPassword(String email, String password) {
    return _repository.reauthenticateWithPassword(email, password);
  }

  Future<void> updateEmail(String email) {
    return _repository.updateEmail(email);
  }

  Future<void> updatePassword(String password) {
    return _repository.updatePassword(password);
  }
}
