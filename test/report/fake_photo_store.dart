import 'dart:async';
import 'dart:io';

import 'package:sifasilitas/services/photo_store.dart';

/// Pengganti [PhotoStore] untuk widget test (tanpa Firestore/kompresi).
class FakePhotoStore implements PhotoStore {
  /// Referensi yang dikembalikan upload berikutnya.
  String ref = 'photo:uji1';

  /// Bila diisi, `uploadPhoto` melempar ini (boleh Exception atau Error).
  Object? error;

  /// Bila diisi, `uploadPhoto` menunggu completer ini (upload lambat).
  Completer<String>? pending;

  /// Path file setiap upload, sesuai urutan.
  final List<String> uploads = [];

  @override
  Future<String> uploadPhoto(File file) async {
    uploads.add(file.path);
    final e = error;
    if (e != null) throw e;
    final wait = pending;
    if (wait != null) return wait.future;
    return ref;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
