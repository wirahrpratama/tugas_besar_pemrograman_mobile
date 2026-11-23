import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sifasilitas/screens/onboarding/onboarding_screen.dart';
import 'package:sifasilitas/utils/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Onboarding menampilkan 3 slide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(animateForever: false)),
    );

    expect(find.text('Lapor Kerusakan'), findsOneWidget);
    expect(find.text('Pantau Perbaikan'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Pantau Perbaikan'), findsOneWidget);
    expect(find.text('Login Sesuai Peran'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Login Sesuai Peran'), findsOneWidget);
  });

  testWidgets('Tombol Lewati muncul hanya di slide awal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(animateForever: false)),
    );

    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Mulai'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Lewati'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Lewati'), findsNothing);
    expect(find.text('Mulai'), findsOneWidget);
  });

  testWidgets('Menyimpan onboarding_completed saat lewati', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () => completed = true,
          animateForever: false,
        ),
      ),
    );

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(await StorageKeys.isOnboardingCompleted(), isTrue);
    expect(completed, isTrue);
  });

  testWidgets('Menyimpan onboarding_completed saat Mulai', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          onCompleted: () => completed = true,
          animateForever: false,
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    expect(await StorageKeys.isOnboardingCompleted(), isTrue);
    expect(completed, isTrue);
  });
}
