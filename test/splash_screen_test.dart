import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sifasilitas/screens/onboarding/onboarding_screen.dart';
import 'package:sifasilitas/screens/splash/splash_screen.dart';
import 'package:sifasilitas/utils/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SplashScreen menampilkan logo dan teks SiFasilitas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(autoNavigate: false, animate: false),
      ),
    );

    // Brand text harus ada
    expect(find.text('SiFasilitas'), findsOneWidget);
  });

  testWidgets(
    'SplashScreen navigasi ke OnboardingScreen jika onboarding belum selesai',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.onboardingCompleted: false,
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoNavigate: true, animate: false),
        ),
      );

      // Frame pertama: navigasi dipanggil via addPostFrameCallback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingScreen), findsOneWidget);
    },
  );

  testWidgets(
    'SplashScreen destinationBuilder kustom digunakan saat disuplai',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        StorageKeys.onboardingCompleted: true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            autoNavigate: true,
            animate: false,
            destinationBuilder: (context, completed) {
              return Scaffold(
                body: Text(completed ? 'Sudah Onboarding' : 'Belum Onboarding'),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sudah Onboarding'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    },
  );
}
