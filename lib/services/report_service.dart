import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_models.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Validasi State Machine sesuai Slide Opsi 5:
  /// reported -> verified -> assigned -> in_progress -> resolved
  static bool isValidTransition(ReportStatus current, ReportStatus next) {
    if (next == ReportStatus.rejected &&
        (current == ReportStatus.reported || current == ReportStatus.verified)) {
      return true;
    }
    switch (current) {
      case ReportStatus.reported:
        return next == ReportStatus.verified;
      case ReportStatus.verified:
        return next == ReportStatus.assigned;
      case ReportStatus.assigned:
        return next == ReportStatus.inProgress;
      case ReportStatus.inProgress:
        return next == ReportStatus.resolved;
      case ReportStatus.resolved:
      case ReportStatus.rejected:
        return false;
    }
  }

  /// Buat Laporan Baru (dengan Pengecekan Anti-Duplikasi + Auto-Upvote)
  Future<Map<String, dynamic>> submitReport({
    required AppUser reporter,
    required CampusLocation location,
    required FacilityCategory category,
    required String deskripsi,
    required String fotoSebelumUrl,
    String? aiSuggestedPriority,
  }) async {
    final existingQuery = await _db
        .collection('reports')
        .where('location_id', isEqualTo: location.id)
        .where('category_id', isEqualTo: category.id)
        .where('status', whereIn: [
          'reported',
          'verified',
          'assigned',
          'in_progress',
        ])
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      final existingDoc = existingQuery.docs.first;
      final supporterRef = existingDoc.reference
          .collection('supporters')
          .doc(reporter.uid);

      return _db.runTransaction((transaction) async {
        final supporterSnap = await transaction.get(supporterRef);
        if (supporterSnap.exists) {
          return {
            'merged': true,
            'already_supported': true,
            'ticket_number': existingDoc.data()['ticket_number'],
            'message':
                'Fasilitas ini sudah dilaporkan dan sedang ditangani. Anda sudah tercatat sebagai pendukung tiket ini.',
          };
        }

        transaction.set(supporterRef, {
          'user_uid': reporter.uid,
          'nama': reporter.nama,
          'created_at': FieldValue.serverTimestamp(),
        });

        transaction.update(existingDoc.reference, {
          'upvotes_count': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        });

        return {
          'merged': true,
          'already_supported': false,
          'ticket_number': existingDoc.data()['ticket_number'],
          'message':
              'Keluhan serupa di ruangan ini sudah aktif. Dukungan Anda (+1 Upvote) berhasil ditambahkan agar prioritas naik!',
        };
      });
    }

    final now = DateTime.now();
    final slaDeadline = now.add(Duration(hours: category.targetSlaJam));
    final ticketNumber =
        'TKT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final reportRef = _db.collection('reports').doc();
    final logRef = reportRef.collection('logs').doc();
    final supporterRef = reportRef.collection('supporters').doc(reporter.uid);

    await _db.runTransaction((transaction) async {
      transaction.set(reportRef, {
        'ticket_number': ticketNumber,
        'reporter_uid': reporter.uid,
        'reporter_name': reporter.nama,
        'reporter_sub_role': reporter.subRole,
        'location_id': location.id,
        'kode_ruangan': location.kodeRuangan,
        'nama_gedung': location.namaGedung,
        'nama_ruangan': location.namaRuangan,
        'category_id': category.id,
        'nama_objek': category.namaObjek,
        'prioritas': aiSuggestedPriority ?? category.prioritasDefault,
        'target_sla_jam': category.targetSlaJam,
        'deskripsi': deskripsi,
        'foto_sebelum_url': fotoSebelumUrl,
        'foto_sesudah_url': null,
        'status': ReportStatus.reported.value,
        'assigned_teknisi_uid': null,
        'assigned_teknisi_nama': null,
        'upvotes_count': 1,
        'confirmed_by_reporter': false,
        'created_at': Timestamp.fromDate(now),
        'sla_deadline': Timestamp.fromDate(slaDeadline),
        'updated_at': Timestamp.fromDate(now),
      });

      transaction.set(supporterRef, {
        'user_uid': reporter.uid,
        'nama': reporter.nama,
        'created_at': Timestamp.fromDate(now),
      });

      transaction.set(logRef, {
        'actor_uid': reporter.uid,
        'actor_nama': reporter.nama,
        'actor_role': reporter.role.name,
        'status_lama': null,
        'status_baru': ReportStatus.reported.value,
        'catatan': 'Laporan awal dibuat melalui aplikasi.',
        'created_at': Timestamp.fromDate(now),
      });
    });

    return {
      'merged': false,
      'ticket_number': ticketNumber,
      'message': 'Tiket laporan baru berhasil dibuat dengan nomor $ticketNumber.',
    };
  }

  /// Update Status Laporan dengan State Machine Guard + Atomic Audit Trail
  Future<void> updateReportStatus({
    required String reportId,
    required AppUser actor,
    required ReportStatus newStatus,
    required String catatan,
    String? assignedTeknisiUid,
    String? assignedTeknisiNama,
    String? fotoSesudahUrl,
  }) async {
    if (actor.role == UserRole.pelapor) {
      throw Exception('403 Forbidden: Pelapor tidak diizinkan mengubah status pekerjaan.');
    }

    final reportRef = _db.collection('reports').doc(reportId);

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(reportRef);
      if (!snap.exists) {
        throw Exception('Laporan tidak ditemukan.');
      }

      final data = snap.data()!;
      final currentStatus = ReportStatus.fromString((data['status'] ?? 'reported').toString());

      if (!isValidTransition(currentStatus, newStatus)) {
        throw Exception(
          '422 Transisi Ilegal: Tidak dapat mengubah status dari ${currentStatus.value} langsung ke ${newStatus.value}.',
        );
      }

      if (newStatus == ReportStatus.assigned &&
          (assignedTeknisiUid == null || assignedTeknisiUid.isEmpty)) {
        throw Exception('422 Validasi Gagal: Wajib memilih Teknisi saat mengubah status ke Assigned.');
      }

      if (newStatus == ReportStatus.resolved &&
          (fotoSesudahUrl == null || fotoSesudahUrl.isEmpty)) {
        throw Exception('422 Validasi Gagal: Teknisi wajib mengunggah Foto Sesudah perbaikan sebelum menutup tiket ke Resolved.');
      }

      final updates = <String, dynamic>{
        'status': newStatus.value,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (assignedTeknisiUid != null) {
        updates['assigned_teknisi_uid'] = assignedTeknisiUid;
        updates['assigned_teknisi_nama'] = assignedTeknisiNama;
      }

      if (fotoSesudahUrl != null) {
        updates['foto_sesudah_url'] = fotoSesudahUrl;
      }

      transaction.update(reportRef, updates);

      final logRef = reportRef.collection('logs').doc();
      transaction.set(logRef, {
        'actor_uid': actor.uid,
        'actor_nama': actor.nama,
        'actor_role': actor.role.name,
        'status_lama': currentStatus.value,
        'status_baru': newStatus.value,
        'catatan': catatan,
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }
}