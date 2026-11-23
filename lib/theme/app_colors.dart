import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Hijau utama brand (seed color tema).
  static const Color primary = Color(0xFF108A43);

  /// Varian hijau untuk permukaan terang (chip, badge, highlight).
  static const Color primaryContainer = Color(0xFFD9F2E3);

  /// Warna untuk status sukses / tiket resolved.
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainer = Color(0xFFE8F5E9);

  /// Warna untuk status peringatan / prioritas tinggi.
  static const Color warning = Color(0xFFF9A825);
  static const Color warningContainer = Color(0xFFFFF8E1);

  /// Warna untuk status bahaya / tiket rejected.
  static const Color danger = Color(0xFFC62828);
  static const Color dangerContainer = Color(0xFFFFEBEE);

  /// Warna untuk status info / dalam proses.
  static const Color info = Color(0xFF1565C0);
  static const Color infoContainer = Color(0xFFE3F2FD);

  /// Warna netral untuk teks sekunder & ikon non-interaktif.
  static const Color muted = Color(0xFF757575);

  /// Latar kartu & permukaan.
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F7F5);
}
