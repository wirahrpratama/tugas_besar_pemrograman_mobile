import 'dart:async';

import 'package:sifasilitas/services/ai_classifier_service.dart';

/// Pengganti [AiClassifierService] untuk widget test (tanpa Gemini/HTTP).
///
/// Pasang lewat `Provider<AiClassifierService>.value(value: fake, ...)`.
class FakeAiClassifier implements AiClassifierService {
  /// Hasil default untuk setiap permintaan.
  DamageClassificationResult hasil = const DamageClassificationResult(
    categoryId: 'cat_proyektor',
    prioritas: 'tinggi',
    alasanSingkat: 'Proyektor dibutuhkan langsung untuk perkuliahan.',
  );

  /// Bila diisi, menggantikan [hasil] (mis. Completer untuk respons lambat,
  /// atau melempar exception).
  Future<DamageClassificationResult> Function(String deskripsi)? handler;

  /// Semua deskripsi yang diklasifikasi, sesuai urutan.
  final List<String> permintaan = [];

  @override
  Future<DamageClassificationResult> classifyComplaint(String deskripsi) {
    permintaan.add(deskripsi);
    final h = handler;
    if (h != null) return h(deskripsi);
    return Future.value(hasil);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
