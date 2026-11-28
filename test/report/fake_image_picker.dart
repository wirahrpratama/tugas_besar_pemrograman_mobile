import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Pengganti [ImagePicker] untuk widget test (tanpa kamera/galeri native).
///
/// Pasang lewat `Provider<ImagePicker>.value(value: fake, ...)`; layar form
/// mengambilnya dengan `context.read<ImagePicker?>()`.
class FakeImagePicker implements ImagePicker {
  /// Foto yang dikembalikan; null = pengguna menekan batal.
  XFile? hasil;

  /// Bila diisi, `pickImage` melempar exception ini (mis. izin ditolak).
  PlatformException? error;

  /// Bila diisi, `pickImage` menunggu completer ini (picker "masih terbuka").
  Completer<XFile?>? pending;

  /// Sumber setiap panggilan, sesuai urutan.
  final List<ImageSource> sources = [];

  /// Nilai `requestFullMetadata` pada panggilan terakhir.
  bool? lastRequestFullMetadata;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sources.add(source);
    lastRequestFullMetadata = requestFullMetadata;
    final e = error;
    if (e != null) throw e;
    final wait = pending;
    if (wait != null) return wait.future;
    return hasil;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
