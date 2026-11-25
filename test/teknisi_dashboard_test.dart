import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/teknisi_dashboard.dart';
import 'package:sifasilitas/services/report_repository.dart';

void main() {
  testWidgets('technician can filter assigned and in-progress tasks', (
    tester,
  ) async {
    final repository = _FakeReportRepository([
      _report('TKT-ASSIGNED', ReportStatus.assigned),
      _report('TKT-PROGRESS', ReportStatus.inProgress),
    ]);

    await tester.pumpWidget(
      Provider<ReportRepository>.value(
        value: repository,
        child: MaterialApp(home: TeknisiDashboard(user: _technician)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Halo, Vincent'), findsOneWidget);
    expect(find.text('TKT-ASSIGNED'), findsOneWidget);
    expect(find.text('TKT-PROGRESS'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ditugaskan'));
    await tester.pumpAndSettle();

    expect(find.text('TKT-ASSIGNED'), findsOneWidget);
    expect(find.text('TKT-PROGRESS'), findsNothing);
  });
}

const _technician = AppUser(
  uid: 'technician-1',
  nama: 'Vincent',
  identityNumber: '241402039',
  email: 'vincent@example.com',
  subRole: 'teknisi',
  role: UserRole.teknisi,
);

Report _report(String ticketNumber, ReportStatus status) => Report(
  id: ticketNumber,
  ticketNumber: ticketNumber,
  reporterUid: 'reporter-1',
  reporterName: 'Pelapor',
  reporterSubRole: 'mahasiswa',
  locationId: 'location-1',
  kodeRuangan: 'QR-101',
  namaGedung: 'Gedung A',
  namaRuangan: 'Ruang 101',
  categoryId: 'cat-ac',
  namaObjek: 'AC',
  prioritas: 'tinggi',
  prioritasRank: 2,
  targetSlaJam: 6,
  deskripsi: 'AC tidak dingin.',
  fotoSebelumUrl: '',
  status: status,
  upvotesCount: 1,
  supporterUids: const ['reporter-1'],
  confirmedByReporter: false,
);

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.reports);

  final List<Report> reports;

  @override
  Stream<List<Report>> watchReportsForTeknisi(String uid) =>
      Stream.value(reports);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
