import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/profile/profile_screen.dart';
import 'package:sifasilitas/services/auth_service.dart';
import 'package:sifasilitas/services/photo_store.dart';
import 'package:sifasilitas/services/report_repository.dart';

final _tinyPngBytes = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('ProfileScreen menampilkan statistik dan ikon peran teknisi', (
    tester,
  ) async {
    const teknisi = AppUser(
      uid: 'tek-1',
      nama: 'Budi Santoso',
      identityNumber: '198801012015011001',
      email: 'budi@email.com',
      subRole: '',
      role: UserRole.teknisi,
    );

    final reports = [
      _report('TKT-1', ReportStatus.assigned),
      _report('TKT-2', ReportStatus.resolved),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: _FakeAuthService(teknisi)),
          Provider<ReportRepository>.value(value: _FakeReportRepo(reports)),
        ],
        child: const MaterialApp(home: ProfileScreen(uid: 'tek-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsNWidgets(2));
    expect(find.text('BS'), findsNWidgets(2)); // TopBar + Avatar Header
    expect(find.text('Teknisi Lapangan'), findsNWidgets(2));
    expect(find.byIcon(Icons.engineering_rounded), findsOneWidget);
    expect(find.text('Total Tugas'), findsOneWidget);
    expect(find.text('Dikerjakan'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('ProfileScreen menampilkan error state saat stream gagal', (
    tester,
  ) async {
    await tester.pumpWidget(
      Provider<AuthService>.value(
        value: _FakeAuthService.error(),
        child: const MaterialApp(home: ProfileScreen(uid: 'u-err')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat profil'), findsOneWidget);
  });

  testWidgets('ProfileScreen dapat mengajukan perubahan dan cek status email', (
    tester,
  ) async {
    final auth = _FakeAuthService(
      const AppUser(
        uid: 'tek-1',
        nama: 'Budi Santoso',
        identityNumber: '198801012015011001',
        email: 'budi@email.com',
        subRole: '',
        role: UserRole.teknisi,
        pendingEmail: 'budi.baru@usu.ac.id',
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: auth),
          Provider<ReportRepository>.value(value: _FakeReportRepo(const [])),
        ],
        child: const MaterialApp(home: ProfileScreen(uid: 'tek-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Cek Status'), 200);
    await tester.ensureVisible(find.text('Cek Status'));
    await tester.pumpAndSettle();
    expect(
      find.text('Menunggu verifikasi ke budi.baru@usu.ac.id'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cek Status'));
    await tester.pumpAndSettle();
    expect(auth.syncEmailCalls, 1);

    // Tombol Ubah ke-2 adalah pada baris Email (setelah Nama Lengkap).
    final ubahEmailBtn = find.widgetWithText(TextButton, 'Ubah').at(1);
    await tester.ensureVisible(ubahEmailBtn);
    await tester.pumpAndSettle();
    await tester.tap(ubahEmailBtn);
    await tester.pumpAndSettle();
    expect(find.text('Ubah Email'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Baru'),
      'budi.lain@usu.ac.id',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password Saat Ini'),
      'Password1',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(auth.lastRequestedEmail, 'budi.lain@usu.ac.id');
    expect(auth.lastRequestedPassword, 'Password1');
    expect(
      find.textContaining('Tautan verifikasi dikirim ke budi.lain@usu.ac.id'),
      findsOneWidget,
    );
  });

  testWidgets('ProfileScreen dapat mengubah foto profil', (tester) async {
    final auth = _FakeAuthService(
      const AppUser(
        uid: 'tek-1',
        nama: 'Budi Santoso',
        identityNumber: '198801012015011001',
        email: 'budi@email.com',
        subRole: '',
        role: UserRole.teknisi,
      ),
    );
    final photoStore = _FakePhotoStore({'avatar-1': _tinyPngBytes});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: auth),
          Provider<PhotoStore>.value(value: photoStore),
          Provider<ReportRepository>.value(value: _FakeReportRepo(const [])),
        ],
        child: MaterialApp(
          home: ProfileScreen(
            uid: 'tek-1',
            pickImage: (_) async => File('avatar.jpg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Ambil dari kamera'), findsOneWidget);
    expect(find.text('Pilih dari galeri'), findsOneWidget);
    expect(find.text('Hapus foto profil'), findsNothing);

    await tester.tap(find.text('Pilih dari galeri'));
    await tester.pumpAndSettle();

    expect(photoStore.uploadCalls, 1);
    expect(auth.updatedPhotoUrls, ['photo:avatar-1']);
    expect(find.text('Foto profil berhasil diperbarui.'), findsOneWidget);
  });

  testWidgets('ProfileScreen dapat menghapus foto profil yang sudah ada', (
    tester,
  ) async {
    final authWithPhoto = _FakeAuthService(
      const AppUser(
        uid: 'tek-1',
        nama: 'Budi Santoso',
        identityNumber: '198801012015011001',
        email: 'budi@email.com',
        subRole: '',
        role: UserRole.teknisi,
        photoUrl: 'photo:avatar-1',
      ),
    );
    final photoStore = _FakePhotoStore({'avatar-1': _tinyPngBytes});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: authWithPhoto),
          Provider<PhotoStore>.value(value: photoStore),
          Provider<ReportRepository>.value(value: _FakeReportRepo(const [])),
        ],
        child: const MaterialApp(home: ProfileScreen(uid: 'tek-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);

    await tester.tap(find.byIcon(Icons.camera_alt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hapus foto profil'), findsOneWidget);

    await tester.tap(find.text('Hapus foto profil'));
    await tester.pumpAndSettle();
    expect(authWithPhoto.updatedPhotoUrls, [null]);
    expect(find.text('Foto profil berhasil dihapus.'), findsOneWidget);
  });
}

Report _report(String ticket, ReportStatus status) => Report(
  id: ticket,
  ticketNumber: ticket,
  reporterUid: 'rep-1',
  reporterName: 'Pelapor',
  reporterSubRole: 'mahasiswa',
  locationId: 'loc-1',
  kodeRuangan: 'QR-101',
  namaGedung: 'Gedung A',
  namaRuangan: 'Ruang 101',
  categoryId: 'cat-ac',
  namaObjek: 'AC',
  prioritas: 'tinggi',
  prioritasRank: 2,
  targetSlaJam: 6,
  deskripsi: 'AC rusak.',
  fotoSebelumUrl: '',
  status: status,
  upvotesCount: 1,
  supporterUids: const ['rep-1'],
  confirmedByReporter: false,
);

class _FakeAuthService implements AuthService {
  _FakeAuthService(this._user) : _error = false;
  _FakeAuthService.error() : _user = null, _error = true;

  final AppUser? _user;
  final bool _error;
  String? lastRequestedEmail;
  String? lastRequestedPassword;
  int syncEmailCalls = 0;
  final List<String?> updatedPhotoUrls = <String?>[];

  @override
  Stream<AppUser?> watchAppUser(String uid) =>
      _error ? Stream.error(Exception('fail')) : Stream.value(_user);

  @override
  Future<void> requestEmailChange({
    required String uid,
    required String newEmail,
    required String currentPassword,
  }) async {
    lastRequestedEmail = newEmail;
    lastRequestedPassword = currentPassword;
  }

  @override
  Future<bool> syncEmailChange(String uid) async {
    syncEmailCalls++;
    return false;
  }

  @override
  Future<void> updatePhotoUrl(String uid, String? photoUrl) async {
    updatedPhotoUrls.add(photoUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePhotoStore implements PhotoStore {
  _FakePhotoStore(this.photos);

  final Map<String, Uint8List> photos;
  int uploadCalls = 0;

  @override
  Future<Uint8List> loadPhoto(String ref) async {
    final id = PhotoStore.photoIdFromRef(ref);
    if (id == null || !photos.containsKey(id)) {
      throw StateError('Missing $ref');
    }
    return photos[id]!;
  }

  @override
  Future<String> uploadPhoto(File file) async {
    uploadCalls++;
    return 'photo:avatar-1';
  }
}

class _FakeReportRepo implements ReportRepository {
  _FakeReportRepo(this.reports);

  final List<Report> reports;

  @override
  Stream<List<Report>> watchReportsForTeknisi(String uid) =>
      Stream.value(reports);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
