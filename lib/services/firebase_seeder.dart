import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Panggil sekali saat aplikasi pertama kali dijalankan untuk mengisi 6 Objek & 10 Ruangan
  Future<void> seedMasterDataIfNeeded() async {
    final categoriesSnap = await _db.collection('categories').limit(1).get();
    if (categoriesSnap.docs.isEmpty) {
      final batch = _db.batch();

      // 6 Objek Kerusakan sesuai Slide Opsi 5 Dosen
      final categories = [
        {
          'id': 'cat_ac',
          'nama_objek': 'AC & Pendingin Ruangan',
          'prioritas_default': 'tinggi',
          'target_sla_jam': 6,
        },
        {
          'id': 'cat_proyektor',
          'nama_objek': 'Proyektor & Layar Presentasi',
          'prioritas_default': 'tinggi',
          'target_sla_jam': 4,
        },
        {
          'id': 'cat_jaringan',
          'nama_objek': 'Jaringan Wi-Fi & Kabel LAN',
          'prioritas_default': 'tinggi',
          'target_sla_jam': 4,
        },
        {
          'id': 'cat_lampu',
          'nama_objek': 'Lampu & Kelistrikan Ruangan',
          'prioritas_default': 'darurat',
          'target_sla_jam': 2,
        },
        {
          'id': 'cat_toilet',
          'nama_objek': 'Toilet & Sanitasi Air',
          'prioritas_default': 'sedang',
          'target_sla_jam': 8,
        },
        {
          'id': 'cat_ruang_kelas',
          'nama_objek': 'Ruang Kelas (Kursi, Meja, Pintu, Papan Tulis)',
          'prioritas_default': 'rendah',
          'target_sla_jam': 24,
        },
      ];

      for (final item in categories) {
        final ref = _db.collection('categories').doc(item['id'] as String);
        batch.set(ref, item);
      }

      // 10 Lokasi Ruangan/Aset dengan Kode QR Terstandarisasi
      final locations = [
        {'id': 'loc_r101', 'kode_ruangan': 'QR-GDA-101', 'nama_gedung': 'Gedung A Fasilkom-TI', 'nama_ruangan': 'Ruang Kuliah A-101', 'lantai': 1},
        {'id': 'loc_r102', 'kode_ruangan': 'QR-GDA-102', 'nama_gedung': 'Gedung A Fasilkom-TI', 'nama_ruangan': 'Ruang Kuliah A-102', 'lantai': 1},
        {'id': 'loc_r201', 'kode_ruangan': 'QR-GDA-201', 'nama_gedung': 'Gedung A Fasilkom-TI', 'nama_ruangan': 'Ruang Kuliah A-201', 'lantai': 2},
        {'id': 'loc_tlt2', 'kode_ruangan': 'QR-GDA-TLT2', 'nama_gedung': 'Gedung A Fasilkom-TI', 'nama_ruangan': 'Toilet Mahasiswa Lt. 2', 'lantai': 2},
        {'id': 'loc_lab1', 'kode_ruangan': 'QR-LAB-301', 'nama_gedung': 'Gedung Laboratorium', 'nama_ruangan': 'Lab Pemrograman Mobile', 'lantai': 3},
        {'id': 'loc_lab2', 'kode_ruangan': 'QR-LAB-302', 'nama_gedung': 'Gedung Laboratorium', 'nama_ruangan': 'Lab Jaringan Komputer', 'lantai': 3},
        {'id': 'loc_lab3', 'kode_ruangan': 'QR-LAB-303', 'nama_gedung': 'Gedung Laboratorium', 'nama_ruangan': 'Lab Sistem Informasi', 'lantai': 3},
        {'id': 'loc_aud1', 'kode_ruangan': 'QR-AUD-101', 'nama_gedung': 'Gedung Auditorium', 'nama_ruangan': 'Aula Utama Lt. 1', 'lantai': 1},
        {'id': 'loc_prp1', 'kode_ruangan': 'QR-PRP-101', 'nama_gedung': 'Gedung Perpustakaan', 'nama_ruangan': 'Ruang Baca Digital', 'lantai': 1},
        {'id': 'loc_dkn1', 'kode_ruangan': 'QR-DKN-101', 'nama_gedung': 'Gedung Dekanat', 'nama_ruangan': 'Ruang Pelayanan Akademik', 'lantai': 1},
      ];

      for (final loc in locations) {
        final ref = _db.collection('locations').doc(loc['id'] as String);
        batch.set(ref, loc);
      }

      await batch.commit();
    }
  }
}