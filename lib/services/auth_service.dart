import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report_models.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _dbOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Sub-peran yang boleh mendaftar sendiri. Akun admin & teknisi dibuat oleh admin.
  static const pelaporSubRoles = ['mahasiswa', 'dosen', 'staf'];

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  User? get currentUser => _auth.currentUser;

  Stream<User?> userChanges() => _auth.userChanges();

  Stream<AppUser?> watchAppUser(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      final data = snap.data();
      return data == null ? null : AppUser.fromMap(snap.id, data);
    });
  }

  Future<void> register({
    required String nama,
    required String identityNumber,
    required String email,
    required String password,
    required String subRole,
  }) async {
    if (!pelaporSubRoles.contains(subRole)) {
      throw const AuthException('Status pengguna tidak valid.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }

    final user = credential.user!;
    final profile = AppUser(
      uid: user.uid,
      nama: nama.trim(),
      identityNumber: identityNumber.trim(),
      email: normalizedEmail,
      subRole: subRole,
      role: UserRole.pelapor,
    );

    try {
      await _userDoc(user.uid).set({
        ...profile.toMap(),
        'fcm_tokens': <String>[],
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Hindari akun Auth tanpa profil Firestore.
      try {
        await user.delete();
      } catch (_) {}
      throw const AuthException('Gagal menyimpan profil. Silakan coba lagi.');
    }

    try {
      await user.updateDisplayName(profile.nama);
      await user.sendEmailVerification();
    } on FirebaseAuthException {
      // Email verifikasi bisa dikirim ulang dari layar verifikasi.
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      // Jangan bocorkan apakah email terdaftar atau tidak.
      if (e.code == 'user-not-found') return;
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Memuat ulang status verifikasi email. Jika sudah terverifikasi, token
  /// diperbarui agar [userChanges] memancarkan user terbaru ke AuthGate.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null || !refreshed.emailVerified) return false;
      await refreshed.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<void> updateNama(String uid, String nama) async {
    final trimmed = nama.trim();
    try {
      await _userDoc(uid).update({'nama': trimmed});
      await _auth.currentUser?.updateDisplayName(trimmed);
    } on FirebaseException catch (e) {
      throw AuthException('Gagal memperbarui nama (${e.code}).');
    }
  }

  static String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk atau gunakan Lupa Password.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'weak-password':
        return 'Password terlalu lemah.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Email atau password salah.';
      case 'user-disabled':
        return 'Akun ini dinonaktifkan. Hubungi admin fasilitas.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat lagi.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      case 'operation-not-allowed':
        return 'Login email/password belum diaktifkan di Firebase Console.';
      case 'requires-recent-login':
        return 'Sesi sudah lama. Silakan keluar lalu masuk kembali.';
      default:
        return 'Terjadi kesalahan (${e.code}). Silakan coba lagi.';
    }
  }
}
