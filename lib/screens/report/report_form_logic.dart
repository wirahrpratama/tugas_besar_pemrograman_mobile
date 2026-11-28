/// Logika murni form laporan, dipisah dari widget agar mudah diuji unit.
library;

import 'package:image_picker/image_picker.dart';

import '../../models/report_models.dart';
import '../../services/ai_classifier_service.dart';

/// Validator foto kerusakan: wajib ada.
String? validasiFoto(XFile? foto) =>
    foto == null ? 'Foto kerusakan wajib dilampirkan.' : null;

/// Pesan ramah untuk kode error `PlatformException` dari `image_picker`.
///
/// Kode diambil dari sumber paket (image_picker_android 0.8.13 dan
/// image_picker_ios 0.8.13). Mengembalikan `null` bila error tidak perlu
/// ditampilkan (picker masih terbuka dari tekanan sebelumnya).
String? pesanGagalAmbilFoto(String code, ImageSource source) {
  switch (code) {
    case 'already_active' || 'multiple_request':
      return null;
    case 'camera_access_denied' || 'camera_access_restricted':
      return 'Izin kamera ditolak. Izinkan kamera di Pengaturan > Aplikasi > '
          'SiFasilitas > Izin, lalu coba lagi.';
    case 'photo_access_denied' || 'photo_access_restricted':
      return 'Izin galeri ditolak. Izinkan akses foto di Pengaturan, '
          'lalu coba lagi.';
    case 'no_available_camera':
      return 'Kamera tidak tersedia. Pilih foto dari galeri.';
    case 'invalid_image' || 'no_valid_image_uri':
      return 'File yang dipilih bukan foto yang bisa dibaca. Pilih foto lain.';
  }
  return source == ImageSource.camera
      ? 'Gagal membuka kamera. Silakan coba lagi.'
      : 'Gagal membuka galeri. Silakan coba lagi.';
}

/// Panjang minimal deskripsi (contoh dosen, pertemuan 09 slide 11).
const deskripsiMinimal = 15;

/// Panjang maksimal deskripsi; juga dipakai sebagai `maxLength` field.
const deskripsiMaksimal = 500;

/// Validator deskripsi kerusakan: wajib, 15–500 karakter setelah spasi di
/// awal/akhir dipotong. Mengembalikan pesan error, atau `null` bila valid.
String? validasiDeskripsi(String? value) {
  final teks = value?.trim() ?? '';
  if (teks.isEmpty) return 'Deskripsi kerusakan wajib diisi.';
  if (teks.length < deskripsiMinimal) {
    return 'Deskripsi minimal $deskripsiMinimal karakter '
        '(sekarang ${teks.length}).';
  }
  if (teks.length > deskripsiMaksimal) {
    return 'Deskripsi maksimal $deskripsiMaksimal karakter.';
  }
  return null;
}

/// Label tampilan untuk kode prioritas (`rendah|sedang|tinggi|darurat`).
String labelPrioritas(String prioritas) {
  final kode = prioritas.trim().toLowerCase();
  return switch (kode) {
    'darurat' => 'Darurat',
    'tinggi' => 'Tinggi',
    'sedang' => 'Sedang',
    'rendah' => 'Rendah',
    '' => '-',
    _ => prioritas.trim(),
  };
}

/// Nilai `aiSuggestedPriority` untuk `ReportService.submitReport`.
///
/// Aturan (spesifikasi layar): prioritas AI hanya dipakai bila pelapor TIDAK
/// mengganti kategori saran. Bila kategori diganti, kirim `null` sehingga
/// service memakai `prioritasDefault` kategori pilihan pelapor.
String? prioritasUntukDikirim(
  DamageClassificationResult? saran,
  String? kategoriTerpilihId,
) {
  if (saran == null || kategoriTerpilihId == null) return null;
  if (saran.categoryId != kategoriTerpilihId) return null;
  final prioritas = saran.prioritas.trim();
  return prioritas.isEmpty ? null : prioritas;
}

/// Prioritas yang akan tercatat di tiket, sama persis dengan logika
/// `submitReport` (trim + huruf kecil, kosong → default kategori), supaya
/// chip di layar tidak berbeda dengan hasil di server.
({String prioritas, bool dariAi}) prioritasTampil(
  DamageClassificationResult? saran,
  FacilityCategory kategori,
) {
  final ai = prioritasUntukDikirim(saran, kategori.id);
  if (ai != null) return (prioritas: ai.toLowerCase(), dariAi: true);
  return (prioritas: kategori.prioritasDefault, dariAi: false);
}
