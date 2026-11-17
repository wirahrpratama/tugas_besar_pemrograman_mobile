import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/loading_button.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _pollInterval = Duration(seconds: 5);
  static const _resendCooldownSeconds = 60;

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;
  bool _checking = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => _checkVerified(showFeedback: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified({required bool showFeedback}) async {
    if (_checking) return;
    setState(() => _checking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final verified = await context.read<AuthService>().refreshEmailVerified();
      if (verified) {
        _pollTimer?.cancel();
      } else if (showFeedback) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Email belum terverifikasi. Buka tautan di email Anda.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (showFeedback) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthService>().resendEmailVerification();
      messenger.showSnackBar(
        const SnackBar(content: Text('Email verifikasi sudah dikirim ulang.')),
      );
      if (mounted) _startCooldown();
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownLeft = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = !_sending && _cooldownLeft <= 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kami telah mengirim tautan verifikasi ke',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buka tautan tersebut, lalu kembali ke aplikasi. '
                    'Cek folder spam jika email tidak ada di kotak masuk.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    label: 'Saya Sudah Verifikasi',
                    loading: _checking,
                    onPressed: () => _checkVerified(showFeedback: true),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: canResend ? _resend : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      _cooldownLeft > 0
                          ? 'Kirim Ulang ($_cooldownLeft detik)'
                          : 'Kirim Ulang Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<AuthService>().signOut(),
                    child: const Text('Keluar / Ganti Akun'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
