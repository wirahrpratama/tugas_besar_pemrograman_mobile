import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/photo_store.dart';
import 'package:sifasilitas/widgets/report_photo.dart';

// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _FakeDocumentSnapshot({
    required this.id,
    required this.exists,
    Map<String, dynamic>? data,
  }) : _data = data;

  @override
  final String id;

  @override
  final bool exists;

  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;
}

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}

class _FakeAuth extends Fake implements FirebaseAuth {
  _FakeAuth(this.currentUser);

  @override
  final User? currentUser;
}

// ignore: subtype_of_sealed_class
class _FakePhotoDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakePhotoDocRef(this.id, this._store, this._getCounts);

  @override
  final String id;
  final Map<String, Map<String, dynamic>> _store;
  final Map<String, int> _getCounts;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _store[id] = Map<String, dynamic>.from(data);
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    _getCounts[id] = (_getCounts[id] ?? 0) + 1;
    final data = _store[id];
    return _FakeDocumentSnapshot(id: id, exists: data != null, data: data);
  }
}

// ignore: subtype_of_sealed_class
class _FakePhotoCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> docs = {};
  final Map<String, int> getCounts = {};
  final Map<String, _FakePhotoDocRef> refs = {};

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    final id = path ?? 'photo_${refs.length + 1}';
    return refs.putIfAbsent(
      id,
      () => _FakePhotoDocRef(id, docs, getCounts),
    );
  }
}

class _FakePhotoFirestore extends Fake implements FirebaseFirestore {
  final _FakePhotoCollection photos = _FakePhotoCollection();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    assert(collectionPath == 'report_photos');
    return photos;
  }
}

class _MemoryPhotoStore implements PhotoStore {
  _MemoryPhotoStore(this.photos);

  final Map<String, Uint8List> photos;
  int loadCount = 0;

  @override
  Future<Uint8List> loadPhoto(String ref) async {
    loadCount++;
    final id = PhotoStore.photoIdFromRef(ref);
    if (id == null || !photos.containsKey(id)) {
      throw StateError('Foto tidak ditemukan: $ref');
    }
    return photos[id]!;
  }

  @override
  Future<String> uploadPhoto(File file) async => 'photo:dummy';
}

// PNG 1x1 transparan valid untuk menguji widget Image.memory.
final _tinyPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('CampusLocation fromDoc & toMap', () {
    test('memetakan dokumen valid dan round-trip toMap', () {
      final doc = _FakeDocumentSnapshot(
        id: 'loc_r101',
        exists: true,
        data: {
          'kode_ruangan': 'QR-GDA-101',
          'nama_gedung': 'Gedung A Fasilkom-TI',
          'nama_ruangan': 'Ruang Kuliah A-101',
          'lantai': 1,
        },
      );

      final loc = CampusLocation.fromDoc(doc);
      expect(loc.id, 'loc_r101');
      expect(loc.kodeRuangan, 'QR-GDA-101');
      expect(loc.namaGedung, 'Gedung A Fasilkom-TI');
      expect(loc.namaRuangan, 'Ruang Kuliah A-101');
      expect(loc.lantai, 1);

      expect(loc.toMap(), {
        'id': 'loc_r101',
        'kode_ruangan': 'QR-GDA-101',
        'nama_gedung': 'Gedung A Fasilkom-TI',
        'nama_ruangan': 'Ruang Kuliah A-101',
        'lantai': 1,
      });
    });

    test('melempar StateError jika dokumen tidak ada atau data null', () {
      expect(
        () => CampusLocation.fromDoc(
          _FakeDocumentSnapshot(id: 'x', exists: false, data: null),
        ),
        throwsStateError,
      );
      expect(
        () => CampusLocation.fromDoc(
          _FakeDocumentSnapshot(id: 'x', exists: true, data: null),
        ),
        throwsStateError,
      );
    });
  });

  group('FacilityCategory fromDoc & toMap', () {
    test('memetakan dokumen valid dan round-trip toMap', () {
      final doc = _FakeDocumentSnapshot(
        id: 'cat_ac',
        exists: true,
        data: {
          'nama_objek': 'AC & Pendingin Ruangan',
          'prioritas_default': 'tinggi',
          'target_sla_jam': 6,
        },
      );

      final cat = FacilityCategory.fromDoc(doc);
      expect(cat.id, 'cat_ac');
      expect(cat.namaObjek, 'AC & Pendingin Ruangan');
      expect(cat.prioritasDefault, 'tinggi');
      expect(cat.targetSlaJam, 6);

      expect(cat.toMap(), {
        'id': 'cat_ac',
        'nama_objek': 'AC & Pendingin Ruangan',
        'prioritas_default': 'tinggi',
        'target_sla_jam': 6,
      });
    });

    test('melempar StateError jika dokumen tidak ada', () {
      expect(
        () => FacilityCategory.fromDoc(
          _FakeDocumentSnapshot(id: 'x', exists: false),
        ),
        throwsStateError,
      );
    });
  });

  group('Report fromDoc & toMap', () {
    test('priorityRankFor memetakan prioritas ke urutan numerik', () {
      expect(Report.priorityRankFor('darurat'), 1);
      expect(Report.priorityRankFor('TINGGI'), 2);
      expect(Report.priorityRankFor('sedang'), 3);
      expect(Report.priorityRankFor('rendah'), 4);
      expect(Report.priorityRankFor('lainnya'), 3);
    });

    test('memetakan dokumen lengkap dengan Timestamp dan toMap', () {
      final created = DateTime.utc(2026, 11, 17, 10, 0);
      final deadline = DateTime.utc(2026, 11, 17, 16, 0);
      final updated = DateTime.utc(2026, 11, 17, 11, 30);

      final doc = _FakeDocumentSnapshot(
        id: 'rep_123456',
        exists: true,
        data: {
          'ticket_number': 'TKT-20261117-rep_12',
          'reporter_uid': 'u1',
          'reporter_name': 'Budi',
          'reporter_sub_role': 'mahasiswa',
          'location_id': 'loc_r101',
          'kode_ruangan': 'QR-GDA-101',
          'nama_gedung': 'Gedung A',
          'nama_ruangan': 'A-101',
          'category_id': 'cat_ac',
          'nama_objek': 'AC',
          'prioritas': 'tinggi',
          'prioritas_rank': 2,
          'target_sla_jam': 6,
          'deskripsi': 'AC bocor',
          'foto_sebelum_url': 'photo:p1',
          'foto_sesudah_url': 'photo:p2',
          'status': 'in_progress',
          'assigned_teknisi_uid': 't1',
          'assigned_teknisi_nama': 'Pak Tek',
          'upvotes_count': 2,
          'supporter_uids': ['u1', 'u2'],
          'confirmed_by_reporter': true,
          'created_at': Timestamp.fromDate(created),
          'sla_deadline': Timestamp.fromDate(deadline),
          'updated_at': Timestamp.fromDate(updated),
        },
      );

      final report = Report.fromDoc(doc);
      expect(report.id, 'rep_123456');
      expect(report.status, ReportStatus.inProgress);
      expect(report.prioritasRank, 2);
      expect(report.supporterUids, ['u1', 'u2']);
      expect(report.confirmedByReporter, isTrue);
      expect(report.createdAt, created.toLocal());
      expect(report.slaDeadline, deadline.toLocal());
      expect(report.updatedAt, updated.toLocal());

      final map = report.toMap();
      expect(map['status'], 'in_progress');
      expect(map['prioritas_rank'], 2);
      expect(map['supporter_uids'], ['u1', 'u2']);
      expect(map['created_at'], isA<Timestamp>());
      expect((map['created_at'] as Timestamp).toDate(), created.toLocal());
      expect(Report.fromMap('rep_123456', map).toMap(), map);
    });

    test('menangani field opsional null dan fallback supporter_uids', () {
      final doc = _FakeDocumentSnapshot(
        id: 'rep_null',
        exists: true,
        data: {
          'ticket_number': 'TKT-20261117-rep_nu',
          'reporter_uid': 'u_asli',
          'reporter_name': null,
          'prioritas': 'darurat',
          'status': null,
          'foto_sesudah_url': null,
          'supporter_uids': null,
          'confirmed_by_reporter': null,
          'created_at': null,
          'sla_deadline': null,
          'updated_at': null,
        },
      );

      final report = Report.fromDoc(doc);
      expect(report.reporterName, '');
      expect(report.status, ReportStatus.reported);
      expect(report.prioritasRank, 1);
      expect(report.supporterUids, ['u_asli']);
      expect(report.fotoSesudahUrl, isNull);
      expect(report.confirmedByReporter, isFalse);
      expect(report.createdAt, isNull);

      final map = report.toMap();
      expect(map['created_at'], isNull);
      expect(map['foto_sesudah_url'], isNull);
    });

    test('melempar StateError jika dokumen tidak ada atau data null', () {
      expect(
        () => Report.fromDoc(_FakeDocumentSnapshot(id: 'r', exists: false)),
        throwsStateError,
      );
      expect(
        () => Report.fromDoc(
          _FakeDocumentSnapshot(id: 'r', exists: true, data: null),
        ),
        throwsStateError,
      );
    });
  });

  group('ReportLog fromDoc & toMap', () {
    test('memetakan log dengan status_lama null maupun terisi', () {
      final ts = DateTime.utc(2026, 11, 17, 12, 0);
      final initialDoc = _FakeDocumentSnapshot(
        id: 'log_1',
        exists: true,
        data: {
          'actor_uid': 'u1',
          'actor_nama': 'Budi',
          'actor_role': 'pelapor',
          'status_lama': null,
          'status_baru': 'reported',
          'catatan': 'Laporan awal',
          'created_at': Timestamp.fromDate(ts),
        },
      );

      final log = ReportLog.fromDoc(initialDoc);
      expect(log.id, 'log_1');
      expect(log.actorRole, UserRole.pelapor);
      expect(log.statusLama, isNull);
      expect(log.statusBaru, ReportStatus.reported);
      expect(log.createdAt, ts.toLocal());

      final map = log.toMap();
      expect(map['status_lama'], isNull);
      expect(map['status_baru'], 'reported');
      expect(map['actor_role'], 'pelapor');
      expect((map['created_at'] as Timestamp).toDate(), ts.toLocal());

      final updateLog = ReportLog.fromDoc(
        _FakeDocumentSnapshot(
          id: 'log_2',
          exists: true,
          data: {
            'actor_uid': 'u1',
            'actor_nama': 'Budi',
            'actor_role': 'pelapor',
            'status_lama': 'resolved',
            'status_baru': 'in_progress',
            'catatan': 'Masih panas',
            'created_at': null,
          },
        ),
      );
      expect(updateLog.statusLama, ReportStatus.resolved);
      expect(updateLog.statusBaru, ReportStatus.inProgress);
      expect(updateLog.createdAt, isNull);
      expect(updateLog.toMap()['status_lama'], 'resolved');
    });

    test('melempar StateError jika dokumen log tidak ada', () {
      expect(
        () => ReportLog.fromDoc(_FakeDocumentSnapshot(id: 'l', exists: false)),
        throwsStateError,
      );
    });
  });

  group('Supporter fromDoc & toMap', () {
    test('memetakan dokumen valid, fallback doc.id, dan null created_at', () {
      final ts = DateTime.utc(2026, 11, 17, 8, 15);
      final doc = _FakeDocumentSnapshot(
        id: 'u2',
        exists: true,
        data: {
          'user_uid': 'u2',
          'nama': 'Siti',
          'created_at': Timestamp.fromDate(ts),
        },
      );

      final sup = Supporter.fromDoc(doc);
      expect(sup.userUid, 'u2');
      expect(sup.nama, 'Siti');
      expect(sup.createdAt, ts.toLocal());

      final map = sup.toMap();
      expect(map['user_uid'], 'u2');
      expect(map['nama'], 'Siti');
      expect((map['created_at'] as Timestamp).toDate(), ts.toLocal());

      final fallback = Supporter.fromDoc(
        _FakeDocumentSnapshot(
          id: 'u3',
          exists: true,
          data: {'nama': null, 'created_at': null},
        ),
      );
      expect(fallback.userUid, 'u3');
      expect(fallback.nama, '');
      expect(fallback.createdAt, isNull);
      expect(fallback.toMap()['created_at'], isNull);
    });

    test('melempar StateError jika dokumen supporter tidak ada', () {
      expect(
        () => Supporter.fromDoc(_FakeDocumentSnapshot(id: 's', exists: false)),
        throwsStateError,
      );
    });
  });

  group('PhotoStore & ReportPhoto', () {
    test('isPhotoRef dan photoIdFromRef memvalidasi prefix photo:', () {
      expect(PhotoStore.isPhotoRef('photo:abc123'), isTrue);
      expect(PhotoStore.photoIdFromRef('photo:abc123'), 'abc123');
      expect(PhotoStore.isPhotoRef('photo:'), isFalse);
      expect(PhotoStore.isPhotoRef('photo:   '), isFalse);
      expect(PhotoStore.isPhotoRef('https://example.com/a.jpg'), isFalse);
      expect(PhotoStore.isPhotoRef(null), isFalse);
    });

    test('FirestorePhotoStore.loadPhoto menolak referensi tidak valid', () {
      final store = FirestorePhotoStore();
      expect(store.loadPhoto('https://invalid'), throwsArgumentError);
      expect(store.loadPhoto('photo:'), throwsArgumentError);
    });

    test('uploadPhoto menurunkan kualitas sampai < 200 KB dan mengisi cache', () async {
      final db = _FakePhotoFirestore();
      final auth = _FakeAuth(_FakeUser('u_pelapor'));
      final qualitiesTried = <int>[];

      final store = FirestorePhotoStore(
        firestore: db,
        auth: auth,
        compressor: (file, {required minWidth, required minHeight, required quality}) async {
          qualitiesTried.add(quality);
          expect(minWidth, 1024);
          expect(minHeight, 1024);
          if (quality >= 60) {
            return Uint8List(210 * 1024); // > 200 KB pada kualitas awal
          }
          return _tinyPngBytes; // < 200 KB pada kualitas berikutnya
        },
      );

      final ref = await store.uploadPhoto(File('dummy.jpg'));
      expect(ref, 'photo:photo_1');
      expect(qualitiesTried, [60, 45]);

      final stored = db.photos.docs['photo_1']!;
      expect(stored['owner_uid'], 'u_pelapor');
      expect(stored['mime_type'], 'image/jpeg');
      expect(stored['data_base64'], base64Encode(_tinyPngBytes));

      // loadPhoto mengambil dari cache memori tanpa memanggil Firestore get().
      final loaded = await store.loadPhoto(ref);
      expect(loaded, _tinyPngBytes);
      expect(db.photos.getCounts['photo_1'] ?? 0, 0);

      // Setelah clearCache(), loadPhoto membaca dari Firestore sekali lalu cache lagi.
      store.clearCache();
      final reloaded = await store.loadPhoto(ref);
      expect(reloaded, _tinyPngBytes);
      expect(db.photos.getCounts['photo_1'], 1);
      await store.loadPhoto(ref);
      expect(db.photos.getCounts['photo_1'], 1);
    });

    test('uploadPhoto menolak jika hasil kompresi tetap >= 200 KB', () async {
      final db = _FakePhotoFirestore();
      final auth = _FakeAuth(_FakeUser('u_pelapor'));
      final store = FirestorePhotoStore(
        firestore: db,
        auth: auth,
        compressor: (file, {required minWidth, required minHeight, required quality}) async =>
            Uint8List(PhotoStore.maxBytes),
      );

      await expectLater(
        store.uploadPhoto(File('besar.jpg')),
        throwsStateError,
      );
      expect(db.photos.docs, isEmpty);
    });

    testWidgets('ReportPhoto memuat gambar dari PhotoStore', (tester) async {
      final store = _MemoryPhotoStore({'img1': _tinyPngBytes});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportPhoto(ref: 'photo:img1', photoStore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.loadCount, 1);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('ReportPhoto menampilkan errorWidget saat ref tidak ditemukan', (
      tester,
    ) async {
      final store = _MemoryPhotoStore({});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportPhoto(
              ref: 'photo:missing',
              photoStore: store,
              errorWidget: const Text('Foto gagal dimuat'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Foto gagal dimuat'), findsOneWidget);
    });
  });
}
