import 'package:flutter/material.dart';

/// Skala spacing konsisten (basis 4px) untuk seluruh aplikasi.
///
/// Gunakan konstanta [AppSpacing.xs] dst. untuk `SizedBox`, margin, dan gap.
/// Untuk padding penuh, gunakan helper [AppSpacing.paddingAll] /
/// [AppSpacing.paddingHorizontal] / [AppSpacing.paddingVertical].
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Padding standar konten layar (semua sisi).
  static const EdgeInsets paddingAllLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingAllXl = EdgeInsets.all(xl);

  /// Padding horizontal standar konten layar.
  static const EdgeInsets paddingHorizontalLg =
      EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl =
      EdgeInsets.symmetric(horizontal: xl);

  /// Padding vertikal standar.
  static const EdgeInsets paddingVerticalLg =
      EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXl =
      EdgeInsets.symmetric(vertical: xl);
}
