/// Logika murni form laporan, dipisah dari widget agar mudah diuji unit.
library;

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
