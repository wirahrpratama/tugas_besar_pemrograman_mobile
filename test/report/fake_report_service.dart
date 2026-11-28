import 'dart:async';

import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/report_service.dart';

/// Argumen satu panggilan `submitReport`.
typedef SubmitCall = ({
  AppUser reporter,
  CampusLocation location,
  FacilityCategory category,
  String deskripsi,
  String fotoSebelumUrl,
  String? aiSuggestedPriority,
});

/// Pengganti [ReportService] untuk widget test (tanpa transaksi Firestore).
class FakeReportService implements ReportService {
  /// Map hasil yang dikembalikan `submitReport`.
  Map<String, dynamic> hasil = {
    'merged': false,
    'report_id': 'rep_uji',
    'ticket_number': 'SF-UJI-0001',
    'message': 'Tiket laporan baru berhasil dibuat dengan nomor SF-UJI-0001.',
  };

  /// Bila diisi, `submitReport` melempar ini.
  Object? error;

  /// Bila diisi, `submitReport` menunggu completer ini.
  Completer<Map<String, dynamic>>? pending;

  final List<SubmitCall> calls = [];

  @override
  Future<Map<String, dynamic>> submitReport({
    required AppUser reporter,
    required CampusLocation location,
    required FacilityCategory category,
    required String deskripsi,
    required String fotoSebelumUrl,
    String? aiSuggestedPriority,
  }) async {
    calls.add((
      reporter: reporter,
      location: location,
      category: category,
      deskripsi: deskripsi,
      fotoSebelumUrl: fotoSebelumUrl,
      aiSuggestedPriority: aiSuggestedPriority,
    ));
    final e = error;
    if (e != null) throw e;
    final wait = pending;
    if (wait != null) return wait.future;
    return hasil;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
