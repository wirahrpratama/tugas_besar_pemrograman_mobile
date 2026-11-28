import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/pelapor_home.dart';
import 'package:sifasilitas/screens/report/report_submitted_screen.dart';
import 'package:sifasilitas/services/ai_classifier_service.dart';
import 'package:sifasilitas/services/report_repository.dart';

import 'fake_ai_classifier.dart';
import 'fake_image_picker.dart';
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

void main() {
  late FakeScannerPlatform scanner;

  // ScanQrScreen memakai kamera; di test diganti platform palsu.
  setUp(() {
    scanner = FakeScannerPlatform();
    MobileScannerPlatform.instance = scanner;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ReportRepository>.value(
            value: FakeReportRepository(locations: const [_gda201])
              ..categories = const [
                FacilityCategory(
                  id: 'cat_proyektor',
                  namaObjek: 'Proyektor',
                  prioritasDefault: 'tinggi',
                  targetSlaJam: 4,
                ),
              ],
          ),
          Provider<AiClassifierService>.value(value: FakeAiClassifier()),
          Provider<ImagePicker>.value(
            value: FakeImagePicker()..hasil = XFile('/tmp/sifasilitas_uji.jpg'),
          ),
        ],
        child: const MaterialApp(home: PelaporHome(user: _user)),
      ),
    );
  }

  testWidgets('tombol Pindai QR ruangan membuka layar pemindai', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Pindai QR ruangan'), findsOneWidget);
    await tester.tap(find.text('Pindai QR ruangan'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Pindai QR ruangan'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pindai QR sampai layar hasil, back kembali ke beranda', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('Pindai QR ruangan'));
    await tester.pumpAndSettle();
    scanner.emitQr('QR-GDA-201');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut buat laporan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QR-GDA-201'), findsOneWidget);

    // Tombol kirim memvalidasi form, jadi foto dan deskripsi diisi dulu.
    await tester.tap(find.text('Ambil foto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Proyektor tidak menyala sejak Senin pagi.',
    );
    // "Selesai" di keyboard: saran AI mengisi kategori.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kirim (contoh, sementara)'));
    await tester.tap(find.text('Kirim (contoh, sementara)'));
    await tester.pumpAndSettle();
    expect(find.text('CONTOH-0001'), findsOneWidget);

    // Simulasi tombol back sistem.
    final popped = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(popped, isTrue);
    expect(find.text('Beranda Pelapor'), findsOneWidget);
    expect(find.byType(ReportSubmittedScreen), findsNothing);
  });

  testWidgets('layar hasil tidak crash bila field map kosong', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ReportSubmittedScreen(result: {})),
    );
    expect(find.text('-'), findsNWidgets(2));
  });
}
