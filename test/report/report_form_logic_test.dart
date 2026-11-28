import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/screens/report/report_form_logic.dart';

void main() {
  group('validasiDeskripsi', () {
    test('null, kosong, dan spasi saja = wajib diisi', () {
      for (final v in [null, '', '   \n  ']) {
        expect(validasiDeskripsi(v), 'Deskripsi kerusakan wajib diisi.');
      }
    });

    test('14 karakter ditolak dengan jumlah saat ini', () {
      expect(
        validasiDeskripsi('a' * 14),
        'Deskripsi minimal 15 karakter (sekarang 14).',
      );
    });

    test('15 karakter diterima', () {
      expect(validasiDeskripsi('a' * 15), isNull);
    });

    test('spasi di awal/akhir tidak ikut dihitung', () {
      expect(
        validasiDeskripsi('   ${'a' * 14}   '),
        'Deskripsi minimal 15 karakter (sekarang 14).',
      );
    });

    test('500 diterima, 501 ditolak', () {
      expect(validasiDeskripsi('a' * 500), isNull);
      expect(validasiDeskripsi('a' * 501), 'Deskripsi maksimal 500 karakter.');
    });
  });
}
