import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  AuthRepository(this._auth, this._googleSignIn);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  Future<void> ensureGuest() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> upgradeAnonymousWithEmail(
    String email,
    String password,
  ) async {
    final user = _auth.currentUser;
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    if (user != null && user.isAnonymous) {
      return user.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in aborted');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> upgradeAnonymousWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in aborted');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final user = _auth.currentUser;
    if (user != null && user.isAnonymous) {
      return user.linkWithCredential(credential);
    }
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> reauthenticateWithPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updateEmail(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.updateEmail(email);
    await user.reload();
  }

  Future<void> updatePassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }
    await user.updatePassword(password);
    await user.reload();
  }
}
