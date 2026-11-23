import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../report/scan_qr_screen.dart';
import 'role_home_scaffold.dart';

class PelaporHome extends StatelessWidget {
  const PelaporHome({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      user: user,
      title: 'Beranda Pelapor',
      icon: Icons.report_outlined,
      placeholderText:
          'Fitur buat laporan (M2) dan riwayat laporan (M3) akan tampil di sini.',
      extraContent: [
        const SizedBox(height: 24),
        _BuatLaporanCard(user: user),
      ],
    );
  }
}

/// Pintu masuk alur buat laporan (M2, Aldrik).
class _BuatLaporanCard extends StatelessWidget {
  const _BuatLaporanCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ada fasilitas yang rusak?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Pindai QR Code di ruangan untuk membuat laporan.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ScanQrScreen(user: user)),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Pindai QR ruangan'),
            ),
          ],
        ),
      ),
    );
  }
}
