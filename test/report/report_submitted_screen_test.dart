import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/pelapor_home.dart';
import 'package:sifasilitas/screens/report/category_section.dart';
import 'package:sifasilitas/screens/report/report_submitted_screen.dart';
import 'package:sifasilitas/widgets/pelapor_bottom_nav_bar.dart';

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
  namaRuangan: 'Ruang Kuliah A-201',
  lantai: 2,
);

const _proyektor = FacilityCategory(
  id: 'cat_proyektor',
  namaObjek: 'Proyektor & Layar Presentasi',
  prioritasDefault: 'tinggi',
  targetSlaJam: 4,
);

const _tiketBaru = {
  'merged': false,
  'report_id': 'rep1',
  'ticket_number': 'SF-20261128-AB12',
  'message': '-',
};
const _digabung = {
  'merged': true,
  'already_supported': false,
  'report_id': 'rep0',
  'ticket_number': 'SF-20261127-ZZ99',
  'message': '-',
};
const _sudahMendukung = {
  'merged': true,
  'already_supported': true,
  'report_id': 'rep0',
  'ticket_number': 'SF-20261127-ZZ99',
  'message': '-',
};

void main() {
  /// Layar hasil dibuka di atas halaman awal ("beranda" palsu), seperti di
  /// app: form sudah diganti (pushReplacement) oleh layar hasil.
  Future<void> pumpHasil(
    WidgetTester tester,
    Map<String, dynamic> result, {
    String prioritas = 'darurat',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportSubmittedScreen(
                    result: result,
                    user: _user,
                    location: _gda201,
                    category: _proyektor,
                    prioritas: prioritas,
                  ),
                ),
              ),
              child: const Text('beranda palsu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('beranda palsu'));
    await tester.pumpAndSettle();
  }

  testWidgets('tiket baru: judul, nomor, lokasi, fasilitas, prioritas, SLA', (
    tester,
  ) async {
    await pumpHasil(tester, _tiketBaru);

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(find.text('Nomor tiket'), findsOneWidget);
    expect(find.text('SF-20261128-AB12'), findsOneWidget);
    expect(find.text('Ruang Kuliah A-201 · Gedung A'), findsOneWidget);
    expect(find.text('Proyektor & Layar Presentasi'), findsOneWidget);
    // Prioritas yang dioper form (bukan default kategori).
    expect(
      tester.widget<PriorityChip>(find.byType(PriorityChip)).prioritas,
      'darurat',
    );
    expect(find.text('4 jam'), findsOneWidget);
  });

  testWidgets('digabung: penjelasan +1, nomor tiket lama, tanpa prioritas', (
    tester,
  ) async {
    await pumpHasil(tester, _digabung);

    expect(find.text('Dukungan Anda tercatat'), findsOneWidget);
    expect(find.textContaining('+1 dukungan'), findsOneWidget);
    expect(find.text('Nomor tiket (yang sudah ada)'), findsOneWidget);
    expect(find.text('SF-20261127-ZZ99'), findsOneWidget);
    expect(find.byType(PriorityChip), findsNothing);
    expect(find.text('Target penanganan'), findsNothing);
  });

  testWidgets('sudah mendukung: tidak ada perubahan', (tester) async {
    await pumpHasil(tester, _sudahMendukung);

    expect(find.text('Anda sudah mendukung laporan ini'), findsOneWidget);
    expect(find.textContaining('tidak ada perubahan'), findsOneWidget);
    expect(find.byType(PriorityChip), findsNothing);
  });

  testWidgets('map kosong tidak crash: dianggap tiket baru, nomor "-"', (
    tester,
  ) async {
    await pumpHasil(tester, const {});

    expect(find.text('Laporan terkirim'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('Kembali ke beranda dan back sistem menuju beranda', (
    tester,
  ) async {
    await pumpHasil(tester, _tiketBaru);
    await tester.ensureVisible(find.text('Kembali ke beranda'));
    await tester.tap(find.text('Kembali ke beranda'));
    await tester.pumpAndSettle();
    expect(find.text('beranda palsu'), findsOneWidget);

    await tester.tap(find.text('beranda palsu'));
    await tester.pumpAndSettle();
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(find.byType(ReportSubmittedScreen), findsNothing);
    expect(find.text('beranda palsu'), findsOneWidget);
  });

  testWidgets('Lihat status laporan membuka beranda pelapor tab Riwayat', (
    tester,
  ) async {
    await pumpHasil(tester, _tiketBaru);

    await tester.ensureVisible(find.text('Lihat status laporan'));
    await tester.tap(find.text('Lihat status laporan'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportSubmittedScreen), findsNothing);
    final home = tester.widget<PelaporHome>(find.byType(PelaporHome));
    expect(home.initialTab, PelaporTab.riwayat);

    // Back dari Riwayat kembali ke halaman pertama.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('beranda palsu'), findsOneWidget);
  });

  testWidgets('HP 360 dp tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpHasil(tester, _digabung);

    expect(tester.takeException(), isNull);
  });
}
