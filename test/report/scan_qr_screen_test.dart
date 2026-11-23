import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/report/create_report_screen.dart';
import 'package:sifasilitas/screens/report/scan_qr_screen.dart';
import 'package:sifasilitas/services/report_repository.dart';

import 'fake_report_repository.dart';
import 'fake_scanner_platform.dart';

const _user = AppUser(
  uid: 'u1',
  nama: 'Pelapor Uji',
  identityNumber: '241402000',
  email: 'uji@example.com',
  subRole: 'mahasiswa',
  role: UserRole.pelapor,
);

const _gda201 = CampusLocation(
  id: 'loc_gda_201',
  kodeRuangan: 'QR-GDA-201',
  namaGedung: 'Gedung A',
  namaRuangan: 'Ruang Kelas 201',
  lantai: 2,
);

const _lab301 = CampusLocation(
  id: 'loc_lab_301',
  kodeRuangan: 'QR-LAB-301',
  namaGedung: 'Gedung Laboratorium',
  namaRuangan: 'Lab Komputer 301',
  lantai: 3,
);

const _pesanTidakDikenal = 'QR tidak dikenali sebagai ruangan kampus.';

void main() {
  late FakeScannerPlatform scanner;
  late FakeReportRepository repo;

  setUp(() {
    scanner = FakeScannerPlatform();
    MobileScannerPlatform.instance = scanner;
    repo = FakeReportRepository(locations: const [_gda201, _lab301]);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<ReportRepository>.value(
        value: repo,
        child: const MaterialApp(home: ScanQrScreen(user: _user)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('QR terdaftar menampilkan panel ruangan', (tester) async {
    await pumpScreen(tester);

    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();

    expect(find.text('Ruang Kelas 201'), findsOneWidget);
    expect(find.text('QR-GDA-201 · Gedung A · Lantai 2'), findsOneWidget);
    expect(find.text('Lanjut buat laporan'), findsOneWidget);
    expect(find.text('Pindai lagi'), findsOneWidget);
  });

  testWidgets('indikator tampil selama QR diperiksa', (tester) async {
    final query = Completer<CampusLocation?>();
    repo.pending = query;
    await pumpScreen(tester);

    scanner.emitQr('QR-GDA-201');
    // Bukan pumpAndSettle: spinner beranimasi terus sehingga tidak pernah
    // "settle". Pump pertama mengantar event kamera ke onDetect (setState),
    // pump kedua menggambar frame berisi indikator.
    await tester.pump();
    await tester.pump();
    expect(find.text('Memeriksa QR…'), findsOneWidget);

    query.complete(_gda201);
    await tester.pumpAndSettle();
    expect(find.text('Memeriksa QR…'), findsNothing);
    expect(find.text('Ruang Kelas 201'), findsOneWidget);
  });

  testWidgets('QR beruntun hanya diperiksa sekali; Pindai lagi membuka kunci', (
    tester,
  ) async {
    await pumpScreen(tester);

    scanner.emitQr('QR-GDA-201');
    scanner.emitQr('QR-GDA-201');
    scanner.emitQr('QR-LAB-301');
    await tester.pumpAndSettle();

    expect(repo.qrQueries, ['QR-GDA-201']);
    expect(find.text('Ruang Kelas 201'), findsOneWidget);
    expect(find.text('Lab Komputer 301'), findsNothing);

    await tester.tap(find.text('Pindai lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Ruang Kelas 201'), findsNothing);

    scanner.emitQr('QR-LAB-301');
    await tester.pumpAndSettle();
    expect(find.text('Lab Komputer 301'), findsOneWidget);
  });

  testWidgets('QR kosong diabaikan tanpa query', (tester) async {
    await pumpScreen(tester);

    scanner.emitQr('   ');
    await tester.pumpAndSettle();

    expect(repo.qrQueries, isEmpty);
  });

  testWidgets('QR asing ditolak, lalu diabaikan selama 3 detik', (
    tester,
  ) async {
    await pumpScreen(tester);

    scanner.emitQr('https://contoh.com/bukan-ruangan');
    await tester.pumpAndSettle();
    expect(find.text(_pesanTidakDikenal), findsOneWidget);
    expect(find.text('Lanjut buat laporan'), findsNothing);

    // QR yang sama masih di depan kamera: tidak di-query ulang.
    scanner.emitQr('https://contoh.com/bukan-ruangan');
    await tester.pump(const Duration(seconds: 2));
    expect(repo.qrQueries, hasLength(1));

    // QR lain yang valid tetap langsung diterima selama jeda.
    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();
    expect(find.text('Ruang Kelas 201'), findsOneWidget);
    await tester.tap(find.text('Pindai lagi'));
    await tester.pumpAndSettle();

    // Setelah jeda habis, QR asing tadi diperiksa lagi.
    await tester.pump(const Duration(seconds: 3));
    scanner.emitQr('https://contoh.com/bukan-ruangan');
    await tester.pumpAndSettle();
    expect(repo.qrQueries, [
      'https://contoh.com/bukan-ruangan',
      'QR-GDA-201',
      'https://contoh.com/bukan-ruangan',
    ]);
  });

  testWidgets('gagal memeriksa QR menampilkan pesan ramah', (tester) async {
    repo.error = Exception('[cloud_firestore/unavailable] stack trace dsb.');
    await pumpScreen(tester);

    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal memeriksa QR. Periksa koneksi internet lalu coba lagi.'),
      findsOneWidget,
    );
    expect(find.textContaining('cloud_firestore'), findsNothing);
    expect(find.text('Lanjut buat laporan'), findsNothing);

    // Setelah koneksi pulih dan jeda habis, QR yang sama berhasil.
    repo.error = null;
    await tester.pump(const Duration(seconds: 3));
    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();
    expect(find.text('Ruang Kelas 201'), findsOneWidget);
  });

  testWidgets('Lanjut membuka form; kamera dimatikan lalu dinyalakan lagi', (
    tester,
  ) async {
    await pumpScreen(tester);
    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut buat laporan'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateReportScreen), findsOneWidget);
    expect(scanner.stopCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(scanner.startCalls, 2);
    // Kembali ke pemindai berarti memilih ruangan lagi: panel lama ditutup.
    expect(find.text('Lanjut buat laporan'), findsNothing);
  });

  testWidgets('izin kamera ditolak menampilkan pesan dan Coba lagi', (
    tester,
  ) async {
    scanner.startError = const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
    await pumpScreen(tester);

    expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    // Pengguna mengizinkan di Pengaturan lalu menekan Coba lagi.
    scanner.startError = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(scanner.startCalls, 2);
    expect(find.textContaining('Izin kamera ditolak'), findsNothing);
  });

  testWidgets('tombol senter nonaktif bila perangkat tanpa senter', (
    tester,
  ) async {
    await pumpScreen(tester);

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.flash_off),
    );
    expect(button.onPressed, isNull);
  });
}
