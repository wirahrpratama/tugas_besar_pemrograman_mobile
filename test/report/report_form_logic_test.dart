import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/services/ai_classifier_service.dart';
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

  group('aturan prioritas', () {
    const saran = DamageClassificationResult(
      categoryId: 'cat_proyektor',
      prioritas: 'Tinggi ',
      alasanSingkat: '-',
    );
    const toilet = FacilityCategory(
      id: 'cat_toilet',
      namaObjek: 'Toilet',
      prioritasDefault: 'sedang',
      targetSlaJam: 8,
    );
    const proyektor = FacilityCategory(
      id: 'cat_proyektor',
      namaObjek: 'Proyektor',
      prioritasDefault: 'rendah',
      targetSlaJam: 4,
    );

    test('kategori saran tidak diubah: prioritas AI dikirim', () {
      expect(prioritasUntukDikirim(saran, 'cat_proyektor'), 'Tinggi');
    });

    test('kategori diganti atau belum ada saran: null', () {
      expect(prioritasUntukDikirim(saran, 'cat_toilet'), isNull);
      expect(prioritasUntukDikirim(null, 'cat_proyektor'), isNull);
      expect(prioritasUntukDikirim(saran, null), isNull);
    });

    test('prioritas AI kosong dianggap tidak ada', () {
      const kosong = DamageClassificationResult(
        categoryId: 'cat_proyektor',
        prioritas: '  ',
        alasanSingkat: '-',
      );
      expect(prioritasUntukDikirim(kosong, 'cat_proyektor'), isNull);
    });

    test('prioritasTampil sama dengan logika submitReport', () {
      expect(prioritasTampil(saran, proyektor), (
        prioritas: 'tinggi',
        dariAi: true,
      ));
      expect(prioritasTampil(saran, toilet), (
        prioritas: 'sedang',
        dariAi: false,
      ));
    });

    test('labelPrioritas', () {
      expect(labelPrioritas('darurat'), 'Darurat');
      expect(labelPrioritas(' TINGGI '), 'Tinggi');
      expect(labelPrioritas(''), '-');
      expect(labelPrioritas('urgent'), 'urgent');
    });
  });

  group('pesanGagalKirim', () {
    const koneksi =
        'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba '
        'lagi.';

    FirebaseException fb(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);

    test('timeout dan jaringan = pesan koneksi', () {
      expect(pesanGagalKirim(TimeoutException('x'), saatUpload: true), koneksi);
      expect(pesanGagalKirim(fb('unavailable'), saatUpload: false), koneksi);
      expect(
        pesanGagalKirim(fb('network-request-failed'), saatUpload: true),
        koneksi,
      );
    });

    test('permission-denied dan sesi', () {
      expect(
        pesanGagalKirim(fb('permission-denied'), saatUpload: false),
        'Akses ditolak server. Coba keluar lalu masuk lagi.',
      );
      expect(
        pesanGagalKirim(
          StateError('401 Unauthorized: Pengguna harus login.'),
          saatUpload: true,
        ),
        'Sesi masuk berakhir. Silakan masuk lagi.',
      );
    });

    test('403/422 dari service apa adanya tanpa awalan Exception', () {
      expect(
        pesanGagalKirim(
          Exception('422 Validasi Gagal: Deskripsi kosong.'),
          saatUpload: false,
        ),
        '422 Validasi Gagal: Deskripsi kosong.',
      );
    });

    test('foto tidak bisa diproses saat upload', () {
      const pesan =
          'Foto tidak bisa diproses. Ambil ulang foto lalu coba lagi.';
      expect(
        pesanGagalKirim(StateError('Gagal mengompres'), saatUpload: true),
        pesan,
      );
      expect(
        pesanGagalKirim(
          ArgumentError('File tidak ditemukan'),
          saatUpload: true,
        ),
        pesan,
      );
    });

    test('lainnya: pesan umum sesuai tahap', () {
      expect(
        pesanGagalKirim(Exception('aneh'), saatUpload: true),
        'Gagal mengunggah foto. Coba lagi.',
      );
      expect(
        pesanGagalKirim(Exception('aneh'), saatUpload: false),
        'Gagal mengirim laporan. Coba lagi.',
      );
    });
  });
}
