import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/report_service.dart';

void main() {
  group('ReportService.isValidTransition', () {
    // Satu-satunya transisi yang sah (current -> daftar next).
    const allowed = <ReportStatus, Set<ReportStatus>>{
      ReportStatus.reported: {ReportStatus.verified, ReportStatus.rejected},
      ReportStatus.verified: {ReportStatus.assigned, ReportStatus.rejected},
      ReportStatus.assigned: {ReportStatus.inProgress},
      ReportStatus.inProgress: {ReportStatus.resolved},
      ReportStatus.resolved: {},
      ReportStatus.rejected: {},
    };

    for (final current in ReportStatus.values) {
      for (final next in ReportStatus.values) {
        final expected = allowed[current]!.contains(next);
        test('${current.value} -> ${next.value} == $expected', () {
          expect(ReportService.isValidTransition(current, next), expected);
        });
      }
    }
  });

  group('ReportService.canChangeStatus (tabel peran)', () {
    const actor = 'uid-teknisi-1';
    const other = 'uid-teknisi-2';

    bool can(UserRole role, ReportStatus next, {String? assigned = actor}) =>
        ReportService.canChangeStatus(
          role: role,
          actorUid: actor,
          newStatus: next,
          currentAssignedUid: assigned,
        );

    test('admin: hanya verified, rejected, assigned', () {
      expect(can(UserRole.admin, ReportStatus.verified), isTrue);
      expect(can(UserRole.admin, ReportStatus.rejected), isTrue);
      expect(can(UserRole.admin, ReportStatus.assigned), isTrue);
      expect(can(UserRole.admin, ReportStatus.inProgress), isFalse);
      expect(can(UserRole.admin, ReportStatus.resolved), isFalse);
      expect(can(UserRole.admin, ReportStatus.reported), isFalse);
    });

    test('teknisi: tidak boleh verified, rejected, assigned', () {
      expect(can(UserRole.teknisi, ReportStatus.verified), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.rejected), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.assigned), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.reported), isFalse);
    });

    test('teknisi yang ditugaskan boleh in_progress dan resolved', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress), isTrue);
      expect(can(UserRole.teknisi, ReportStatus.resolved), isTrue);
    });

    test('teknisi lain (bukan yang ditugaskan) ditolak', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress, assigned: other), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.resolved, assigned: other), isFalse);
    });

    test('tiket belum punya teknisi: in_progress/resolved ditolak', () {
      expect(can(UserRole.teknisi, ReportStatus.inProgress, assigned: null), isFalse);
      expect(can(UserRole.teknisi, ReportStatus.resolved, assigned: ''), isFalse);
    });

    test('admin tidak boleh in_progress/resolved walau UID-nya sama', () {
      expect(can(UserRole.admin, ReportStatus.inProgress), isFalse);
      expect(can(UserRole.admin, ReportStatus.resolved), isFalse);
    });

    test('pelapor ditolak untuk semua status', () {
      for (final s in ReportStatus.values) {
        expect(can(UserRole.pelapor, s), isFalse, reason: s.value);
      }
    });
  });

  group('ReportService.ticketNumberFor', () {
    test('format TKT-YYYYMMDD-XXXXXX dari 6 karakter pertama ID dokumen', () {
      expect(
        ReportService.ticketNumberFor(
          DateTime(2026, 11, 17),
          'AbCdEfGhIjKlMnOpQrSt',
        ),
        'TKT-20261117-AbCdEf',
      );
    });

    test('bulan dan hari satu digit diberi nol di depan', () {
      expect(
        ReportService.ticketNumberFor(DateTime(2026, 3, 5), 'abcdef123456'),
        'TKT-20260305-abcdef',
      );
    });

    test('cocok dengan pola yang didokumentasikan', () {
      final number = ReportService.ticketNumberFor(
        DateTime(2026, 12, 31),
        'Zy9Xw8Vu7Ts6Rq5Po4Nm',
      );
      expect(number, matches(RegExp(r'^TKT-\d{8}-[A-Za-z0-9]{6}$')));
    });

    test('ID yang lebih pendek dari 6 karakter tidak melempar error', () {
      expect(
        ReportService.ticketNumberFor(DateTime(2026, 1, 2), 'abc'),
        'TKT-20260102-abc',
      );
    });
  });

  group('ReportService.activeTicketKey', () {
    test('format {locationId}_{categoryId}', () {
      expect(
        ReportService.activeTicketKey('loc_r101', 'cat_ac'),
        'loc_r101_cat_ac',
      );
    });
  });
}
