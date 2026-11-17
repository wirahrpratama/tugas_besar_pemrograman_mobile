import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/report_models.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'auth/verify_email_screen.dart';
import 'home/admin_dashboard.dart';
import 'home/pelapor_home.dart';
import 'home/teknisi_dashboard.dart';

/// Gerbang navigasi berbasis peran:
/// belum login -> Login; pelapor belum verifikasi email -> Verifikasi;
/// selain itu -> beranda sesuai `users/{uid}.role`.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: auth.userChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = authSnap.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<AppUser?>(
          stream: auth.watchAppUser(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.hasError) {
              return const _ProfileProblemScreen(
                message:
                    'Gagal memuat profil akun. Periksa koneksi internet lalu coba lagi.',
              );
            }
            if (!profileSnap.hasData &&
                profileSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            final profile = profileSnap.data;
            if (profile == null) {
              return const _ProfileProblemScreen(
                message:
                    'Profil akun tidak ditemukan. Hubungi admin fasilitas.',
              );
            }
            if (profile.role == UserRole.pelapor && !user.emailVerified) {
              return VerifyEmailScreen(email: user.email ?? profile.email);
            }
            switch (profile.role) {
              case UserRole.admin:
                return AdminDashboard(user: profile);
              case UserRole.teknisi:
                return TeknisiDashboard(user: profile);
              case UserRole.pelapor:
                return PelaporHome(user: profile);
            }
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ProfileProblemScreen extends StatelessWidget {
  const _ProfileProblemScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.read<AuthService>().signOut(),
                  child: const Text('Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
