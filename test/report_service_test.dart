import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/report_service.dart';

// ignore: subtype_of_sealed_class
class _FakeSnap<T extends Object?> extends Fake implements DocumentSnapshot<T> {
  _FakeSnap(this.id, T? data)
      : exists = data != null,
        _data = data;

  @override
  final String id;

  @override
  final bool exists;

  final T? _data;

  @override
  T? data() => _data;
}

// ignore: subtype_of_sealed_class
class _FakeDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _FakeDocRef(this.path, this.id, this._store);

  @override
  final String path;

  @override
  final String id;

  final _InMemoryStore _store;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeColRef('$path/$collectionPath', _store);
}

// ignore: subtype_of_sealed_class
class _FakeColRef extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeColRef(this.path, this._store);

  @override
  final String path;

  final _InMemoryStore _store;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? docId]) {
    final id = docId ?? _store.nextId();
    return _FakeDocRef('$path/$id', id, _store);
  }
}

class _InMemoryStore {
  final Map<String, Map<String, dynamic>> docs = {};
  final List<({String op, String path, Map<String, dynamic> data})> ops = [];
  int _seq = 0;

  String nextId() => 'doc_${++_seq}_abcdef';
}

class _FakeTx extends Fake implements Transaction {
  _FakeTx(this._store);

  final _InMemoryStore _store;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    final data = _store.docs[documentReference.path];
    return _FakeSnap<T>(
      documentReference.id,
      data == null ? null : Map<String, dynamic>.from(data) as T,
    );
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    final map = Map<String, dynamic>.from(data as Map);
    _store.docs[documentReference.path] = map;
    _store.ops.add((op: 'set', path: documentReference.path, data: map));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    final current =
        Map<String, dynamic>.from(_store.docs[documentReference.path] ?? {});
    final casted = data.map((k, v) => MapEntry(k.toString(), v));
    current.addAll(casted);
    _store.docs[documentReference.path] = current;
    _store.ops.add((op: 'update', path: documentReference.path, data: casted));
    return this;
  }

  @override
  Transaction delete(DocumentReference<Object?> documentReference) {
    _store.docs.remove(documentReference.path);
    _store.ops.add((op: 'delete', path: documentReference.path, data: {}));
    return this;
  }
}

class _FakeFirestore extends Fake implements FirebaseFirestore {
  final _InMemoryStore store = _InMemoryStore();

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _FakeColRef(collectionPath, store);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    final tx = _FakeTx(store);
    return transactionHandler(tx);
  }
}

void main() {
  group('ReportService.isValidTransition', () {
    // Satu-satunya transisi yang sah (current -> daftar next).
    const allowed = <ReportStatus, Set<ReportStatus>>{
      ReportStatus.reported: {ReportStatus.verified, ReportStatus.rejected},
      ReportStatus.verified: {ReportStatus.assigned, ReportStatus.rejected},
      ReportStatus.assigned: {ReportStatus.inProgress},
      ReportStatus.inProgress: {ReportStatus.resolved},
      ReportStatus.resolved: {ReportStatus.inProgress},
      ReportStatus.rejected: {},
    };

    for (final current in ReportStatus.values) {
      for (final next in ReportStatus.values) {
        final expected = allowed[current]!.contains(next);
        test('${current.value} -> ${next.value} == $expected', () {
          expect(ReportService.isValidTransition(current, next), expected);
        });
      }
    }
  });

  group('ReportService.canChangeStatus (tabel peran)', () {
    const actor = 'uid-teknisi-1';
    const other = 'uid-teknisi-2';

    bool can(UserRole role, ReportStatus next, {String? assigned = actor}) =>
        ReportService.canChangeStatus(
          role: role,
          actorUid: actor,
          newStatus: next,
          currentAssignedUid: assigned,
        );

    test('admin: hanya verified, rejected, assigned', () {
      expect(can(UserRole.admin, ReportStatus.verified), isTrue);
      expect(can(UserRole.admin, ReportStatus.rejected), isTrue);
      expect(can(UserRole.admin, ReportStatus.assigned), isTrue);
      expect(can(UserRole.admin, ReportStatus.inProgress), isFalse);
      expect(can(UserRole.admin, ReportStatus.resolved), isFalse);
      expect(can(UserRole.admin, ReportStatus.reported), isFalse);
    });

    test('teknisi: tidak boleh verified, rejected, assigned', () {
      expect(can(UserRole.teknisi, ReportStatus.verified), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.rejected), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.assigned), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.reported), isFalse);
    });

    test('teknisi yang ditugaskan boleh in_progress dan resolved', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress), isTrue);
      expect(can(UserRole.teknisi, ReportStatus.resolved), isTrue);
    });

    test('teknisi lain (bukan yang ditugaskan) ditolak', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress, assigned: other), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.resolved, assigned: other), isFalse);
    });

    test('tiket belum punya teknisi: in_progress/resolved ditolak', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress, assigned: null), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.resolved, assigned: ''), isFalse);
    });

    test('admin tidak boleh in_progress/resolved walau UID-nya sama', () {
      expect(can(UserRole.admin, ReportStatus.inProgress), isFalse);
      expect(can(UserRole.admin, ReportStatus.resolved), isFalse);
    });

    test('pelapor ditolak untuk semua status', () {
      for (final s in ReportStatus.values) {
        expect(can(UserRole.pelapor, s), isFalse, reason: s.value);
      }
    });
  });

  group('ReportService.ticketNumberFor', () {
    test('format TKT-YYYYMMDD-XXXXXX dari 6 karakter pertama ID dokumen', () {
      expect(
        ReportService.ticketNumberFor(
          DateTime(2026, 11, 17),
          'AbCdEfGhIjKlMnOpQrSt',
        ),
        'TKT-20261117-AbCdEf',
      );
    });

    test('bulan dan hari satu digit diberi nol di depan', () {
      expect(
        ReportService.ticketNumberFor(DateTime(2026, 3, 5), 'abcdef123456'),
        'TKT-20260305-abcdef',
      );
    });

    test('cocok dengan pola yang didokumentasikan', () {
      final number = ReportService.ticketNumberFor(
        DateTime(2026, 12, 31),
        'Zy9Xw8Vu7Ts6Rq5Po4Nm',
      );
      expect(number, matches(RegExp(r'^TKT-\d{8}-[A-Za-z0-9]{6}$')));
    });

    test('ID yang lebih pendek dari 6 karakter tidak melempar error', () {
      expect(
        ReportService.ticketNumberFor(DateTime(2026, 1, 2), 'abc'),
        'TKT-20260102-abc',
      );
    });
  });

  group('ReportService.activeTicketKey', () {
    test('format {locationId}_{categoryId}', () {
      expect(
        ReportService.activeTicketKey('loc_r101', 'cat_ac'),
        'loc_r101_cat_ac',
      );
    });
  });

  group('ReportService transaksi (supporter_uids, confirmResolution, guard)', () {
    const pelapor = AppUser(
      uid: 'u_pelapor',
      nama: 'Aldi',
      identityNumber: '241402001',
      email: 'aldi@students.usu.ac.id',
      subRole: 'mahasiswa',
      role: UserRole.pelapor,
    );
    const pendukung = AppUser(
      uid: 'u_pendukung',
      nama: 'Bima',
      identityNumber: '241402002',
      email: 'bima@students.usu.ac.id',
      subRole: 'mahasiswa',
      role: UserRole.pelapor,
    );
    const lokasi = CampusLocation(
      id: 'loc_r101',
      kodeRuangan: 'QR-GDA-101',
      namaGedung: 'Gedung A',
      namaRuangan: 'R-101',
      lantai: 1,
    );
    const kategori = FacilityCategory(
      id: 'cat_ac',
      namaObjek: 'AC',
      prioritasDefault: 'tinggi',
      targetSlaJam: 6,
    );

    late _FakeFirestore db;
    late ReportService service;

    setUp(() {
      db = _FakeFirestore();
      db.store.docs['users/u_pelapor'] = pelapor.toMap();
      db.store.docs['users/u_pendukung'] = pendukung.toMap();
      db.store.docs['users/u_teknisi'] = const AppUser(
        uid: 'u_teknisi',
        nama: 'Teknisi',
        identityNumber: '199001012020011001',
        email: 'tek@usu.ac.id',
        subRole: 'teknisi',
        role: UserRole.teknisi,
      ).toMap();
      service = ReportService(firestore: db);
    });

    test('submitReport mengisi prioritas_rank & supporter_uids dan merge menambah pendukung', () async {
      final res1 = await service.submitReport(
        reporter: pelapor,
        location: lokasi,
        category: kategori,
        deskripsi: 'AC mati',
        fotoSebelumUrl: 'photo:p1',
        aiSuggestedPriority: 'darurat',
      );
      expect(res1['merged'], isFalse);

      final reportPath =
          db.store.ops.firstWhere((o) => o.path.startsWith('reports/') && !o.path.contains('/logs/') && !o.path.contains('/supporters/')).path;
      final created = db.store.docs[reportPath]!;
      expect(created['prioritas'], 'darurat');
      expect(created['prioritas_rank'], 1);
      expect(created['supporter_uids'], ['u_pelapor']);

      final res2 = await service.submitReport(
        reporter: pendukung,
        location: lokasi,
        category: kategori,
        deskripsi: 'AC juga mati',
        fotoSebelumUrl: 'photo:p2',
      );
      expect(res2['merged'], isTrue);
      expect(res2['already_supported'], isFalse);
      final mergeUpdate = db.store.ops.lastWhere(
        (o) => o.op == 'update' && o.path == reportPath,
      );
      expect(mergeUpdate.data.containsKey('supporter_uids'), isTrue);
      expect(mergeUpdate.data.containsKey('upvotes_count'), isTrue);
    });

    test('submitReport mengembalikan report_id di ketiga cabang (baru, gabung, sudah mendukung)', () async {
      final baru = await service.submitReport(
        reporter: pelapor,
        location: lokasi,
        category: kategori,
        deskripsi: 'AC mati',
        fotoSebelumUrl: 'photo:p1',
      );
      final reportPath = db.store.ops
          .firstWhere((o) =>
              o.path.startsWith('reports/') &&
              !o.path.contains('/logs/') &&
              !o.path.contains('/supporters/'))
          .path;
      final reportId = reportPath.split('/')[1];
      expect(baru['merged'], isFalse);
      expect(baru['report_id'], reportId);

      final gabung = await service.submitReport(
        reporter: pendukung,
        location: lokasi,
        category: kategori,
        deskripsi: 'AC juga mati',
        fotoSebelumUrl: 'photo:p2',
      );
      expect(gabung['merged'], isTrue);
      expect(gabung['already_supported'], isFalse);
      expect(gabung['report_id'], reportId);

      final ulang = await service.submitReport(
        reporter: pendukung,
        location: lokasi,
        category: kategori,
        deskripsi: 'Masih mati',
        fotoSebelumUrl: 'photo:p3',
      );
      expect(ulang['merged'], isTrue);
      expect(ulang['already_supported'], isTrue);
      expect(ulang['report_id'], reportId);
    });

    test('updateReportStatus menolak teknisi mengembalikan resolved -> in_progress', () async {
      db.store.docs['reports/rep1'] = {
        'reporter_uid': 'u_pelapor',
        'assigned_teknisi_uid': 'u_teknisi',
        'location_id': 'loc_r101',
        'category_id': 'cat_ac',
        'status': 'resolved',
        'confirmed_by_reporter': false,
      };

      await expectLater(
        service.updateReportStatus(
          reportId: 'rep1',
          actorUid: 'u_teknisi',
          newStatus: ReportStatus.inProgress,
          catatan: 'Coba buka ulang',
        ),
        throwsA(
          predicate((e) => e.toString().contains('403 Forbidden')),
        ),
      );
    });

    test('confirmResolution terima: set confirmed_by_reporter dan tulis log', () async {
      db.store.docs['reports/rep1'] = {
        'reporter_uid': 'u_pelapor',
        'location_id': 'loc_r101',
        'category_id': 'cat_ac',
        'status': 'resolved',
        'confirmed_by_reporter': false,
      };

      await service.confirmResolution('rep1', 'u_pelapor', diterima: true);

      expect(db.store.docs['reports/rep1']!['confirmed_by_reporter'], isTrue);
      expect(db.store.docs['reports/rep1']!['status'], 'resolved');

      final logOp = db.store.ops.lastWhere(
        (o) => o.path.startsWith('reports/rep1/logs/'),
      );
      expect(logOp.data['actor_uid'], 'u_pelapor');
      expect(logOp.data['status_lama'], 'resolved');
      expect(logOp.data['status_baru'], 'resolved');
      expect((logOp.data['catatan'] as String).isNotEmpty, isTrue);
    });

    test('confirmResolution tolak: wajib catatan, kembalikan status ke in_progress, pulihkan lock, tulis log', () async {
      db.store.docs['reports/rep1'] = {
        'reporter_uid': 'u_pelapor',
        'location_id': 'loc_r101',
        'category_id': 'cat_ac',
        'status': 'resolved',
        'confirmed_by_reporter': false,
      };

      await expectLater(
        service.confirmResolution(
          'rep1',
          'u_pelapor',
          diterima: false,
          catatan: '   ',
        ),
        throwsA(predicate((e) => e.toString().contains('422 Validasi Gagal'))),
      );

      await service.confirmResolution(
        'rep1',
        'u_pelapor',
        diterima: false,
        catatan: 'AC masih meneteskan air',
      );

      expect(db.store.docs['reports/rep1']!['status'], 'in_progress');
      expect(db.store.docs['reports/rep1']!['confirmed_by_reporter'], isFalse);
      expect(
        db.store.docs['active_tickets/loc_r101_cat_ac']?['report_id'],
        'rep1',
      );

      final logOp = db.store.ops.lastWhere(
        (o) => o.path.startsWith('reports/rep1/logs/'),
      );
      expect(logOp.data['status_lama'], 'resolved');
      expect(logOp.data['status_baru'], 'in_progress');
      expect(logOp.data['catatan'], 'AC masih meneteskan air');
    });

    test('confirmResolution menolak aktor bukan pelapor asli dan status bukan resolved', () async {
      db.store.docs['reports/rep1'] = {
        'reporter_uid': 'u_pelapor',
        'location_id': 'loc_r101',
        'category_id': 'cat_ac',
        'status': 'resolved',
        'confirmed_by_reporter': false,
      };

      await expectLater(
        service.confirmResolution('rep1', 'u_pendukung', diterima: true),
        throwsA(predicate((e) => e.toString().contains('403 Forbidden'))),
      );

      db.store.docs['reports/rep1']!['status'] = 'in_progress';
      await expectLater(
        service.confirmResolution('rep1', 'u_pelapor', diterima: true),
        throwsA(predicate((e) => e.toString().contains('422 Transisi Ilegal'))),
      );
    });
  });
}
