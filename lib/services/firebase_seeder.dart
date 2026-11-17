import 'package:cloud_firestore/cloud_firestore.dart';

/// Jumlah dokumen master data yang ditulis oleh satu kali seeding.
/// Nilai 0 berarti koleksi tersebut sudah berisi sehingga dilewati.
class SeedResult {
  const SeedResult({
    required this.categoriesSeeded,
    required this.locationsSeeded,
  });

  final int categoriesSeeded;
  final int locationsSeeded;

  bool get nothingToDo => categoriesSeeded == 0 && locationsSeeded == 0;
}

/// Mengisi master data `categories` dan `locations`.
///
/// Penulisan hanya diizinkan untuk admin (lihat `firestore.rules`), jadi
/// seeder ini dipicu MANUAL dari dashboard admin (tombol "Isi Data Master"),
/// bukan otomatis dari `main()`.
class FirebaseSeeder {
  FirebaseSeeder({FirebaseFirestore? firestore}) : _dbOverride = firestore;

  final FirebaseFirestore? _dbOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  /// 6 Objek Kerusakan sesuai Slide Opsi 5 Dosen.
  static const List<Map<String, Object>> categoryData = [
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

  /// 10 Lokasi Ruangan/Aset dengan Kode QR Terstandarisasi.
  static const List<Map<String, Object>> locationData = [
    {
      'id': 'loc_r101',
      'kode_ruangan': 'QR-GDA-101',
      'nama_gedung': 'Gedung A Fasilkom-TI',
      'nama_ruangan': 'Ruang Kuliah A-101',
      'lantai': 1,
    },
    {
      'id': 'loc_r102',
      'kode_ruangan': 'QR-GDA-102',
      'nama_gedung': 'Gedung A Fasilkom-TI',
      'nama_ruangan': 'Ruang Kuliah A-102',
      'lantai': 1,
    },
    {
      'id': 'loc_r201',
      'kode_ruangan': 'QR-GDA-201',
      'nama_gedung': 'Gedung A Fasilkom-TI',
      'nama_ruangan': 'Ruang Kuliah A-201',
      'lantai': 2,
    },
    {
      'id': 'loc_tlt2',
      'kode_ruangan': 'QR-GDA-TLT2',
      'nama_gedung': 'Gedung A Fasilkom-TI',
      'nama_ruangan': 'Toilet Mahasiswa Lt. 2',
      'lantai': 2,
    },
    {
      'id': 'loc_lab1',
      'kode_ruangan': 'QR-LAB-301',
      'nama_gedung': 'Gedung Laboratorium',
      'nama_ruangan': 'Lab Pemrograman Mobile',
      'lantai': 3,
    },
    {
      'id': 'loc_lab2',
      'kode_ruangan': 'QR-LAB-302',
      'nama_gedung': 'Gedung Laboratorium',
      'nama_ruangan': 'Lab Jaringan Komputer',
      'lantai': 3,
    },
    {
      'id': 'loc_lab3',
      'kode_ruangan': 'QR-LAB-303',
      'nama_gedung': 'Gedung Laboratorium',
      'nama_ruangan': 'Lab Sistem Informasi',
      'lantai': 3,
    },
    {
      'id': 'loc_aud1',
      'kode_ruangan': 'QR-AUD-101',
      'nama_gedung': 'Gedung Auditorium',
      'nama_ruangan': 'Aula Utama Lt. 1',
      'lantai': 1,
    },
    {
      'id': 'loc_prp1',
      'kode_ruangan': 'QR-PRP-101',
      'nama_gedung': 'Gedung Perpustakaan',
      'nama_ruangan': 'Ruang Baca Digital',
      'lantai': 1,
    },
    {
      'id': 'loc_dkn1',
      'kode_ruangan': 'QR-DKN-101',
      'nama_gedung': 'Gedung Dekanat',
      'nama_ruangan': 'Ruang Pelayanan Akademik',
      'lantai': 1,
    },
  ];

  /// Mengisi `categories` dan `locations`, masing-masing hanya bila
  /// koleksinya masih kosong. Aman dijalankan ulang (idempoten).
  ///
  /// Melempar [FirebaseException] (mis. `permission-denied` bila bukan admin,
  /// `unavailable` bila offline). Bila `categories` sudah terisi tetapi
  /// `locations` gagal, menjalankannya lagi hanya mengisi yang belum ada.
  Future<SeedResult> seedMasterDataIfNeeded() async {
    final categories = await seedCategoriesIfNeeded();
    final locations = await seedLocationsIfNeeded();
    return SeedResult(categoriesSeeded: categories, locationsSeeded: locations);
  }

  /// Mengisi `categories` bila kosong. Mengembalikan jumlah dokumen ditulis.
  Future<int> seedCategoriesIfNeeded() =>
      _seedIfEmpty('categories', categoryData);

  /// Mengisi `locations` bila kosong. Mengembalikan jumlah dokumen ditulis.
  Future<int> seedLocationsIfNeeded() =>
      _seedIfEmpty('locations', locationData);

  Future<int> _seedIfEmpty(
    String collection,
    List<Map<String, Object>> items,
  ) async {
    // Source.server: jangan percaya cache lokal untuk keputusan "sudah ada?".
    // Saat offline ini melempar `unavailable` alih-alih diam-diam menulis.
    final probe = await _db
        .collection(collection)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (probe.docs.isNotEmpty) return 0;

    final batch = _db.batch();
    for (final item in items) {
      batch.set(_db.collection(collection).doc(item['id'] as String), item);
    }
    await batch.commit();
    return items.length;
  }
}
