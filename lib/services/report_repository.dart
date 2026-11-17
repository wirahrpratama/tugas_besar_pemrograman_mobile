import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report_models.dart';

/// Lapisan baca data Firestore untuk seluruh modul UI tanpa akses query langsung.
class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// Mencari lokasi kampus berdasarkan isi QR Code (`kode_ruangan`).
  Future<CampusLocation?> getLocationByQr(String kodeRuangan) async {
    final normalized = kodeRuangan.trim();
    if (normalized.isEmpty) return null;
    final snap = await _db
        .collection('locations')
        .where('kode_ruangan', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CampusLocation.fromDoc(snap.docs.first);
  }

  /// Aliran daftar master kategori fasilitas, diurutkan menurut target SLA.
  Stream<List<FacilityCategory>> watchCategories() {
    return _db
        .collection('categories')
        .orderBy('target_sla_jam')
        .snapshots()
        .map((snap) => snap.docs.map(FacilityCategory.fromDoc).toList());
  }

  /// Aliran daftar master lokasi ruangan, diurutkan gedung lalu nama ruangan.
  Stream<List<CampusLocation>> watchLocations() {
    return _db.collection('locations').orderBy('nama_gedung').snapshots().map((
      snap,
    ) {
      final list = snap.docs.map(CampusLocation.fromDoc).toList();
      list.sort((a, b) {
        final gedung = a.namaGedung.compareTo(b.namaGedung);
        if (gedung != 0) return gedung;
        return a.namaRuangan.compareTo(b.namaRuangan);
      });
      return list;
    });
  }

  /// Aliran laporan yang dibuat oleh [uid] DAN laporan yang didukungnya
  /// (`uid` ada di `supporter_uids`), diurutkan `prioritas_rank` lalu `created_at`.
  Stream<List<Report>> watchReportsForReporter(String uid) {
    return _db
        .collection('reports')
        .where(
          Filter.or(
            Filter('reporter_uid', isEqualTo: uid),
            Filter('supporter_uids', arrayContains: uid),
          ),
        )
        .orderBy('prioritas_rank')
        .orderBy('created_at')
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromDoc).toList());
  }

  /// Aliran antrean laporan untuk Admin dengan filter opsional [status] dan
  /// [prioritas], diurutkan `prioritas_rank` lalu `created_at`.
  Stream<List<Report>> watchReportsForAdmin({
    ReportStatus? status,
    String? prioritas,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('reports');
    if (status != null) {
      query = query.where('status', isEqualTo: status.value);
    }
    final normalizedPrioritas = prioritas?.trim().toLowerCase();
    if (normalizedPrioritas != null && normalizedPrioritas.isNotEmpty) {
      query = query.where('prioritas', isEqualTo: normalizedPrioritas);
    }
    return query
        .orderBy('prioritas_rank')
        .orderBy('created_at')
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromDoc).toList());
  }

  /// Aliran tugas laporan yang ditugaskan kepada teknisi [uid],
  /// diurutkan `prioritas_rank` lalu `created_at`.
  Stream<List<Report>> watchReportsForTeknisi(String uid) {
    return _db
        .collection('reports')
        .where('assigned_teknisi_uid', isEqualTo: uid)
        .orderBy('prioritas_rank')
        .orderBy('created_at')
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromDoc).toList());
  }

  /// Aliran detail satu laporan; memancarkan `null` bila dokumen tidak ada.
  Stream<Report?> watchReport(String id) {
    return _db.collection('reports').doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Report.fromDoc(doc);
    });
  }

  /// Aliran audit trail log laporan secara kronologis (`created_at` ASC).
  Stream<List<ReportLog>> watchLogs(String reportId) {
    return _db
        .collection('reports')
        .doc(reportId)
        .collection('logs')
        .orderBy('created_at')
        .snapshots()
        .map((snap) => snap.docs.map(ReportLog.fromDoc).toList());
  }

  /// Daftar akun berperan `teknisi` (hanya diizinkan dibaca oleh admin).
  Future<List<AppUser>> listTeknisi() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: UserRole.teknisi.name)
        .get();
    final users =
        snap.docs.map((doc) => AppUser.fromMap(doc.id, doc.data())).toList();
    users.sort((a, b) => a.nama.compareTo(b.nama));
    return users;
  }
}
