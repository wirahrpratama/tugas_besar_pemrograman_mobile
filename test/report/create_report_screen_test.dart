import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/report/create_report_screen.dart';
import 'package:sifasilitas/screens/report/report_submitted_screen.dart';

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

const _kirim = 'Kirim (contoh, sementara)';
const _wajib = 'Deskripsi kerusakan wajib diisi.';
const _valid = 'Proyektor tidak menyala sejak Senin pagi.';

void main() {
  /// Form dibuka dari halaman awal ("pemindai" palsu), supaya pop bisa diuji.
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const CreateReportScreen(user: _user, location: _gda201),
                ),
              ),
              child: const Text('pemindai'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pemindai'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKirim(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_kirim));
    await tester.tap(find.text(_kirim));
    await tester.pumpAndSettle();
  }

  Finder deskripsi() => find.byType(TextFormField);

  testWidgets('kartu lokasi, teks bantu, dan penghitung tampil', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Ruang Kelas 201'), findsOneWidget);
    expect(find.text('Gedung A · QR-GDA-201 · Lantai 2'), findsOneWidget);
    expect(
      find.text('Jelaskan apa yang rusak dan sejak kapan.'),
      findsOneWidget,
    );
    expect(find.text('0/500'), findsOneWidget);
  });

  testWidgets('error belum tampil sebelum submit', (tester) async {
    await pumpForm(tester);

    await tester.enterText(deskripsi(), 'rusak');
    await tester.pumpAndSettle();

    expect(find.textContaining('minimal 15 karakter'), findsNothing);
  });

  testWidgets(
    'submit kosong menampilkan error teks; hilang setelah diperbaiki',
    (tester) async {
      await pumpForm(tester);

      await tapKirim(tester);
      expect(find.text(_wajib), findsOneWidget);
      expect(find.byType(ReportSubmittedScreen), findsNothing);

      // Setelah submit gagal, validasi berjalan tiap kali mengetik.
      await tester.enterText(deskripsi(), 'Lampu mati');
      await tester.pumpAndSettle();
      expect(
        find.text('Deskripsi minimal 15 karakter (sekarang 10).'),
        findsOneWidget,
      );

      await tester.enterText(deskripsi(), _valid);
      await tester.pumpAndSettle();
      expect(find.textContaining('Deskripsi minimal'), findsNothing);
      expect(find.text(_wajib), findsNothing);
    },
  );

  testWidgets('deskripsi valid membuka layar hasil', (tester) async {
    await pumpForm(tester);

    await tester.enterText(deskripsi(), _valid);
    await tapKirim(tester);

    expect(find.byType(ReportSubmittedScreen), findsOneWidget);
    expect(find.byType(CreateReportScreen), findsNothing);
  });

  testWidgets('back saat form kosong langsung keluar', (tester) async {
    await pumpForm(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CreateReportScreen), findsNothing);
  });

  testWidgets(
    'back saat terisi minta konfirmasi; Lanjut mengisi tetap di form',
    (tester) async {
      await pumpForm(tester);
      await tester.enterText(deskripsi(), _valid);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Buang laporan ini?'), findsOneWidget);

      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateReportScreen), findsOneWidget);
      expect(find.text(_valid), findsOneWidget);
    },
  );

  testWidgets('back sistem saat terisi lalu Buang laporan menutup form', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(deskripsi(), _valid);

    // Tombol back Android.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buang laporan'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateReportScreen), findsNothing);
    expect(find.text('pemindai'), findsOneWidget);
  });

  testWidgets('Ubah lokasi kembali ke pemindai, lewat konfirmasi bila terisi', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('pemindai'), findsOneWidget);

    await tester.tap(find.text('pemindai'));
    await tester.pumpAndSettle();
    await tester.enterText(deskripsi(), _valid);
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('Buang laporan ini?'), findsOneWidget);
  });
}
