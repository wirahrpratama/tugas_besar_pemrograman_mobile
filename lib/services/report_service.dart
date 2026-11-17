import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report_models.dart';

class ReportService {
  ReportService({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

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

  /// Nomor tiket `TKT-YYYYMMDD-XXXXXX`: tanggal [date] (jam perangkat) diikuti
  /// 6 karakter pertama ID dokumen laporan [reportId].
  static String ticketNumberFor(DateTime date, String reportId) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final suffix = reportId.length > 6 ? reportId.substring(0, 6) : reportId;
    return 'TKT-$y$m$d-$suffix';
  }

  /// Validasi State Machine sesuai Slide Opsi 5:
  /// reported -> verified -> assigned -> in_progress -> resolved
  /// serta resolved -> in_progress (hanya lewat [confirmResolution]).
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
        return next == ReportStatus.inProgress;
      case ReportStatus.rejected:
        return false;
    }
  }

  /// Tabel peran perubahan status lewat [updateReportStatus]:
  /// - verified / rejected / assigned : hanya admin
  /// - in_progress / resolved         : hanya teknisi yang ditugaskan di tiket
  /// - reported                       : tidak bisa di-set siapa pun
  ///
  /// Pengembalian `resolved -> in_progress` hanya melalui [confirmResolution]
  /// oleh pelapor asli.
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
  ///
  /// Semua `created_at`/`updated_at` memakai `serverTimestamp()`. Hanya
  /// `sla_deadline` dan tanggal pada nomor tiket yang berasal dari jam perangkat.
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
    final rawPriority = aiSuggestedPriority?.trim();
    final prioritas = (rawPriority != null && rawPriority.isNotEmpty)
        ? rawPriority.toLowerCase()
        : category.prioritasDefault;

    final lockRef = _db
        .collection('active_tickets')
        .doc(activeTicketKey(location.id, category.id));
    final reportRef = _db.collection('reports').doc();
    final ticketNumber = ticketNumberFor(now, reportRef.id);
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
          'supporter_uids': FieldValue.arrayUnion(<String>[reporter.uid]),
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
        'prioritas': prioritas,
        'prioritas_rank': Report.priorityRankFor(prioritas),
        'target_sla_jam': category.targetSlaJam,
        'deskripsi': deskripsi,
        'foto_sebelum_url': fotoSebelumUrl,
        'foto_sesudah_url': null,
        'status': ReportStatus.reported.value,
        'assigned_teknisi_uid': null,
        'assigned_teknisi_nama': null,
        'upvotes_count': 1,
        'supporter_uids': <String>[reporter.uid],
        'confirmed_by_reporter': false,
        'created_at': FieldValue.serverTimestamp(),
        'sla_deadline': Timestamp.fromDate(slaDeadline),
        'updated_at': FieldValue.serverTimestamp(),
      });

      transaction.set(supporterRef, {
        'user_uid': reporter.uid,
        'nama': reporter.nama,
        'created_at': FieldValue.serverTimestamp(),
      });

      transaction.set(logRef, {
        'actor_uid': reporter.uid,
        'actor_nama': reporter.nama,
        'actor_role': reporter.role.name,
        'status_lama': null,
        'status_baru': ReportStatus.reported.value,
        'catatan': 'Laporan awal dibuat melalui aplikasi.',
        'created_at': FieldValue.serverTimestamp(),
      });

      transaction.set(lockRef, {
        'report_id': reportRef.id,
        'location_id': location.id,
        'category_id': category.id,
        'created_at': FieldValue.serverTimestamp(),
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

      final currentStatus =
          ReportStatus.fromString((data['status'] ?? 'reported').toString());

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

      if (currentStatus == ReportStatus.resolved &&
          newStatus == ReportStatus.inProgress) {
        throw Exception(
          '403 Forbidden: Pengembalian status dari resolved ke in_progress hanya dapat dilakukan melalui konfirmasi pelapor.',
        );
      }

      if (!isValidTransition(currentStatus, newStatus)) {
        throw Exception(
          '422 Transisi Ilegal: Tidak dapat mengubah status dari ${currentStatus.value} langsung ke ${newStatus.value}.',
        );
      }

      // ---- Validasi parameter ----
      if (newStatus == ReportStatus.rejected && catatan.trim().isEmpty) {
        throw Exception(
          '422 Validasi Gagal: Alasan penolakan (catatan) wajib diisi.',
        );
      }

      if (newStatus != ReportStatus.assigned && assignedTeknisiUid != null) {
        throw Exception(
          '422 Validasi Gagal: Teknisi hanya dapat dipilih saat status diubah ke Assigned.',
        );
      }

      String? teknisiNama;
      if (newStatus == ReportStatus.assigned) {
        if (!hasTeknisiUid) {
          throw Exception(
            '422 Validasi Gagal: Wajib memilih Teknisi saat mengubah status ke Assigned.',
          );
        }
        final teknisiData = teknisiSnap?.data();
        if (teknisiSnap == null || !teknisiSnap.exists || teknisiData == null) {
          throw Exception(
            '422 Validasi Gagal: Teknisi yang dipilih tidak ditemukan.',
          );
        }
        final teknisi = AppUser.fromMap(assignedTeknisiUid, teknisiData);
        if (teknisi.role != UserRole.teknisi) {
          throw Exception(
            '422 Validasi Gagal: Pengguna yang dipilih bukan berperan Teknisi.',
          );
        }
        teknisiNama = teknisi.nama;
      }

      if (newStatus == ReportStatus.resolved &&
          (fotoSesudahUrl == null || fotoSesudahUrl.isEmpty)) {
        throw Exception(
          '422 Validasi Gagal: Teknisi wajib mengunggah Foto Sesudah perbaikan sebelum menutup tiket ke Resolved.',
        );
      }

      // Dokumen kunci dibaca (bila perlu) sebelum penulisan apa pun.
      DocumentReference<Map<String, dynamic>>? lockToDelete;
      if (newStatus == ReportStatus.resolved ||
          newStatus == ReportStatus.rejected) {
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

  /// Konfirmasi penyelesaian perbaikan oleh pelapor asli pada tiket `resolved`.
  ///
  /// - Jika [diterima] == `true`: menandai `confirmed_by_reporter = true` dan
  ///   mencatat log konfirmasi (`resolved -> resolved`).
  /// - Jika [diterima] == `false`: [catatan] wajib diisi; status dikembalikan
  ///   ke `in_progress`, kunci `active_tickets` dipulihkan bila slot masih kosong,
  ///   dan log penolakan (`resolved -> in_progress`) dicatat atomik.
  Future<void> confirmResolution(
    String reportId,
    String actorUid, {
    required bool diterima,
    String? catatan,
  }) async {
    final reportRef = _db.collection('reports').doc(reportId);
    final actorRef = _db.collection('users').doc(actorUid);

    await _db.runTransaction((transaction) async {
      // ---- Semua pembacaan dilakukan lebih dulu ----
      final actorSnap = await transaction.get(actorRef);
      final snap = await transaction.get(reportRef);

      final actorData = actorSnap.data();
      if (!actorSnap.exists || actorData == null) {
        throw Exception('403 Forbidden: Akun pengguna tidak ditemukan.');
      }
      final actor = AppUser.fromMap(actorUid, actorData);

      final data = snap.data();
      if (!snap.exists || data == null) {
        throw Exception('Laporan tidak ditemukan.');
      }

      if (data['reporter_uid'] != actorUid) {
        throw Exception(
          '403 Forbidden: Hanya pelapor asli yang dapat mengonfirmasi penyelesaian laporan.',
        );
      }

      final currentStatus =
          ReportStatus.fromString((data['status'] ?? 'reported').toString());
      if (currentStatus != ReportStatus.resolved) {
        throw Exception(
          '422 Transisi Ilegal: Konfirmasi hanya dapat dilakukan pada laporan berstatus resolved.',
        );
      }

      if (data['confirmed_by_reporter'] == true) {
        throw Exception(
          '422 Validasi Gagal: Penyelesaian laporan sudah pernah dikonfirmasi.',
        );
      }

      final trimmedCatatan = (catatan ?? '').trim();
      if (!diterima && trimmedCatatan.isEmpty) {
        throw Exception(
          '422 Validasi Gagal: Alasan penolakan (catatan) wajib diisi saat menolak hasil perbaikan.',
        );
      }

      final locationId = (data['location_id'] ?? '').toString();
      final categoryId = (data['category_id'] ?? '').toString();
      DocumentReference<Map<String, dynamic>>? lockToRestore;
      if (!diterima && locationId.isNotEmpty && categoryId.isNotEmpty) {
        final lockRef = _db
            .collection('active_tickets')
            .doc(activeTicketKey(locationId, categoryId));
        final lockSnap = await transaction.get(lockRef);
        if (!lockSnap.exists) {
          lockToRestore = lockRef;
        } else {
          final lockReportId = lockSnap.data()?['report_id'];
          if (lockReportId is! String || lockReportId.isEmpty) {
            lockToRestore = lockRef;
          } else {
            final lockReportSnap =
                await transaction.get(_db.collection('reports').doc(lockReportId));
            final lockReportStatus = lockReportSnap.data()?['status'];
            if (!lockReportSnap.exists ||
                !_activeStatusValues.contains(lockReportStatus)) {
              lockToRestore = lockRef;
            }
          }
        }
      }

      // ---- Penulisan ----
      final nextStatus =
          diterima ? ReportStatus.resolved : ReportStatus.inProgress;
      final logCatatan = trimmedCatatan.isNotEmpty
          ? trimmedCatatan
          : 'Perbaikan dikonfirmasi selesai oleh pelapor.';

      final updates = <String, dynamic>{
        'confirmed_by_reporter': diterima,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (!diterima) {
        updates['status'] = ReportStatus.inProgress.value;
      }

      transaction.update(reportRef, updates);

      if (lockToRestore != null) {
        transaction.set(lockToRestore, {
          'report_id': reportId,
          'location_id': locationId,
          'category_id': categoryId,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      final logRef = reportRef.collection('logs').doc();
      transaction.set(logRef, {
        'actor_uid': actorUid,
        'actor_nama': actor.nama,
        'actor_role': actor.role.name,
        'status_lama': ReportStatus.resolved.value,
        'status_baru': nextStatus.value,
        'catatan': logCatatan,
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }
}
