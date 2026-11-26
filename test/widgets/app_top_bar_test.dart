import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/widgets/app_top_bar.dart';

void main() {
  group('AppTopBar', () {
    testWidgets('menampilkan logo di kiri, judul di tengah, dan profil di kanan', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppTopBar(
              title: 'Beranda Pelapor',
              userName: 'Adi Utama',
              onProfileTap: () => tapped = true,
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      final logoCenter = tester.getCenter(find.byType(Image));
      final titleCenter = tester.getCenter(find.text('Beranda Pelapor'));
      final profileCenter = tester.getCenter(find.text('AU'));

      expect(logoCenter.dx, lessThan(titleCenter.dx));
      expect(profileCenter.dx, greaterThan(titleCenter.dx));
      expect((titleCenter.dx - 400).abs(), lessThan(20));

      await tester.tap(find.text('AU'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets(
      'AppBackButton berada di bawah logo luar TopBar dan berfungsi pop',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        appBar: AppTopBar(title: 'Buat laporan'),
                        body: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: 16, top: 8),
                              child: AppBackButton(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();

        // BackButton TIDAK ada di dalam AppBar, tetapi ada di bawah logo.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(BackButton),
          ),
          findsNothing,
        );
        expect(find.byType(BackButton), findsOneWidget);

        final logoRect = tester.getRect(find.byType(Image));
        final backRect = tester.getRect(find.byType(BackButton));
        expect(backRect.top, greaterThanOrEqualTo(logoRect.bottom - 10));
        expect((backRect.center.dx - logoRect.center.dx).abs(), lessThan(12));

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Buka'), findsOneWidget);
      },
    );
  });
}
