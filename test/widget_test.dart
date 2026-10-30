import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sifasilitas/screens/auth/login_screen.dart';
import 'package:sifasilitas/screens/auth/register_screen.dart';
import 'package:sifasilitas/services/auth_service.dart';

Widget _wrap(Widget child) {
  return Provider<AuthService>(
    create: (_) => AuthService(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('Login menampilkan error validasi saat form kosong', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();

    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Password wajib diisi.'), findsOneWidget);
  });

  testWidgets('Register mengganti label NIM menjadi NIP untuk dosen', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));

    expect(find.text('NIM'), findsOneWidget);
    expect(find.text('NIP'), findsNothing);

    await tester.tap(find.text('Mahasiswa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dosen').last);
    await tester.pumpAndSettle();

    expect(find.text('NIP'), findsOneWidget);
    expect(find.text('NIM'), findsNothing);
  });

  testWidgets('Register menolak email non-kampus', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email Kampus'),
      'leondo@gmail.com',
    );
    final daftarButton = find.widgetWithText(FilledButton, 'Daftar');
    await tester.ensureVisible(daftarButton);
    await tester.tap(daftarButton);
    await tester.pump();

    expect(
      find.text('Gunakan email kampus (@students.usu.ac.id atau @usu.ac.id).'),
      findsOneWidget,
    );
  });
}
