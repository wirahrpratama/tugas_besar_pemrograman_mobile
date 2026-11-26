import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/storage_keys.dart';
import '../../widgets/app_button.dart';
import '../auth_gate.dart';

/// Data model untuk satu slide onboarding.
class OnboardingSlideData {
  const OnboardingSlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
}

/// Halaman onboarding 3 slide dengan komposisi geometris modern yang tetap
/// mengikuti seluruh token desain sistem SiFasilitas.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.onCompleted,
    this.slides,
    this.animateForever = true,
  });

  final VoidCallback? onCompleted;
  final List<OnboardingSlideData>? slides;
  final bool animateForever;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentIndex = 0;

  List<OnboardingSlideData> get _slides =>
      widget.slides ??
      const [
        OnboardingSlideData(
          title: 'Lapor Kerusakan',
          description:
              'Scan QR lokasi, ambil foto, dan buat laporan kerusakan fasilitas kampus dengan mudah.',
          icon: Icons.qr_code_scanner_rounded,
          accentColor: AppColors.primary,
        ),
        OnboardingSlideData(
          title: 'Pantau Perbaikan',
          description:
              'Lacak status laporan secara real-time dari dilaporkan hingga selesai diperbaiki.',
          icon: Icons.track_changes_rounded,
          accentColor: AppColors.secondary,
        ),
        OnboardingSlideData(
          title: 'Login Sesuai Peran',
          description:
              'Masuk sebagai Pelapor, Admin, atau Teknisi untuk akses fitur yang sesuai dengan tugas Anda.',
          icon: Icons.group_outlined,
          accentColor: AppColors.primaryDark,
        ),
      ];

  Future<void> _markCompleted() async {
    await StorageKeys.setOnboardingCompleted(true);
  }

  void _next() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    _finish();
  }

  Future<void> _finish() async {
    await _markCompleted();
    if (!mounted) return;
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _slides.length - 1;
    final activeColor = _slides[_currentIndex].accentColor;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: Stack(
        children: [
          // ── Elemen Geometris Atas (mengikuti komposisi referensi) ──
          Positioned(
            top: -55,
            left: -45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 24,
            right: 95,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: -45,
            child: Container(
              width: 125,
              height: 125,
              decoration: const BoxDecoration(
                color: AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Animasi Teknisi Ujung ke Ujung di Bagian Bawah ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: _AnimatedTeknisiFooter(
                accentColor: activeColor,
                animate: widget.animateForever,
              ),
            ),
          ),

          // ── Konten Utama: Posisi di Tengah-Tengah Layar ──
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 92),
                const Spacer(flex: 3),
                _buildCenterContent(isLast: isLast, activeColor: activeColor),
                const Spacer(flex: 2),
                const SizedBox(height: 165),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterContent({
    required bool isLast,
    required Color activeColor,
  }) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              return _OnboardingSlideContent(data: _slides[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indikator slide rata kiri
              Row(
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    height: 6,
                    width: _currentIndex == index ? 22 : 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? activeColor
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: isLast ? 'Mulai' : 'Lanjut',
                variant: AppButtonVariant.primary,
                onPressed: _next,
              ),
              if (!isLast) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Lewati',
                  variant: AppButtonVariant.outline,
                  onPressed: _skip,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (widget.animateForever) {
      content = content
          .animate()
          .fadeIn(duration: 350.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.05,
            end: 0,
            duration: 350.ms,
            curve: Curves.easeOutCubic,
          );
    }

    return content;
  }
}

class _OnboardingSlideContent extends StatelessWidget {
  const _OnboardingSlideContent({required this.data});

  final OnboardingSlideData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            textAlign: TextAlign.left,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.description,
            textAlign: TextAlign.left,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustrasi animasi teknisi kampus dari ujung kiri ke ujung kanan di bagian
/// bawah layar, proporsional tanpa memenuhi seluruh layar.
class _AnimatedTeknisiFooter extends StatelessWidget {
  const _AnimatedTeknisiFooter({
    required this.accentColor,
    required this.animate,
  });

  final Color accentColor;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    Widget leftGear = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.settings_rounded,
        size: 32,
        color: AppColors.surface,
      ),
    );
    if (animate) {
      leftGear = leftGear
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 6000.ms, curve: Curves.linear);
    }

    Widget rightGear = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.settings_rounded,
        size: 26,
        color: AppColors.primaryContainer,
      ),
    );
    if (animate) {
      rightGear = rightGear
          .animate(onPlay: (c) => c.repeat())
          .rotate(begin: 1, end: 0, duration: 5000.ms, curve: Curves.linear);
    }

    Widget wrench = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      child: const Icon(
        Icons.build_rounded,
        size: 20,
        color: AppColors.primaryDark,
      ),
    );
    if (animate) {
      wrench = wrench
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .rotate(
            begin: -0.08,
            end: 0.08,
            duration: 900.ms,
            curve: Curves.easeInOut,
          )
          .slideY(begin: 0.06, end: -0.06, duration: 900.ms);
    }

    Widget technicianCharacter = const _TeknisiCharacter();
    if (animate) {
      technicianCharacter = technicianCharacter
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .slideY(
            begin: 0.03,
            end: -0.02,
            duration: 1600.ms,
            curve: Curves.easeInOut,
          );
    }

    return SizedBox(
      width: double.infinity,
      height: 165,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Lengkung dasar dari ujung kiri ke ujung kanan
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: double.infinity,
              height: 122,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.elliptical(screenWidth * 0.9, 80),
                ),
              ),
            ),
          ),
          // Garis aksen halus di tepi lengkung
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              height: 22,
              color: AppColors.primaryDark.withValues(alpha: 0.22),
            ),
          ),
          // Elemen sisi kiri (gir berputar)
          Positioned(
            left: 24,
            bottom: 36,
            child: leftGear,
          ),
          // Elemen sisi kanan (gir berputar)
          Positioned(
            right: 24,
            bottom: 36,
            child: rightGear,
          ),
          // Karakter teknisi di tengah dengan kunci pas bergerak
          Positioned(
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                technicianCharacter,
                Positioned(
                  right: -28,
                  bottom: 34,
                  child: wrench,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeknisiCharacter extends StatelessWidget {
  const _TeknisiCharacter();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Bahu & seragam teknisi
          Positioned(
            bottom: 0,
            child: Container(
              width: 136,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.vertical(top: Radius.circular(42)),
              ),
              child: Center(
                child: Container(
                  width: 34,
                  height: 18,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          // Wajah teknisi
          Positioned(
            bottom: 36,
            child: Container(
              width: 82,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: AppColors.ink, width: 2.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 14),
                  // Sepasang mata
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 22),
                      Container(
                        width: 10,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Senyum ramah
                  Container(
                    width: 22,
                    height: 10,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.ink, width: 2.5),
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Helm keselamatan teknisi (kuning/amber aksen)
          Positioned(
            top: 8,
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(46),
                    ),
                    border: Border.all(color: AppColors.ink, width: 2.5),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 24,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
                // Visor helm
                Container(
                  width: 104,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.ink, width: 2.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
