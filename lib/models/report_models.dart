import 'package:cloud_firestore/cloud_firestore.dart';

/// 3 Role sesuai Slide Opsi 5:
/// - pelapor (mahasiswa / dosen / staf)
/// - admin (admin fasilitas)
/// - teknisi (petugas perbaikan)
enum UserRole { pelapor, admin, teknisi }

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

class AppUser {
  final String uid;
  final String nama;
  final String identityNumber; // NIM / NIP
  final String email;
  final String subRole; // mahasiswa | dosen | staf | admin | teknisi
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.nama,
    required this.identityNumber,
    required this.email,
    required this.subRole,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final roleStr = (map['role'] ?? 'pelapor').toString();
    return AppUser(
      uid: uid,
      nama: (map['nama'] ?? '').toString(),
      identityNumber: (map['identity_number'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      subRole: (map['sub_role'] ?? 'mahasiswa').toString(),
      role: roleStr == 'admin'
          ? UserRole.admin
          : roleStr == 'teknisi'
              ? UserRole.teknisi
              : UserRole.pelapor,
    );
  }

  Map<String, dynamic> toMap() => {
        'nama': nama,
        'identity_number': identityNumber,
        'email': email,
        'sub_role': subRole,
        'role': role.name,
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
    final data = doc.data()!;
    return CampusLocation(
      id: doc.id,
      kodeRuangan: (data['kode_ruangan'] ?? '').toString(),
      namaGedung: (data['nama_gedung'] ?? '').toString(),
      namaRuangan: (data['nama_ruangan'] ?? '').toString(),
      lantai: (data['lantai'] as num?)?.toInt() ?? 1,
    );
  }
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
    final data = doc.data()!;
    return FacilityCategory(
      id: doc.id,
      namaObjek: (data['nama_objek'] ?? '').toString(),
      prioritasDefault: (data['prioritas_default'] ?? 'sedang').toString(),
      targetSlaJam: (data['target_sla_jam'] as num?)?.toInt() ?? 12,
    );
  }
}