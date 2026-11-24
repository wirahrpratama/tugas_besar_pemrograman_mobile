import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/auth_service.dart';
import '../../services/report_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/validators.dart';

/// Halaman profil pengguna yang dirancang profesional, terstruktur penuh,
/// dan minimalis (meminimalkan penggunaan ikon berlebihan).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.uid,
    this.showAppBar = true,
  });

  final String uid;
  final bool showAppBar;

  static const _roleLabels = {
    UserRole.pelapor: 'Pelapor Fasilitas',
    UserRole.admin: 'Admin Fasilitas',
    UserRole.teknisi: 'Teknisi Lapangan',
  };

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Stream<List<Report>> _watchUserReports(BuildContext context, String uid) {
    try {
      final repo = context.read<ReportRepository?>();
      if (repo == null) return const Stream.empty();
      return repo.watchReportsForReporter(uid);
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> _editNama(BuildContext context, AppUser user) async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final newNama = await showDialog<String>(
      context: context,
      builder: (_) => _EditNamaDialog(initialNama: user.nama),
    );
    if (newNama == null || newNama.trim() == user.nama) return;
    try {
      await auth.updateNama(uid, newNama);
      messenger.showSnackBar(
        const SnackBar(content: Text('Nama berhasil diperbarui.')),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthService>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.signOut();
  }

  void _showPanduanDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Panduan Pelaporan'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PanduanStep(
                nomor: '1',
                judul: 'Pindai Kode QR',
                deskripsi:
                    'Pindai stiker QR Code yang tertera pada pintu ruangan fasilitas.',
              ),
              _PanduanStep(
                nomor: '2',
                judul: 'Foto Bukti Kerusakan',
                deskripsi:
                    'Ambil foto kerusakan fisik fasilitas yang bermasalah secara jelas.',
              ),
              _PanduanStep(
                nomor: '3',
                judul: 'Analisis Otomatis AI',
                deskripsi:
                    'Sistem AI Gemini otomatis mendeteksi kategori dan tingkat urgensi penanganan.',
              ),
              _PanduanStep(
                nomor: '4',
                judul: 'Penugasan Teknisi',
                deskripsi:
                    'Admin memverifikasi laporan dan mendisposisikan ke teknisi bertugas.',
              ),
              _PanduanStep(
                nomor: '5',
                judul: 'Konfirmasi Penyelesaian',
                deskripsi:
                    'Teknisi mengunggah foto bukti perbaikan dan pelapor mengonfirmasi hasilnya.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _showHelpdeskDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Layanan Fasilitas Kampus'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Biro Pengelolaan Fasilitas & Prasarana',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: AppSpacing.xs),
            Text('Gedung Pusat Administrasi Lt. 2'),
            SizedBox(height: AppSpacing.sm),
            Text('Jam Operasional:'),
            Text('Senin – Jumat : 08.00 – 16.00 WIB'),
            SizedBox(height: AppSpacing.sm),
            Text('Email Resmi:'),
            Text(
              'sarpras@usu.ac.id',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showTentangDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tentang SiFasilitas'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SiFasilitas Kampus',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            SizedBox(height: AppSpacing.xs),
            Text('Versi 1.0.0 (Production Build)'),
            SizedBox(height: AppSpacing.md),
            Text(
              'Sistem terpadu pelaporan sarana prasarana kampus berbasis AI Gemini dan pemindai QR ruangan.',
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              'Dikembangkan untuk Tugas Besar Pemrograman Mobile.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: showAppBar
          ? AppBar(
              title: const Text('Profil Akun'),
              backgroundColor: AppColors.surface,
            )
          : null,
      body: StreamBuilder<AppUser?>(
        stream: auth.watchAppUser(uid),
        builder: (context, snap) {
          final user = snap.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final theme = Theme.of(context);
          final identityLabel = user.role == UserRole.pelapor
              ? (user.subRole == 'mahasiswa'
                  ? 'Nomor Induk Mahasiswa (NIM)'
                  : 'Nomor Induk Pegawai (NIP)')
              : 'NIP / ID Pegawai';

          return StreamBuilder<List<Report>>(
            stream: _watchUserReports(context, user.uid),
            builder: (context, reportSnap) {
              final reports = reportSnap.data ?? const <Report>[];
              final totalReports = reports.length;
              final inProgressCount = reports.where((r) {
                return r.status == ReportStatus.reported ||
                    r.status == ReportStatus.verified ||
                    r.status == ReportStatus.assigned ||
                    r.status == ReportStatus.inProgress;
              }).length;
              final resolvedCount = reports.where((r) {
                return r.status == ReportStatus.resolved;
              }).length;

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  // 1. Header Card Profil
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        // Avatar Inisial Elegan dengan Badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getInitials(user.nama),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.school_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Nama Pengguna
                        Text(
                          user.nama,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // Badge Status Mahasiswa / Sivitas
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _capitalize(user.subRole),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // 2. Kartu Ringkasan Aktivitas Aduan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.receipt_long_rounded,
                            iconColor: AppColors.primary,
                            nilai: '$totalReports',
                            label: 'Total Aduan',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: Colors.grey.shade200,
                        ),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.pending_actions_rounded,
                            iconColor: AppColors.warning,
                            nilai: '$inProgressCount',
                            label: 'Diproses',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: Colors.grey.shade200,
                        ),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.task_alt_rounded,
                            iconColor: AppColors.success,
                            nilai: '$resolvedCount',
                            label: 'Selesai',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 3. Section INFORMASI AKUN
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'INFORMASI AKUN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Nama Lengkap',
                          value: user.nama,
                          action: TextButton(
                            onPressed: () => _editNama(context, user),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            child: const Text('Ubah'),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _ProfileInfoRow(
                          icon: Icons.credit_card_rounded,
                          label: identityLabel,
                          value: user.identityNumber.isEmpty
                              ? '-'
                              : user.identityNumber,
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _ProfileInfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email Kampus',
                          value: user.email,
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _ProfileInfoRow(
                          icon: Icons.shield_outlined,
                          label: 'Peran Sistem',
                          value: user.role == UserRole.pelapor
                              ? '${_roleLabels[user.role]} (${_capitalize(user.subRole)})'
                              : _roleLabels[user.role]!,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 4. Section PUSAT BANTUAN & INFORMASI
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BANTUAN & INFORMASI',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _ProfileNavRow(
                          icon: Icons.menu_book_rounded,
                          label: 'Panduan Pelaporan Fasilitas',
                          onTap: () => _showPanduanDialog(context),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _ProfileNavRow(
                          icon: Icons.headset_mic_rounded,
                          label: 'Layanan Pengaduan Sarana Prasarana',
                          onTap: () => _showHelpdeskDialog(context),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _ProfileNavRow(
                          icon: Icons.info_outline_rounded,
                          label: 'Tentang Aplikasi SiFasilitas',
                          onTap: () => _showTentangDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 5. Tombol Keluar dari Akun (Clean Destructive Action)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Keluar dari Akun',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.35),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Kolom metrik statistik dengan ikon pendukung indikatif.
class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.icon,
    required this.iconColor,
    required this.nilai,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: iconColor,
        ),
        const SizedBox(height: 6),
        Text(
          nilai,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Baris informasi profil dengan ikon penunjuk kategori.
class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.action,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Baris navigasi menu bantuan dengan ikon representatif.
class _ProfileNavRow extends StatelessWidget {
  const _ProfileNavRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// Langkah-langkah dalam dialog panduan.
class _PanduanStep extends StatelessWidget {
  const _PanduanStep({
    required this.nomor,
    required this.judul,
    required this.deskripsi,
  });

  final String nomor;
  final String judul;
  final String deskripsi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              nomor,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  deskripsi,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditNamaDialog extends StatefulWidget {
  const _EditNamaDialog({required this.initialNama});

  final String initialNama;

  @override
  State<_EditNamaDialog> createState() => _EditNamaDialogState();
}

class _EditNamaDialogState extends State<_EditNamaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialNama);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Nama'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          validator: Validators.nama,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
