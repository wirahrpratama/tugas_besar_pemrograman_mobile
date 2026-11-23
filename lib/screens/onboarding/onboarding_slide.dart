import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icon_size.dart';
import '../../theme/app_spacing.dart';

/// Model data satu slide onboarding.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    this.accentColor,
    this.lottieAsset,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Warna aksen opsional untuk ilustrasi (default: AppColors.primary).
  final Color? accentColor;

  /// Path ke file animasi Lottie (.json), misal 'assets/animations/onboarding_1.json'.
  final String? lottieAsset;
}

// ─────────────────────────────────────────────────────────────────────────────
// Ilustrasi Cadangan (Fallback jika Lottie belum diisi / gagal muat)
// ─────────────────────────────────────────────────────────────────────────────

/// Widget ilustrasi berlapis dengan animasi floating + elemen orbit.
class _SlideIllustration extends StatefulWidget {
  const _SlideIllustration({
    required this.icon,
    required this.accentColor,
    this.animate = true,
  });

  final IconData icon;
  final Color accentColor;
  final bool animate;

  @override
  State<_SlideIllustration> createState() => _SlideIllustrationState();
}

class _SlideIllustrationState extends State<_SlideIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _floatAnim = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _floatCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.accentColor;

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.animate ? _floatAnim.value : 0),
          child: child,
        );
      },
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Layer 1: Aura luar ──────────────────────────────────────
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: 0.06),
              ),
            ),

            // ── Layer 2: Cincin gradien sedang ─────────────────────────
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.withValues(alpha: 0.18),
                    c.withValues(alpha: 0.06),
                  ],
                ),
              ),
            ),

            // ── Layer 3: Panel ikon solid ───────────────────────────────
            Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.22),
                    blurRadius: 32,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(widget.icon, size: AppIconSize.large, color: c),
            ),

            // ── Chip orbit kiri-atas ────────────────────────────────────
            Positioned(
              top: 24,
              left: 18,
              child: _OrbitChip(color: c, offset: 0.0, animate: widget.animate),
            ),

            // ── Chip orbit kanan-tengah ─────────────────────────────────
            Positioned(
              right: 10,
              top: 90,
              child: _OrbitChip(color: c, offset: 0.4, animate: widget.animate),
            ),

            // ── Chip orbit bawah-kiri ───────────────────────────────────
            Positioned(
              bottom: 26,
              left: 32,
              child: _OrbitChip(color: c, offset: 0.75, animate: widget.animate),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip kecil mengambang dengan phase offset berbeda agar dinamis.
class _OrbitChip extends StatefulWidget {
  const _OrbitChip({
    required this.color,
    required this.offset,
    this.animate = true,
  });

  final Color color;
  final double offset;
  final bool animate;

  @override
  State<_OrbitChip> createState() => _OrbitChipState();
}

class _OrbitChipState extends State<_OrbitChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    final dur = Duration(milliseconds: (2200 + widget.offset * 800).toInt());
    _ctrl = AnimationController(vsync: this, duration: dur);
    _anim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, widget.animate ? _anim.value : 0),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide utama Onboarding
// ─────────────────────────────────────────────────────────────────────────────

/// Komponen satu slide onboarding dengan dukungan Animasi Lottie dan ilustrasi cadangan.
class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    super.key,
    required this.data,
    this.animateForever = true,
  });

  final OnboardingSlideData data;
  final bool animateForever;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = data.accentColor ?? AppColors.primary;

    // ── Ilustrasi / Animasi Lottie ──────────────────────────────────────
    Widget illustration;
    if (data.lottieAsset != null) {
      illustration = SizedBox(
        width: 250,
        height: 250,
        child: Lottie.asset(
          data.lottieAsset!,
          fit: BoxFit.contain,
          repeat: animateForever,
          errorBuilder: (_, __, ___) => _SlideIllustration(
            icon: data.icon,
            accentColor: accent,
            animate: animateForever,
          ),
        ),
      );
    } else {
      illustration = _SlideIllustration(
        icon: data.icon,
        accentColor: accent,
        animate: animateForever,
      );
    }

    // Animasi Entrance: muncul dari bawah + fade-in
    if (animateForever) {
      illustration = illustration
          .animate()
          .fadeIn(duration: 700.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.25,
            end: 0.0,
            duration: 700.ms,
            curve: Curves.easeOutCubic,
          );
    }

    // ── Teks judul ──────────────────────────────────────────────────────
    final title = Text(
      data.title,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1A1A2E),
        height: 1.25,
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 200.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.3,
          end: 0.0,
          duration: 600.ms,
          delay: 200.ms,
          curve: Curves.easeOutCubic,
        );

    // ── Teks deskripsi ──────────────────────────────────────────────────
    final desc = Text(
      data.description,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: AppColors.muted,
        height: 1.6,
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 380.ms, curve: Curves.easeOut)
        .slideY(
          begin: 0.3,
          end: 0.0,
          duration: 600.ms,
          delay: 380.ms,
          curve: Curves.easeOutCubic,
        );

    // ── Accent bar bawah judul ──────────────────────────────────────────
    final accentBar = Container(
      width: 48,
      height: 4,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(2),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 300.ms)
        .scaleX(
          begin: 0.0,
          end: 1.0,
          duration: 500.ms,
          delay: 300.ms,
          curve: Curves.easeOutCubic,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          illustration,
          const Spacer(flex: 3),
          title,
          const SizedBox(height: AppSpacing.sm),
          accentBar,
          const SizedBox(height: AppSpacing.lg),
          desc,
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}
