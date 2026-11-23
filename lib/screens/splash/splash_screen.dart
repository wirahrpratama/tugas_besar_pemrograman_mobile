import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icon_size.dart';
import '../../theme/app_spacing.dart';
import '../../utils/storage_keys.dart';
import '../auth_gate.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.autoNavigate = true,
    this.destinationBuilder,
    this.animate = true,
  });

  final bool autoNavigate;
  final Widget Function(BuildContext context, bool isOnboardingCompleted)?
      destinationBuilder;
  final bool animate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const int _circleExpandDur = 750;  // Lingkaran hijau mengembang hingga memenuhi layar
  static const int _circleHoldDur   = 150;  // Jeda sesaat layar hijau penuh
  static const int _circleFadeDur   = 400;  // Layar hijau fade-out ke background putih

  static const int _logoDelay       = 1250; // Logo mulai turun dari atas
  static const int _logoDur         = 600;  // Durasi logo turun

  static const int _textDelay       = 1750; // Teks mulai masuk dari kanan
  static const int _textDur         = 500;  // Durasi teks masuk

  static const int _holdDur         = 850;  // Jeda tampilan lengkap
  static const int _fadeOutDur      = 400;  // Fade-out seluruh brand
  static const int _totalAnim       = _textDelay + _textDur + _holdDur;

  bool _fadeOut = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    if (widget.animate && widget.autoNavigate) {
      Future.delayed(_totalAnim.ms, () {
        if (!mounted) return;
        setState(() => _fadeOut = true);
      });
      Future.delayed((_totalAnim + _fadeOutDur).ms, _navigate);
    } else if (widget.autoNavigate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigate();
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _navigate() async {
    final completed = await StorageKeys.isOnboardingCompleted();
    if (!mounted) return;

    final Widget destination;
    if (widget.destinationBuilder != null) {
      destination = widget.destinationBuilder!(context, completed);
    } else if (completed) {
      destination = const AuthGate();
    } else {
      destination = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── 1. Lingkaran Hijau Pembuka (Mengembang hingga memenuhi layar) ──
    Widget? greenCircle;
    if (widget.animate) {
      greenCircle = Container(
        width: 240,
        height: 240,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.0, 0.0),
            end: const Offset(7.5, 7.5), // Skala 7.5x (1800px) menutup seluruh layar
            duration: _circleExpandDur.ms,
            curve: Curves.easeInOutCubic,
          )
          .then(delay: _circleHoldDur.ms)
          .fadeOut(
            duration: _circleFadeDur.ms,
            curve: Curves.easeOut,
          );
    }

    // ── 2. Logo dari Assets (Masuk dari ATAS, warna asli di background putih) ──
    Widget logoImg = Image.asset(
      'assets/images/Sifasilitas.png',
      width: AppIconSize.splashLogo,
      height: AppIconSize.splashLogo,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: AppIconSize.splashLogo,
        height: AppIconSize.splashLogo,
        decoration: const BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.apartment_rounded,
          size: AppIconSize.large,
          color: AppColors.primary,
        ),
      ),
    );

    if (widget.animate) {
      logoImg = logoImg
          .animate(delay: _logoDelay.ms)
          .slideY(
            begin: -1.8, // Masuk meluncur dari ATAS
            end: 0.0,
            duration: _logoDur.ms,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(duration: 400.ms, curve: Curves.easeOut);
    }

    // ── 3. Teks "SiFasilitas" Warna Hijau Desain Sistem (Masuk dari KANAN) ──
    Widget brandText = Text(
      'SiFasilitas',
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppColors.primary, // Warna hijau dari desain sistem
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
    );

    if (widget.animate) {
      brandText = brandText
          .animate(delay: _textDelay.ms)
          .slideX(
            begin: 0.6, // Masuk meluncur dari KANAN
            end: 0.0,
            duration: _textDur.ms,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(duration: _textDur.ms, curve: Curves.easeOut);
    }

    // ── Konten Brand (Logo di atas, Teks di bawah) ─────────────────────
    Widget brand = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoImg,
        const SizedBox(height: AppSpacing.lg),
        brandText,
      ],
    );

    if (widget.animate) {
      brand = AnimatedOpacity(
        duration: _fadeOutDur.ms,
        curve: Curves.easeIn,
        opacity: _fadeOut ? 0.0 : 1.0,
        child: brand,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface, // Background putih sesuai desain sistem
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            // Lingkaran hijau pembuka yang mengembang memenuhi seluruh layar
            if (greenCircle != null) Center(child: greenCircle),
            // Logo dan teks brand
            Center(child: brand),
          ],
        ),
      ),
    );
  }
}
