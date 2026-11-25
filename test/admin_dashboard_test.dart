import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/home/admin_dashboard.dart';
import 'package:sifasilitas/services/report_repository.dart';

void main() {
  testWidgets('admin dashboard shows ticket summary and queue filters', (
    tester,
  ) async {
    final repository = _FakeReportRepository([
      _report('TKT-URGENT', 'darurat'),
      _report('TKT-NORMAL', 'sedang'),
    ]);

    await tester.pumpWidget(
      Provider<ReportRepository>.value(
        value: repository,
        child: MaterialApp(home: AdminDashboard(user: _admin)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Halo, Admin Uji'), findsOneWidget);
    expect(find.text('Tiket tampil'), findsOneWidget);
    expect(find.text('Darurat'), findsOneWidget);
    expect(find.text('Filter antrean'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Antrean tiket'), 200);
    await tester.pumpAndSettle();

    expect(find.text('Antrean tiket'), findsOneWidget);
    expect(find.text('TKT-URGENT'), findsOneWidget);
    expect(find.text('TKT-NORMAL'), findsOneWidget);
  });
}

const _admin = AppUser(
  uid: 'admin-1',
  nama: 'Admin Uji',
  identityNumber: '0001',
  email: 'admin@example.com',
  subRole: 'admin',
  role: UserRole.admin,
);

Report _report(String ticketNumber, String priority) => Report(
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
  prioritas: priority,
  prioritasRank: Report.priorityRankFor(priority),
  targetSlaJam: 6,
  deskripsi: 'AC tidak dingin.',
  fotoSebelumUrl: '',
  status: ReportStatus.reported,
  upvotesCount: 1,
  supporterUids: const ['reporter-1'],
  confirmedByReporter: false,
);

class _FakeReportRepository implements ReportRepository {
  _FakeReportRepository(this.reports);

  final List<Report> reports;

  @override
  Stream<List<Report>> watchReportsForAdmin({
    ReportStatus? status,
    String? prioritas,
  }) {
    return Stream.value(
      reports
          .where(
            (report) =>
                (status == null || report.status == status) &&
                (prioritas == null || report.prioritas == prioritas),
          )
          .toList(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
