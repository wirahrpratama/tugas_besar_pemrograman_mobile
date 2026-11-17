import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/admin_dashboard.dart';
import 'package:sifasilitas/services/firebase_seeder.dart';
import 'package:sifasilitas/widgets/seed_master_data_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// OutlinedButton.icon membuat subclass privat, jadi byType tidak cocok.
OutlinedButton _seedButton(WidgetTester tester) => tester
    .widget<OutlinedButton>(find.byWidgetPredicate((w) => w is OutlinedButton));

/// Menekan tombol, lalu (opsional) mengonfirmasi dialog.
Future<void> _tapSeed(WidgetTester tester, {bool confirm = true}) async {
  await tester.tap(find.text('Isi Data Master'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(confirm ? 'Isi Data' : 'Batal'));
  await tester.pump();
}

void main() {
  testWidgets('AdminDashboard menampilkan tombol Isi Data Master', (
    tester,
  ) async {
    const admin = AppUser(
      uid: 'uid-admin',
      nama: 'Admin Uji',
      identityNumber: '0001',
      email: 'admin@usu.ac.id',
      subRole: 'admin',
      role: UserRole.admin,
    );
    await tester.pumpWidget(
      const MaterialApp(home: AdminDashboard(user: admin)),
    );

    expect(find.text('Dashboard Admin'), findsOneWidget);
    expect(find.text('Isi Data Master'), findsOneWidget);
  });

  testWidgets('batal pada dialog tidak menjalankan seeding', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          onSeed: () async {
            calls++;
            return const SeedResult(categoriesSeeded: 6, locationsSeeded: 10);
          },
        ),
      ),
    );

    await _tapSeed(tester, confirm: false);
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('sukses: menampilkan jumlah yang ditambahkan', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          onSeed: () async =>
              const SeedResult(categoriesSeeded: 6, locationsSeeded: 10),
        ),
      ),
    );

    await _tapSeed(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Selesai: 6 kategori ditambahkan, 10 lokasi ditambahkan.'),
      findsOneWidget,
    );
  });

  testWidgets('sebagian: koleksi yang sudah ada dilewati', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          onSeed: () async =>
              const SeedResult(categoriesSeeded: 0, locationsSeeded: 10),
        ),
      ),
    );

    await _tapSeed(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Selesai: kategori sudah ada, 10 lokasi ditambahkan.'),
      findsOneWidget,
    );
  });

  testWidgets('semua sudah ada: tidak ada yang diubah', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          onSeed: () async =>
              const SeedResult(categoriesSeeded: 0, locationsSeeded: 0),
        ),
      ),
    );

    await _tapSeed(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Data master sudah lengkap. Tidak ada yang diubah.'),
      findsOneWidget,
    );
  });

  testWidgets('permission-denied: pesan akses ditolak', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          onSeed: () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
      ),
    );

    await _tapSeed(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Akses ditolak'), findsOneWidget);
  });

  testWidgets('timeout: pesan waktu habis dan tombol aktif kembali', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SeedMasterDataButton(
          timeout: const Duration(seconds: 1),
          onSeed: () => Completer<SeedResult>().future, // tidak pernah selesai
        ),
      ),
    );

    await _tapSeed(tester);
    expect(
      _seedButton(tester).onPressed,
      isNull,
      reason: 'tombol nonaktif selama proses berjalan',
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.textContaining('Waktu habis'), findsOneWidget);
    expect(_seedButton(tester).onPressed, isNotNull);
  });

  testWidgets('error tak terduga: pesan umum', (tester) async {
    await tester.pumpWidget(
      _wrap(SeedMasterDataButton(onSeed: () async => throw StateError('boom'))),
    );

    await _tapSeed(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Gagal mengisi data master. Silakan coba lagi.'),
      findsOneWidget,
    );
  });
}
