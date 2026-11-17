import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_models.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Nilai status (string Firestore) yang dianggap tiket masih aktif.
  static const List<String> _activeStatusValues = [
    'reported',
    'verified',
    'assigned',
    'in_progress',
  ];

  /// ID dokumen kunci anti-duplikasi: active_tickets/{locationId}_{categoryId}.
  static String activeTicketKey(String locationId, String categoryId) =>
      '${locationId}_$categoryId';

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

  /// Tabel peran perubahan status:
  /// - verified / rejected / assigned : hanya admin
  /// - in_progress / resolved         : hanya teknisi yang ditugaskan di tiket
  /// - reported                       : tidak bisa di-set siapa pun
  /// [currentAssignedUid] adalah assigned_teknisi_uid pada tiket saat ini.
  static bool canChangeStatus({
    required UserRole role,
    required String actorUid,
    required ReportStatus newStatus,
    required String? currentAssignedUid,
  }) {
    switch (newStatus) {
      case ReportStatus.verified:
      case ReportStatus.rejected:
      case ReportStatus.assigned:
        return role == UserRole.admin;
      case ReportStatus.inProgress:
      case ReportStatus.resolved:
        return role == UserRole.teknisi &&
            currentAssignedUid != null &&
            currentAssignedUid.isNotEmpty &&
            currentAssignedUid == actorUid;
      case ReportStatus.reported:
        return false;
    }
  }

  /// Buat Laporan Baru (dengan Pengecekan Anti-Duplikasi + Auto-Upvote).
  ///
  /// Pengecekan duplikat dan pembuatan tiket terjadi dalam SATU transaksi
  /// lewat dokumen kunci `active_tickets/{locationId}_{categoryId}`, sehingga
  /// dua pelapor bersamaan tidak bisa membuat dua tiket aktif yang sama.
  Future<Map<String, dynamic>> submitReport({
    required AppUser reporter,
    required CampusLocation location,
    required FacilityCategory category,
    required String deskripsi,
    required String fotoSebelumUrl,
    String? aiSuggestedPriority,
  }) async {
    final now = DateTime.now();
    final slaDeadline = now.add(Duration(hours: category.targetSlaJam));
    final ticketNumber =
        'TKT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

    final lockRef = _db
        .collection('active_tickets')
        .doc(activeTicketKey(location.id, category.id));
    final reportRef = _db.collection('reports').doc();
    final logRef = reportRef.collection('logs').doc();
    final supporterRef = reportRef.collection('supporters').doc(reporter.uid);

    return _db.runTransaction<Map<String, dynamic>>((transaction) async {
      // ---- Semua pembacaan dilakukan lebih dulu (syarat transaksi Firestore) ----
      final lockSnap = await transaction.get(lockRef);

      DocumentReference<Map<String, dynamic>>? existingRef;
      Map<String, dynamic>? existingData;
      bool alreadySupported = false;

      if (lockSnap.exists) {
        final existingId = lockSnap.data()?['report_id'];
        if (existingId is String && existingId.isNotEmpty) {
          final candidateRef = _db.collection('reports').doc(existingId);
          final candidateSnap = await transaction.get(candidateRef);
          final candidateData = candidateSnap.data();
          // Kunci basi (laporan hilang / sudah resolved / rejected) diabaikan,
          // lalu ditimpa oleh tiket baru di bawah.
          if (candidateSnap.exists &&
              candidateData != null &&
              _activeStatusValues.contains(candidateData['status'])) {
            existingRef = candidateRef;
            existingData = candidateData;
            final existingSupporterSnap = await transaction
                .get(candidateRef.collection('supporters').doc(reporter.uid));
            alreadySupported = existingSupporterSnap.exists;
          }
        }
      }

      // ---- Cabang merge: tiket aktif sudah ada ----
      if (existingRef != null && existingData != null) {
        if (alreadySupported) {
          return {
            'merged': true,
            'already_supported': true,
            'ticket_number': existingData['ticket_number'],
            'message':
                'Fasilitas ini sudah dilaporkan dan sedang ditangani. Anda sudah tercatat sebagai pendukung tiket ini.',
          };
        }

        transaction.set(existingRef.collection('supporters').doc(reporter.uid), {
          'user_uid': reporter.uid,
          'nama': reporter.nama,
          'created_at': FieldValue.serverTimestamp(),
        });

        transaction.update(existingRef, {
          'upvotes_count': FieldValue.increment(1),
          'updated_at': FieldValue.serverTimestamp(),
        });

        return {
          'merged': true,
          'already_supported': false,
          'ticket_number': existingData['ticket_number'],
          'message':
              'Keluhan serupa di ruangan ini sudah aktif. Dukungan Anda (+1 Upvote) berhasil ditambahkan agar prioritas naik!',
        };
      }

      // ---- Cabang tiket baru: buat laporan + kunci secara atomik ----
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

      transaction.set(lockRef, {
        'report_id': reportRef.id,
        'location_id': location.id,
        'category_id': category.id,
        'created_at': Timestamp.fromDate(now),
      });

      return {
        'merged': false,
        'ticket_number': ticketNumber,
        'message': 'Tiket laporan baru berhasil dibuat dengan nomor $ticketNumber.',
      };
    });
  }

  /// Update Status Laporan dengan State Machine Guard + Atomic Audit Trail.
  ///
  /// Identitas dan role aktor dibaca dari `users/{actorUid}` di dalam transaksi
  /// (bukan dari objek kiriman UI). Saat tiket menjadi resolved/rejected,
  /// dokumen kunci `active_tickets` dihapus dalam transaksi yang sama.
  Future<void> updateReportStatus({
    required String reportId,
    required String actorUid,
    required ReportStatus newStatus,
    required String catatan,
    String? assignedTeknisiUid,
    String? fotoSesudahUrl,
  }) async {
    final reportRef = _db.collection('reports').doc(reportId);
    final actorRef = _db.collection('users').doc(actorUid);
    final hasTeknisiUid =
        assignedTeknisiUid != null && assignedTeknisiUid.isNotEmpty;
    final teknisiRef =
        hasTeknisiUid ? _db.collection('users').doc(assignedTeknisiUid) : null;

    await _db.runTransaction((transaction) async {
      // ---- Semua pembacaan dilakukan lebih dulu ----
      final actorSnap = await transaction.get(actorRef);
      final snap = await transaction.get(reportRef);
      final teknisiSnap = (newStatus == ReportStatus.assigned && teknisiRef != null)
          ? await transaction.get(teknisiRef)
          : null;

      final actorData = actorSnap.data();
      if (!actorSnap.exists || actorData == null) {
        throw Exception('403 Forbidden: Akun pengguna tidak ditemukan.');
      }
      final actor = AppUser.fromMap(actorUid, actorData);

      final data = snap.data();
      if (!snap.exists || data == null) {
        throw Exception('Laporan tidak ditemukan.');
      }

      final currentStatus = ReportStatus.fromString((data['status'] ?? 'reported').toString());

      // ---- Otorisasi berdasarkan tabel peran ----
      final currentAssignedUid = data['assigned_teknisi_uid'] as String?;
      if (!canChangeStatus(
        role: actor.role,
        actorUid: actorUid,
        newStatus: newStatus,
        currentAssignedUid: currentAssignedUid,
      )) {
        throw Exception(
          '403 Forbidden: Peran ${actor.role.name} tidak diizinkan mengubah status ke ${newStatus.value} pada tiket ini.',
        );
      }

      if (!isValidTransition(currentStatus, newStatus)) {
        throw Exception(
          '422 Transisi Ilegal: Tidak dapat mengubah status dari ${currentStatus.value} langsung ke ${newStatus.value}.',
        );
      }

      // ---- Validasi parameter ----
      if (newStatus == ReportStatus.rejected && catatan.trim().isEmpty) {
        throw Exception('422 Validasi Gagal: Alasan penolakan (catatan) wajib diisi.');
      }

      if (newStatus != ReportStatus.assigned && assignedTeknisiUid != null) {
        throw Exception('422 Validasi Gagal: Teknisi hanya dapat dipilih saat status diubah ke Assigned.');
      }

      String? teknisiNama;
      if (newStatus == ReportStatus.assigned) {
        if (!hasTeknisiUid) {
          throw Exception('422 Validasi Gagal: Wajib memilih Teknisi saat mengubah status ke Assigned.');
        }
        final teknisiData = teknisiSnap?.data();
        if (teknisiSnap == null || !teknisiSnap.exists || teknisiData == null) {
          throw Exception('422 Validasi Gagal: Teknisi yang dipilih tidak ditemukan.');
        }
        final teknisi = AppUser.fromMap(assignedTeknisiUid, teknisiData);
        if (teknisi.role != UserRole.teknisi) {
          throw Exception('422 Validasi Gagal: Pengguna yang dipilih bukan berperan Teknisi.');
        }
        teknisiNama = teknisi.nama;
      }

      if (newStatus == ReportStatus.resolved &&
          (fotoSesudahUrl == null || fotoSesudahUrl.isEmpty)) {
        throw Exception('422 Validasi Gagal: Teknisi wajib mengunggah Foto Sesudah perbaikan sebelum menutup tiket ke Resolved.');
      }

      // Dokumen kunci dibaca (bila perlu) sebelum penulisan apa pun.
      DocumentReference<Map<String, dynamic>>? lockToDelete;
      if (newStatus == ReportStatus.resolved || newStatus == ReportStatus.rejected) {
        final lockRef = _db.collection('active_tickets').doc(
              activeTicketKey(
                (data['location_id'] ?? '').toString(),
                (data['category_id'] ?? '').toString(),
              ),
            );
        final lockSnap = await transaction.get(lockRef);
        // Hanya hapus kunci milik tiket ini; kunci yang menunjuk tiket lain dibiarkan.
        if (lockSnap.exists && lockSnap.data()?['report_id'] == reportId) {
          lockToDelete = lockRef;
        }
      }

      // ---- Penulisan ----
      final updates = <String, dynamic>{
        'status': newStatus.value,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (newStatus == ReportStatus.assigned) {
        updates['assigned_teknisi_uid'] = assignedTeknisiUid;
        updates['assigned_teknisi_nama'] = teknisiNama;
      }

      if (fotoSesudahUrl != null) {
        updates['foto_sesudah_url'] = fotoSesudahUrl;
      }

      transaction.update(reportRef, updates);

      if (lockToDelete != null) {
        transaction.delete(lockToDelete);
      }

      final logRef = reportRef.collection('logs').doc();
      transaction.set(logRef, {
        'actor_uid': actorUid,
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
