import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_icon_size.dart';
import '../theme/app_text_theme.dart';

/// Daftar tab navigasi bawah untuk peran Pelapor.
enum PelaporTab {
  beranda,
  riwayat,
  pindai,
  profil;

  String get label {
    switch (this) {
      case PelaporTab.beranda:
        return 'Beranda';
      case PelaporTab.riwayat:
        return 'Riwayat';
      case PelaporTab.pindai:
        return 'Pindai';
      case PelaporTab.profil:
        return 'Profil';
    }
  }

  IconData get icon {
    switch (this) {
      case PelaporTab.beranda:
        return Icons.home_outlined;
      case PelaporTab.riwayat:
        return Icons.assignment_outlined;
      case PelaporTab.pindai:
        return Icons.qr_code_scanner_outlined;
      case PelaporTab.profil:
        return Icons.person_outline_rounded;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case PelaporTab.beranda:
        return Icons.home_rounded;
      case PelaporTab.riwayat:
        return Icons.assignment_rounded;
      case PelaporTab.pindai:
        return Icons.qr_code_scanner_rounded;
      case PelaporTab.profil:
        return Icons.person_rounded;
    }
  }
}

class PelaporBottomNavBar extends StatelessWidget {
  const PelaporBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = PelaporTab.values,
  });

  /// Index tab yang sedang aktif.
  final int currentIndex;

  /// Callback ketika salah satu tab ditekan.
  final ValueChanged<int> onTap;

  /// Daftar tab yang ditampilkan (default: semua nilai [PelaporTab]).
  final List<PelaporTab> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _PelaporNavItem(
                    tab: tabs[i],
                    isSelected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item navigasi individual dengan state hover dan animasi seleksi.
class _PelaporNavItem extends StatefulWidget {
  const _PelaporNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final PelaporTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_PelaporNavItem> createState() => _PelaporNavItemState();
}

class _PelaporNavItemState extends State<_PelaporNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isHovered = _isHovered;

    final Color activeColor = AppColors.primary;
    final Color inactiveColor = AppColors.muted;
    final Color currentColor = (isSelected || isHovered) ? activeColor : inactiveColor;

    // Warna kapsul latar belakang (pill)
    Color pillColor = Colors.transparent;
    if (isSelected) {
      pillColor = AppColors.primaryContainer; // soft emerald highlight (#D9F2E3)
    } else if (isHovered) {
      pillColor = AppColors.primary.withValues(alpha: 0.08); // hover glow
    }

    // Skala animasi ikon (membal saat aktif, membesar halus saat hover)
    final double iconScale = isSelected ? 1.15 : (isHovered ? 1.08 : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Kapsul animasi untuk ikon
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 18 : (isHovered ? 14 : 10),
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: AnimatedScale(
                  scale: iconScale,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    isSelected ? widget.tab.activeIcon : widget.tab.icon,
                    size: AppIconSize.small,
                    color: currentColor,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Label teks dengan animasi transisi style
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                style: AppTextTheme.theme.labelSmall!.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected
                      ? FontWeight.w700
                      : (isHovered ? FontWeight.w600 : FontWeight.w500),
                  color: currentColor,
                ),
                child: Text(
                  widget.tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              // Indikator garis bawah aktif
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: isSelected ? 14 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
