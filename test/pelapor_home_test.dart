import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/pelapor_home.dart';
import 'package:sifasilitas/services/report_repository.dart';

void main() {
  const pelapor = AppUser(
    uid: 'pelapor-1',
    nama: 'Leondo Purba',
    identityNumber: '241402053',
    email: 'leondo@email.com',
    subRole: 'mahasiswa',
    role: UserRole.pelapor,
  );

  Report makeReport(String ticket, ReportStatus status) => Report(
    id: ticket,
    ticketNumber: ticket,
    reporterUid: 'pelapor-1',
    reporterName: 'Leondo Purba',
    reporterSubRole: 'mahasiswa',
    locationId: 'loc-1',
    kodeRuangan: 'QR-101',
    namaGedung: 'Gedung A',
    namaRuangan: 'Ruang 101',
    categoryId: 'cat-ac',
    namaObjek: 'AC Ruangan',
    prioritas: 'tinggi',
    prioritasRank: 2,
    targetSlaJam: 6,
    deskripsi: 'AC bocor dan tidak dingin.',
    fotoSebelumUrl: '',
    status: status,
    upvotesCount: 1,
    supporterUids: const ['pelapor-1'],
    confirmedByReporter: false,
  );

  testWidgets('PelaporHome menampilkan ringkasan identitas, metrik, dan aduan aktif', (
    tester,
  ) async {
    final repo = _FakePelaporRepo([
      makeReport('TKT-01', ReportStatus.inProgress),
      makeReport('TKT-02', ReportStatus.reported),
      makeReport('TKT-03', ReportStatus.resolved),
    ]);

    await tester.pumpWidget(
      Provider<ReportRepository>.value(
        value: repo,
        child: const MaterialApp(home: PelaporHome(user: pelapor)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Halo, Leondo Purba'), findsOneWidget);
    expect(find.text('NIM 241402053'), findsOneWidget);
    expect(find.text('Mahasiswa'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Aktif
    expect(find.text('1'), findsOneWidget); // Selesai
    expect(find.text('3'), findsOneWidget); // Total
    expect(find.text('Sedang Dikerjakan'), findsOneWidget);
    expect(find.text('+1 aduan aktif lainnya'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('SLA 2 Jam'), 200);
    expect(find.text('SLA 2 Jam'), findsOneWidget);
  });

  testWidgets('Mengetuk kategori menampilkan info SLA dalam snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PelaporHome(user: pelapor)),
    );

    await tester.scrollUntilVisible(find.text('Kelistrikan'), 200);
    await tester.tap(find.text('Kelistrikan'));
    await tester.pump();

    expect(
      find.textContaining('Prioritas Darurat, target SLA 2 Jam'),
      findsOneWidget,
    );
  });
}

class _FakePelaporRepo implements ReportRepository {
  _FakePelaporRepo(this.reports);

  final List<Report> reports;

  @override
  Stream<List<Report>> watchReportsForReporter(String uid) =>
      Stream.value(reports);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
