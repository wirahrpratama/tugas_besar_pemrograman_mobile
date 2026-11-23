import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/storage_keys.dart';
import '../../widgets/app_button.dart';
import '../auth_gate.dart';
import 'onboarding_slide.dart';

/// Halaman onboarding 3 slide dengan PageView, indikator, dan tombol Next/Skip.
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
          icon: Icons.report_problem_outlined,
          accentColor: AppColors.primary,
          lottieAsset: 'assets/animations/onboarding_1.json',
        ),
        OnboardingSlideData(
          title: 'Pantau Perbaikan',
          description:
              'Lacak status laporan secara real-time dari dilaporkan hingga selesai diperbaiki.',
          icon: Icons.track_changes_outlined,
          accentColor: AppColors.primary,
          lottieAsset: 'assets/animations/onboarding_2.json',
        ),
        OnboardingSlideData(
          title: 'Login Sesuai Peran',
          description:
              'Masuk sebagai Pelapor, Admin, atau Teknisi untuk akses fitur yang sesuai dengan tugas Anda.',
          icon: Icons.group_outlined,
          accentColor: AppColors.primary,
          lottieAsset: 'assets/animations/onboarding_3.json',
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  return OnboardingSlide(
                    data: _slides[index],
                    animateForever: widget.animateForever,
                  );
                },
              ),
            ),
            Padding(
              padding: AppSpacing.paddingAllXl,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.primary
                              : AppColors.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      if (!isLast)
                        Expanded(
                          child: AppButton(
                            label: 'Lewati',
                            variant: AppButtonVariant.text,
                            onPressed: _skip,
                          ),
                        ),
                      if (!isLast) const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: AppButton(
                          label: isLast ? 'Mulai' : 'Lanjut',
                          variant: AppButtonVariant.primary,
                          onPressed: _next,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
