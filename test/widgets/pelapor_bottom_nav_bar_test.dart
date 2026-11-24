import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/widgets/pelapor_bottom_nav_bar.dart';

void main() {
  group('PelaporBottomNavBar', () {
    testWidgets('menampilkan 4 tab dengan ikon dan label yang tepat', (
      tester,
    ) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PelaporBottomNavBar(
              currentIndex: selected,
              onTap: (index) => selected = index,
            ),
          ),
        ),
      );

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Pindai'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);

      expect(find.byIcon(Icons.home_rounded), findsOneWidget); // Tab aktif
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('mengetuk tab memicu callback onTap dengan index yang sesuai', (
      tester,
    ) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PelaporBottomNavBar(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );

      // Ketuk tab Riwayat (index 1)
      await tester.tap(find.text('Riwayat'));
      await tester.pump();
      expect(tappedIndex, 1);

      // Ketuk tab Profil (index 3)
      await tester.tap(find.text('Profil'));
      await tester.pump();
      expect(tappedIndex, 3);
    });

    testWidgets('merespons pergerakan mouse hover', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PelaporBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Hover di atas tab Riwayat
      await gesture.moveTo(tester.getCenter(find.text('Riwayat')));
      await tester.pump();

      // Keluar dari tab Riwayat
      await gesture.moveTo(Offset.zero);
      await tester.pump();
    });
  });
}
