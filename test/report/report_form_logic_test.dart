import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
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

  group('validasiFoto', () {
    test('wajib ada', () {
      expect(validasiFoto(null), 'Foto kerusakan wajib dilampirkan.');
      expect(validasiFoto(XFile('/tmp/a.jpg')), isNull);
    });
  });

  group('pesanGagalAmbilFoto', () {
    test('picker masih terbuka tidak perlu pesan', () {
      expect(pesanGagalAmbilFoto('already_active', ImageSource.camera), isNull);
      expect(
        pesanGagalAmbilFoto('multiple_request', ImageSource.gallery),
        isNull,
      );
    });

    test('izin ditolak dibedakan kamera dan galeri', () {
      expect(
        pesanGagalAmbilFoto('camera_access_denied', ImageSource.camera),
        startsWith('Izin kamera ditolak'),
      );
      expect(
        pesanGagalAmbilFoto('photo_access_denied', ImageSource.gallery),
        startsWith('Izin galeri ditolak'),
      );
    });

    test('kamera tidak tersedia menyarankan galeri', () {
      expect(
        pesanGagalAmbilFoto('no_available_camera', ImageSource.camera),
        contains('galeri'),
      );
    });

    test('kode tak dikenal: pesan umum sesuai sumber', () {
      expect(
        pesanGagalAmbilFoto('lainnya', ImageSource.camera),
        'Gagal membuka kamera. Silakan coba lagi.',
      );
      expect(
        pesanGagalAmbilFoto('lainnya', ImageSource.gallery),
        'Gagal membuka galeri. Silakan coba lagi.',
      );
    });
  });
}
