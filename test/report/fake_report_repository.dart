import 'dart:async';

import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/report_repository.dart';

/// Pengganti [ReportRepository] untuk widget test, tanpa Firebase.
///
/// Setiap kelas Dart otomatis punya interface, jadi fake ini cukup
/// `implements ReportRepository`. Method yang tidak dipakai layar saya
/// ditangani `noSuchMethod` (melempar error bila terpanggil di test).
/// Pasang lewat `Provider<ReportRepository>.value(value: fake, ...)`.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({List<CampusLocation> locations = const []})
    : _locations = locations,
      _byKode = {for (final l in locations) l.kodeRuangan: l};

  final List<CampusLocation> _locations;
  final Map<String, CampusLocation> _byKode;

  /// Bila diisi, `watchLocations` mengembalikan stream ini (mis. stream yang
  /// tidak pernah memancarkan data untuk menguji loading, atau stream error).
  /// Bila null, langsung memancarkan daftar lokasi dari konstruktor.
  Stream<List<CampusLocation>>? locationsStream;

  /// Jumlah panggilan `watchLocations` (untuk menguji tombol Coba lagi).
  int watchLocationsCalls = 0;

  @override
  Stream<List<CampusLocation>> watchLocations() {
    watchLocationsCalls++;
    return locationsStream ?? Stream.value(_locations);
  }

  /// Bila diisi, `getLocationByQr` melempar exception ini (mis. jaringan).
  Exception? error;

  /// Bila diisi, `getLocationByQr` menunggu completer ini selesai, supaya
  /// test bisa memeriksa tampilan selama query berjalan.
  Completer<CampusLocation?>? pending;

  /// Semua argumen `getLocationByQr` sesuai urutan panggilan.
  final List<String> qrQueries = [];

  @override
  Future<CampusLocation?> getLocationByQr(String kodeRuangan) async {
    qrQueries.add(kodeRuangan);
    final e = error;
    if (e != null) throw e;
    final wait = pending;
    if (wait != null) return wait.future;
    return _byKode[kodeRuangan.trim()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
