import 'package:cloud_firestore/cloud_firestore.dart';

/// 3 Role sesuai Slide Opsi 5:
/// - pelapor (mahasiswa / dosen / staf)
/// - admin (admin fasilitas)
/// - teknisi (petugas perbaikan)
enum UserRole {
  pelapor,
  admin,
  teknisi;

  static UserRole fromString(String raw) {
    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'teknisi':
        return UserRole.teknisi;
      default:
        return UserRole.pelapor;
    }
  }
}

/// 5 Status resmi sesuai Slide Opsi 5 (+ rejected jika laporan tidak valid)
enum ReportStatus {
  reported,
  verified,
  assigned,
  inProgress,
  resolved,
  rejected;

  String get value {
    switch (this) {
      case ReportStatus.reported:
        return 'reported';
      case ReportStatus.verified:
        return 'verified';
      case ReportStatus.assigned:
        return 'assigned';
      case ReportStatus.inProgress:
        return 'in_progress';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case ReportStatus.reported:
        return 'Reported (Menunggu Verifikasi)';
      case ReportStatus.verified:
        return 'Verified (Terverifikasi Admin)';
      case ReportStatus.assigned:
        return 'Assigned (Teknisi Ditugaskan)';
      case ReportStatus.inProgress:
        return 'In Progress (Sedang Dikerjakan)';
      case ReportStatus.resolved:
        return 'Resolved (Selesai Diperbaiki)';
      case ReportStatus.rejected:
        return 'Rejected (Ditolak)';
    }
  }

  static ReportStatus fromString(String raw) {
    switch (raw) {
      case 'verified':
        return ReportStatus.verified;
      case 'assigned':
        return ReportStatus.assigned;
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'resolved':
        return ReportStatus.resolved;
      case 'rejected':
        return ReportStatus.rejected;
      default:
        return ReportStatus.reported;
    }
  }
}

Map<String, dynamic> _requireDocData(
  DocumentSnapshot<Map<String, dynamic>> doc,
  String label,
) {
  if (!doc.exists) {
    throw StateError('Dokumen $label (${doc.id}) tidak ditemukan.');
  }
  final data = doc.data();
  if (data == null) {
    throw StateError('Data $label (${doc.id}) kosong.');
  }
  return data;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}

List<String> _parseStringList(dynamic value) {
  if (value is! Iterable) return const <String>[];
  return value
      .where((e) => e != null)
      .map((e) => e.toString())
      .where((e) => e.isNotEmpty)
      .toList();
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  return str.isEmpty ? null : str;
}

class AppUser {
  final String uid;
  final String nama;
  final String identityNumber; // NIM / NIP
  final String email;
  final String subRole; // mahasiswa | dosen | staf | admin | teknisi
  final UserRole role;
  final String? photoUrl;
  final String? pendingEmail;

  const AppUser({
    required this.uid,
    required this.nama,
    required this.identityNumber,
    required this.email,
    required this.subRole,
    required this.role,
    this.photoUrl,
    this.pendingEmail,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final roleStr = (map['role'] ?? 'pelapor').toString();
    return AppUser(
      uid: uid,
      nama: (map['nama'] ?? '').toString(),
      identityNumber: (map['identity_number'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      subRole: (map['sub_role'] ?? 'mahasiswa').toString(),
      role: UserRole.fromString(roleStr),
      photoUrl: _nullableString(map['photo_url']),
      pendingEmail: _nullableString(map['pending_email']),
    );
  }

  Map<String, dynamic> toMap() => {
        'nama': nama,
        'identity_number': identityNumber,
        'email': email,
        'sub_role': subRole,
        'role': role.name,
        if (photoUrl != null) 'photo_url': photoUrl,
        if (pendingEmail != null) 'pending_email': pendingEmail,
      };
}

class CampusLocation {
  final String id;
  final String kodeRuangan; // Nilai yang di-encode ke QR Code ruangan/aset
  final String namaGedung;
  final String namaRuangan;
  final int lantai;

  const CampusLocation({
    required this.id,
    required this.kodeRuangan,
    required this.namaGedung,
    required this.namaRuangan,
    required this.lantai,
  });

  factory CampusLocation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return CampusLocation.fromMap(doc.id, _requireDocData(doc, 'lokasi'));
  }

  factory CampusLocation.fromMap(String id, Map<String, dynamic> data) {
    return CampusLocation(
      id: id,
      kodeRuangan: (data['kode_ruangan'] ?? '').toString(),
      namaGedung: (data['nama_gedung'] ?? '').toString(),
      namaRuangan: (data['nama_ruangan'] ?? '').toString(),
      lantai: (data['lantai'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'kode_ruangan': kodeRuangan,
        'nama_gedung': namaGedung,
        'nama_ruangan': namaRuangan,
        'lantai': lantai,
      };
}

class FacilityCategory {
  final String id;
  final String namaObjek; // AC, Proyektor, Jaringan, Lampu, Toilet, Ruang Kelas
  final String prioritasDefault; // rendah, sedang, tinggi, darurat
  final int targetSlaJam;

  const FacilityCategory({
    required this.id,
    required this.namaObjek,
    required this.prioritasDefault,
    required this.targetSlaJam,
  });

  factory FacilityCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return FacilityCategory.fromMap(doc.id, _requireDocData(doc, 'kategori'));
  }

  factory FacilityCategory.fromMap(String id, Map<String, dynamic> data) {
    return FacilityCategory(
      id: id,
      namaObjek: (data['nama_objek'] ?? '').toString(),
      prioritasDefault: (data['prioritas_default'] ?? 'sedang').toString(),
      targetSlaJam: (data['target_sla_jam'] as num?)?.toInt() ?? 12,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nama_objek': namaObjek,
        'prioritas_default': prioritasDefault,
        'target_sla_jam': targetSlaJam,
      };
}

class Report {
  final String id;
  final String ticketNumber;
  final String reporterUid;
  final String reporterName;
  final String reporterSubRole;
  final String locationId;
  final String kodeRuangan;
  final String namaGedung;
  final String namaRuangan;
  final String categoryId;
  final String namaObjek;
  final String prioritas;
  final int prioritasRank;
  final int targetSlaJam;
  final String deskripsi;
  final String fotoSebelumUrl;
  final String? fotoSesudahUrl;
  final ReportStatus status;
  final String? assignedTeknisiUid;
  final String? assignedTeknisiNama;
  final int upvotesCount;
  final List<String> supporterUids;
  final bool confirmedByReporter;
  final DateTime? createdAt;
  final DateTime? slaDeadline;
  final DateTime? updatedAt;

  const Report({
    required this.id,
    required this.ticketNumber,
    required this.reporterUid,
    required this.reporterName,
    required this.reporterSubRole,
    required this.locationId,
    required this.kodeRuangan,
    required this.namaGedung,
    required this.namaRuangan,
    required this.categoryId,
    required this.namaObjek,
    required this.prioritas,
    required this.prioritasRank,
    required this.targetSlaJam,
    required this.deskripsi,
    required this.fotoSebelumUrl,
    this.fotoSesudahUrl,
    required this.status,
    this.assignedTeknisiUid,
    this.assignedTeknisiNama,
    required this.upvotesCount,
    required this.supporterUids,
    required this.confirmedByReporter,
    this.createdAt,
    this.slaDeadline,
    this.updatedAt,
  });

  /// Peringkat numerik untuk pengurutan antrean (lebih kecil = lebih mendesak).
  static int priorityRankFor(String prioritas) {
    switch (prioritas.trim().toLowerCase()) {
      case 'darurat':
        return 1;
      case 'tinggi':
        return 2;
      case 'sedang':
        return 3;
      case 'rendah':
        return 4;
      default:
        return 3;
    }
  }

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Report.fromMap(doc.id, _requireDocData(doc, 'laporan'));
  }

  factory Report.fromMap(String id, Map<String, dynamic> data) {
    final reporterUid = (data['reporter_uid'] ?? '').toString();
    final prioritas = (data['prioritas'] ?? 'sedang').toString();
    final parsedSupporters = _parseStringList(data['supporter_uids']);
    final supporterUids = parsedSupporters.isEmpty && reporterUid.isNotEmpty
        ? <String>[reporterUid]
        : parsedSupporters;

    return Report(
      id: id,
      ticketNumber: (data['ticket_number'] ?? '').toString(),
      reporterUid: reporterUid,
      reporterName: (data['reporter_name'] ?? '').toString(),
      reporterSubRole: (data['reporter_sub_role'] ?? 'mahasiswa').toString(),
      locationId: (data['location_id'] ?? '').toString(),
      kodeRuangan: (data['kode_ruangan'] ?? '').toString(),
      namaGedung: (data['nama_gedung'] ?? '').toString(),
      namaRuangan: (data['nama_ruangan'] ?? '').toString(),
      categoryId: (data['category_id'] ?? '').toString(),
      namaObjek: (data['nama_objek'] ?? '').toString(),
      prioritas: prioritas,
      prioritasRank:
          (data['prioritas_rank'] as num?)?.toInt() ?? priorityRankFor(prioritas),
      targetSlaJam: (data['target_sla_jam'] as num?)?.toInt() ?? 12,
      deskripsi: (data['deskripsi'] ?? '').toString(),
      fotoSebelumUrl: (data['foto_sebelum_url'] ?? '').toString(),
      fotoSesudahUrl: _nullableString(data['foto_sesudah_url']),
      status: ReportStatus.fromString((data['status'] ?? 'reported').toString()),
      assignedTeknisiUid: _nullableString(data['assigned_teknisi_uid']),
      assignedTeknisiNama: _nullableString(data['assigned_teknisi_nama']),
      upvotesCount: (data['upvotes_count'] as num?)?.toInt() ?? 1,
      supporterUids: List<String>.unmodifiable(supporterUids),
      confirmedByReporter: data['confirmed_by_reporter'] == true,
      createdAt: _parseDateTime(data['created_at']),
      slaDeadline: _parseDateTime(data['sla_deadline']),
      updatedAt: _parseDateTime(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'ticket_number': ticketNumber,
        'reporter_uid': reporterUid,
        'reporter_name': reporterName,
        'reporter_sub_role': reporterSubRole,
        'location_id': locationId,
        'kode_ruangan': kodeRuangan,
        'nama_gedung': namaGedung,
        'nama_ruangan': namaRuangan,
        'category_id': categoryId,
        'nama_objek': namaObjek,
        'prioritas': prioritas,
        'prioritas_rank': prioritasRank,
        'target_sla_jam': targetSlaJam,
        'deskripsi': deskripsi,
        'foto_sebelum_url': fotoSebelumUrl,
        'foto_sesudah_url': fotoSesudahUrl,
        'status': status.value,
        'assigned_teknisi_uid': assignedTeknisiUid,
        'assigned_teknisi_nama': assignedTeknisiNama,
        'upvotes_count': upvotesCount,
        'supporter_uids': List<String>.from(supporterUids),
        'confirmed_by_reporter': confirmedByReporter,
        'created_at':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'sla_deadline':
            slaDeadline != null ? Timestamp.fromDate(slaDeadline!) : null,
        'updated_at':
            updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };
}

class ReportLog {
  final String id;
  final String actorUid;
  final String actorNama;
  final UserRole actorRole;
  final ReportStatus? statusLama;
  final ReportStatus statusBaru;
  final String catatan;
  final DateTime? createdAt;

  const ReportLog({
    required this.id,
    required this.actorUid,
    required this.actorNama,
    required this.actorRole,
    this.statusLama,
    required this.statusBaru,
    required this.catatan,
    this.createdAt,
  });

  factory ReportLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ReportLog.fromMap(doc.id, _requireDocData(doc, 'log laporan'));
  }

  factory ReportLog.fromMap(String id, Map<String, dynamic> data) {
    final rawOld = _nullableString(data['status_lama']);
    return ReportLog(
      id: id,
      actorUid: (data['actor_uid'] ?? '').toString(),
      actorNama: (data['actor_nama'] ?? '').toString(),
      actorRole: UserRole.fromString((data['actor_role'] ?? 'pelapor').toString()),
      statusLama: rawOld != null ? ReportStatus.fromString(rawOld) : null,
      statusBaru:
          ReportStatus.fromString((data['status_baru'] ?? 'reported').toString()),
      catatan: (data['catatan'] ?? '').toString(),
      createdAt: _parseDateTime(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'actor_uid': actorUid,
        'actor_nama': actorNama,
        'actor_role': actorRole.name,
        'status_lama': statusLama?.value,
        'status_baru': statusBaru.value,
        'catatan': catatan,
        'created_at':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };
}

class Supporter {
  final String userUid;
  final String nama;
  final DateTime? createdAt;

  const Supporter({
    required this.userUid,
    required this.nama,
    this.createdAt,
  });

  factory Supporter.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Supporter.fromMap(doc.id, _requireDocData(doc, 'pendukung'));
  }

  factory Supporter.fromMap(String id, Map<String, dynamic> data) {
    final uid = _nullableString(data['user_uid']) ?? id;
    return Supporter(
      userUid: uid,
      nama: (data['nama'] ?? '').toString(),
      createdAt: _parseDateTime(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'user_uid': userUid,
        'nama': nama,
        'created_at':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      };
}
