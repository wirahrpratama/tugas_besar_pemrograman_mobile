import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/pelapor_home.dart';
import 'package:sifasilitas/screens/report/report_submitted_screen.dart';

import 'fake_scanner_platform.dart';

const _user = AppUser(
  uid: 'u1',
  nama: 'Pelapor Uji',
  identityNumber: '241402000',
  email: 'uji@example.com',
  subRole: 'mahasiswa',
  role: UserRole.pelapor,
);

void main() {
  // ScanQrScreen memakai kamera; di test diganti platform palsu.
  setUp(() => MobileScannerPlatform.instance = FakeScannerPlatform());

  testWidgets('tombol Pindai QR ruangan membuka layar pemindai', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PelaporHome(user: _user)));

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

  testWidgets('alur contoh sampai layar hasil, back kembali ke beranda', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PelaporHome(user: _user)));

    await tester.tap(find.text('Pindai QR ruangan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut (contoh, sementara)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QR-GDA-201'), findsOneWidget);

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
