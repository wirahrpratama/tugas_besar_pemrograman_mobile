import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/report/create_report_screen.dart';
import 'package:sifasilitas/screens/report/scan_qr_screen.dart';
import 'package:sifasilitas/screens/report/select_location_screen.dart';
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

const _gda101 = CampusLocation(
  id: 'loc_gda_101',
  kodeRuangan: 'QR-GDA-101',
  namaGedung: 'Gedung A',
  namaRuangan: 'Ruang Kelas 101',
  lantai: 1,
);

const _lab301 = CampusLocation(
  id: 'loc_lab_301',
  kodeRuangan: 'QR-LAB-301',
  namaGedung: 'Gedung Laboratorium',
  namaRuangan: 'Lab Komputer 301',
  lantai: 3,
);

const _semua = [_lab301, _gda201, _gda101];

void main() {
  group('daftarGedung', () {
    test('unik dan terurut abjad', () {
      expect(daftarGedung(_semua), ['Gedung A', 'Gedung Laboratorium']);
    });

    test('nama gedung kosong dilewati', () {
      const tanpaNama = CampusLocation(
        id: 'x',
        kodeRuangan: 'QR-X',
        namaGedung: '  ',
        namaRuangan: 'Ruang X',
        lantai: 1,
      );
      expect(daftarGedung(const [tanpaNama]), isEmpty);
    });
  });

  group('ruanganDiGedung', () {
    test('hanya ruangan di gedung itu, terurut lantai', () {
      expect(ruanganDiGedung(_semua, 'Gedung A'), [_gda101, _gda201]);
    });

    test('gedung belum dipilih = kosong', () {
      expect(ruanganDiGedung(_semua, null), isEmpty);
    });
  });

  group('SelectLocationScreen', () {
    late FakeReportRepository repo;

    setUp(() => repo = FakeReportRepository(locations: _semua));

    /// Layar dibuka dari tombol di halaman awal, supaya hasil `pop` bisa
    /// ditangkap di [hasil].
    Future<List<CampusLocation?>> pumpScreen(
      WidgetTester tester, {
      bool settle = true,
    }) async {
      final hasil = <CampusLocation?>[];
      await tester.pumpWidget(
        Provider<ReportRepository>.value(
          value: repo,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final lokasi = await Navigator.of(context)
                        .push<CampusLocation>(
                          MaterialPageRoute(
                            builder: (_) =>
                                const SelectLocationScreen(user: _user),
                          ),
                        );
                    hasil.add(lokasi);
                  },
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        // Spinner beranimasi terus, jadi pumpAndSettle tidak pernah selesai.
        // Cukup jalankan animasi transisi route sampai habis.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
      return hasil;
    }

    Future<void> pilih(WidgetTester tester, String field, String item) async {
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, field),
      );
      await tester.pumpAndSettle();
      // Menu dropdown menggambar item di overlay; ambil yang terakhir.
      await tester.tap(find.text(item).last);
      await tester.pumpAndSettle();
    }

    testWidgets('loading selama data belum datang', (tester) async {
      repo.locationsStream = StreamController<List<CampusLocation>>().stream;
      await pumpScreen(tester, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('data kosong menampilkan pesan data master', (tester) async {
      repo = FakeReportRepository();
      await pumpScreen(tester);

      expect(
        find.textContaining('Daftar ruangan belum tersedia'),
        findsOneWidget,
      );
      expect(find.text('Lanjut buat laporan'), findsNothing);
    });

    testWidgets('error lalu Coba lagi memuat ulang', (tester) async {
      repo.locationsStream = Stream.error(
        Exception('[cloud_firestore/unavailable] detail teknis'),
      );
      await pumpScreen(tester);

      expect(
        find.textContaining('Gagal memuat daftar ruangan'),
        findsOneWidget,
      );
      expect(find.textContaining('cloud_firestore'), findsNothing);

      repo.locationsStream = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();

      expect(repo.watchLocationsCalls, 2);
      expect(find.text('Gedung'), findsOneWidget);
    });

    testWidgets('memilih gedung tidak membuat langganan baru', (tester) async {
      await pumpScreen(tester);
      await pilih(tester, 'Gedung', 'Gedung A');

      expect(repo.watchLocationsCalls, 1);
    });

    testWidgets('submit kosong menampilkan error di tiap field', (
      tester,
    ) async {
      final hasil = await pumpScreen(tester);

      expect(find.text('Pilih gedung terlebih dahulu.'), findsNothing);
      await tester.tap(find.text('Lanjut buat laporan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih gedung terlebih dahulu.'), findsOneWidget);
      expect(find.text('Pilih ruangan terlebih dahulu.'), findsOneWidget);
      expect(hasil, isEmpty);

      // Setelah submit gagal, error gedung hilang begitu gedung dipilih.
      await pilih(tester, 'Gedung', 'Gedung A');
      expect(find.text('Pilih gedung terlebih dahulu.'), findsNothing);
    });

    testWidgets(
      'ruangan mengikuti gedung dan dikosongkan saat gedung diganti',
      (tester) async {
        await pumpScreen(tester);
        expect(find.text('Pilih gedung dulu'), findsOneWidget);

        await pilih(tester, 'Gedung', 'Gedung A');
        await tester.tap(
          find.widgetWithText(DropdownButtonFormField<String>, 'Ruangan'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ruang Kelas 101 · Lantai 1'), findsWidgets);
        expect(find.text('Lab Komputer 301 · Lantai 3'), findsNothing);
        await tester.tap(find.text('Ruang Kelas 201 · Lantai 2').last);
        await tester.pumpAndSettle();
        expect(find.text('Ruang Kelas 201 · Lantai 2'), findsOneWidget);

        await pilih(tester, 'Gedung', 'Gedung Laboratorium');
        expect(find.text('Ruang Kelas 201 · Lantai 2'), findsNothing);
        expect(find.text('Pilih ruangan di gedung ini'), findsOneWidget);
      },
    );

    testWidgets('Lanjut mengembalikan ruangan terpilih', (tester) async {
      final hasil = await pumpScreen(tester);

      await pilih(tester, 'Gedung', 'Gedung Laboratorium');
      await pilih(tester, 'Ruangan', 'Lab Komputer 301 · Lantai 3');
      await tester.tap(find.text('Lanjut buat laporan'));
      await tester.pumpAndSettle();

      expect(hasil, [_lab301]);
      expect(find.byType(SelectLocationScreen), findsNothing);
    });

    testWidgets('ruangan terpilih yang terhapus dari master dikosongkan', (
      tester,
    ) async {
      final data = StreamController<List<CampusLocation>>();
      repo.locationsStream = data.stream;
      data.add(_semua);
      await pumpScreen(tester);
      await pilih(tester, 'Gedung', 'Gedung A');
      await pilih(tester, 'Ruangan', 'Ruang Kelas 201 · Lantai 2');

      data.add(const [_gda101, _lab301]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ruang Kelas 201 · Lantai 2'), findsNothing);
      expect(find.text('Pilih ruangan di gedung ini'), findsOneWidget);
      await data.close();
    });
  });

  group('jalur manual dari pemindai', () {
    late FakeScannerPlatform scanner;

    setUp(() {
      scanner = FakeScannerPlatform();
      MobileScannerPlatform.instance = scanner;
    });

    Future<void> pumpScanner(WidgetTester tester) async {
      await tester.pumpWidget(
        Provider<ReportRepository>.value(
          value: FakeReportRepository(locations: _semua),
          child: const MaterialApp(home: ScanQrScreen(user: _user)),
        ),
      );
      await tester.pumpAndSettle();
    }

    const tombolManual = 'QR tidak terbaca? Pilih ruangan manual';

    testWidgets('pilih manual sampai form; kembali ke pemindai', (
      tester,
    ) async {
      await pumpScanner(tester);

      await tester.tap(find.text(tombolManual));
      await tester.pumpAndSettle();
      expect(find.byType(SelectLocationScreen), findsOneWidget);
      expect(scanner.stopCalls, 1);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Gedung'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gedung A').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Ruangan'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ruang Kelas 201 · Lantai 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut buat laporan'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateReportScreen), findsOneWidget);
      expect(find.textContaining('QR-GDA-201'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ScanQrScreen), findsOneWidget);
      expect(find.byType(SelectLocationScreen), findsNothing);
      expect(scanner.startCalls, 2);
    });

    testWidgets('kembali tanpa memilih menyalakan kamera lagi', (tester) async {
      await pumpScanner(tester);

      await tester.tap(find.text(tombolManual));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ScanQrScreen), findsOneWidget);
      expect(scanner.startCalls, 2);
    });

    testWidgets('izin kamera ditolak: jalur manual tetap tersedia', (
      tester,
    ) async {
      scanner.startError = const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
      await pumpScanner(tester);

      expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
      await tester.tap(find.text(tombolManual));
      await tester.pumpAndSettle();
      expect(find.byType(SelectLocationScreen), findsOneWidget);
    });
  });
}
