import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Hijau utama brand (seed color tema).
  static const Color primary = Color(0xFF108A43);

  /// Varian hijau gelap untuk header, tombol aktif, dan kontras tinggi.
  static const Color primaryDark = Color(0xFF0B6330);

  /// Varian hijau cerah untuk aksen halus gradien.
  static const Color primaryLight = Color(0xFF16A34A);

  /// Varian hijau lembut untuk permukaan chip, badge, dan highlight aktif.
  static const Color primaryContainer = Color(0xFFDCFCE7);

  /// Warna aksen sekunder (Teal) untuk elemen AI & QR.
  static const Color secondary = Color(0xFF0F766E);
  static const Color secondaryContainer = Color(0xFFCCFBF1);

  /// Warna aksen hangat (Amber) khusus untuk sorotan semantik/prioritas.
  static const Color accent = Color(0xFFD97706);
  static const Color accentContainer = Color(0xFFFEF3C7);

  /// Warna highlight permukaan & border netral/aktif yang bersih.
  static const Color highlight = Color(0xFFF0FDF4);
  static const Color highlightBorder = Color(0xFFBBF7D0);
  static const Color border = Color(0xFFE2E8F0);

  /// Warna tipografi utama (slate gelap) & sekunder (slate muted).
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  /// Warna untuk status sukses / tiket resolved.
  static const Color success = Color(0xFF15803D);
  static const Color successContainer = Color(0xFFDCFCE7);

  /// Warna untuk status peringatan / prioritas tinggi.
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);

  /// Warna untuk status bahaya / tiket rejected / darurat.
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerContainer = Color(0xFFFEE2E2);

  /// Warna untuk status info / dalam proses.
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoContainer = Color(0xFFDBEAFE);

  /// Latar kartu & permukaan halaman.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);

  /// Gradien hero utama yang elegan dan tidak mencolok.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
