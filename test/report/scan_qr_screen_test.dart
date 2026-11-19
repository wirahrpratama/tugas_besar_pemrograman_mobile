import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/report/scan_qr_screen.dart';

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
  late FakeScannerPlatform fake;

  setUp(() {
    fake = FakeScannerPlatform();
    MobileScannerPlatform.instance = fake;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanQrScreen(user: _user)));
    await tester.pumpAndSettle();
  }

  testWidgets('QR yang terbaca beruntun hanya diproses sekali', (tester) async {
    await pumpScreen(tester);
    expect(fake.startCalls, 1);

    fake.emitQr('QR-GDA-201');
    fake.emitQr('QR-GDA-201');
    fake.emitQr('QR-LAIN-999');
    await tester.pumpAndSettle();

    expect(find.text('QR terbaca: QR-GDA-201'), findsOneWidget);
    expect(find.textContaining('QR-LAIN-999'), findsNothing);

    await tester.tap(find.text('Pindai lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('QR terbaca'), findsNothing);

    // Setelah "Pindai lagi", deteksi berikutnya diterima lagi.
    fake.emitQr('QR-LAIN-999');
    await tester.pumpAndSettle();
    expect(find.text('QR terbaca: QR-LAIN-999'), findsOneWidget);
  });

  testWidgets('QR kosong diabaikan', (tester) async {
    await pumpScreen(tester);

    fake.emitQr('   ');
    await tester.pumpAndSettle();

    expect(find.textContaining('QR terbaca'), findsNothing);
  });

  testWidgets('izin kamera ditolak menampilkan pesan dan Coba lagi', (
    tester,
  ) async {
    fake.startError = const MobileScannerException(
      errorCode: MobileScannerErrorCode.permissionDenied,
    );
    await pumpScreen(tester);

    expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);

    // Pengguna mengizinkan di Pengaturan lalu menekan Coba lagi.
    fake.startError = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(fake.startCalls, 2);
    expect(find.textContaining('Izin kamera ditolak'), findsNothing);
  });

  testWidgets('kamera dimatikan saat form dibuka dan dinyalakan saat kembali', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lanjut (contoh, sementara)'));
    await tester.pumpAndSettle();
    expect(fake.stopCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(fake.startCalls, 2);
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
