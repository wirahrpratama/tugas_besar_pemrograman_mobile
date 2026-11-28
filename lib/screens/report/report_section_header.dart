import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Judul section di layar laporan, menyalin pola `_SectionHeader` di
/// `pelapor_home.dart` (ikon + HURUF BESAR `labelSmall` w600, warna muted,
/// letterSpacing 0.8) agar alur pelapor punya hierarki font yang sama.
///
/// Disalin, bukan dipakai langsung: widget aslinya privat di file milik
/// Leondo, dan `lib/widgets/` milik Wira. Bila tim memindahkannya ke
/// `lib/widgets/`, widget ini bisa diganti.
class ReportSectionHeader extends StatelessWidget {
  const ReportSectionHeader({
    super.key,
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
