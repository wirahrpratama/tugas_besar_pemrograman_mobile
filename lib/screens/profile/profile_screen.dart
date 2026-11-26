import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/auth_service.dart';
import '../../services/photo_store.dart';
import '../../services/report_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/validators.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/report_photo.dart';

enum _PhotoAction { camera, gallery, remove }

/// Halaman profil pengguna yang menyesuaikan informasi & statistik berdasarkan
/// peran aktif (Pelapor, Teknisi, atau Admin) serta mengikuti token desain sistem.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.uid,
    this.userName,
    this.showAppBar = true,
    this.pickImage,
  });

  final String uid;
  final String? userName;
  final bool showAppBar;
  final Future<File?> Function(ImageSource source)? pickImage;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;
  bool _syncingEmail = false;

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

  static IconData _roleBadgeIcon(AppUser user) {
    switch (user.role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.teknisi:
        return Icons.engineering_rounded;
      case UserRole.pelapor:
        switch (user.subRole) {
          case 'dosen':
            return Icons.cast_for_education_rounded;
          case 'staf':
            return Icons.badge_rounded;
          default:
            return Icons.school_rounded;
        }
    }
  }

  static String _chipLabel(AppUser user) {
    if (user.role == UserRole.pelapor && user.subRole.trim().isNotEmpty) {
      return _capitalize(user.subRole.trim());
    }
    return _roleLabels[user.role] ?? 'Pengguna';
  }

  static ({String total, String active, String done}) _metricLabels(
    UserRole role,
  ) {
    switch (role) {
      case UserRole.admin:
        return (total: 'Total Tiket', active: 'Antrean', done: 'Selesai');
      case UserRole.teknisi:
        return (total: 'Total Tugas', active: 'Dikerjakan', done: 'Selesai');
      case UserRole.pelapor:
        return (total: 'Total Aduan', active: 'Diproses', done: 'Selesai');
    }
  }

  Stream<List<Report>> _watchUserReports(BuildContext context, AppUser user) {
    try {
      final repo = context.read<ReportRepository?>();
      if (repo == null) return const Stream.empty();
      switch (user.role) {
        case UserRole.admin:
          return repo.watchReportsForAdmin();
        case UserRole.teknisi:
          return repo.watchReportsForTeknisi(user.uid);
        case UserRole.pelapor:
          return repo.watchReportsForReporter(user.uid);
      }
    } catch (_) {
      return const Stream.empty();
    }
  }

  PhotoStore _resolvePhotoStore() {
    try {
      return context.read<PhotoStore>();
    } on ProviderNotFoundException {
      return FirestorePhotoStore.shared;
    }
  }

  Future<File?> _pickImageFile(ImageSource source) async {
    if (widget.pickImage != null) {
      return widget.pickImage!(source);
    }
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 100,
    );
    return picked == null ? null : File(picked.path);
  }

  void _showSnack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editFotoProfil(AppUser user) async {
    if (_uploadingPhoto) return;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.trim().isNotEmpty;

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(sheetContext, _PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Hapus foto profil',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(sheetContext, _PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final photoStore = _resolvePhotoStore();

    setState(() => _uploadingPhoto = true);
    try {
      if (action == _PhotoAction.remove) {
        await auth.updatePhotoUrl(widget.uid, null);
        _showSnack(messenger, 'Foto profil berhasil dihapus.');
        return;
      }

      final source = action == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery;
      final file = await _pickImageFile(source);
      if (file == null || !mounted) return;

      final photoRef = await photoStore.uploadPhoto(file);
      await auth.updatePhotoUrl(widget.uid, photoRef);
      _showSnack(messenger, 'Foto profil berhasil diperbarui.');
    } on AuthException catch (e) {
      _showSnack(messenger, e.message);
    } catch (_) {
      _showSnack(
        messenger,
        'Gagal memperbarui foto profil. Silakan coba lagi.',
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editNama(AppUser user) async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final newNama = await showDialog<String>(
      context: context,
      builder: (_) => _EditNamaDialog(initialNama: user.nama),
    );
    if (newNama == null || newNama.trim() == user.nama) return;
    try {
      await auth.updateNama(widget.uid, newNama);
      _showSnack(messenger, 'Nama berhasil diperbarui.');
    } on AuthException catch (e) {
      _showSnack(messenger, e.message);
    }
  }

  Future<void> _editEmail(AppUser user) async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<({String email, String password})>(
      context: context,
      builder: (_) => _EditEmailDialog(currentEmail: user.email),
    );
    if (result == null) return;
    try {
      await auth.requestEmailChange(
        uid: widget.uid,
        newEmail: result.email,
        currentPassword: result.password,
      );
      _showSnack(
        messenger,
        'Tautan verifikasi dikirim ke ${result.email}. '
        'Buka tautan tersebut untuk menyelesaikan perubahan email.',
      );
    } on AuthException catch (e) {
      _showSnack(messenger, e.message);
    }
  }

  Future<void> _syncEmailVerification() async {
    if (_syncingEmail) return;
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _syncingEmail = true);
    try {
      final updated = await auth.syncEmailChange(widget.uid);
      if (!mounted) return;
      _showSnack(
        messenger,
        updated
            ? 'Email berhasil diperbarui.'
            : 'Email baru belum terverifikasi. Buka tautan di kotak masuk email baru Anda.',
      );
    } on AuthException catch (e) {
      _showSnack(messenger, e.message);
    } finally {
      if (mounted) setState(() => _syncingEmail = false);
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

  Widget _buildStatusState(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Keluar dari Akun'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return StreamBuilder<AppUser?>(
      stream: auth.watchAppUser(widget.uid),
      builder: (context, snap) {
        final user = snap.data;
        final resolvedName = user?.nama ?? widget.userName;

        Widget body;
        if (snap.hasError) {
          body = _buildStatusState(
            context,
            icon: Icons.cloud_off_rounded,
            iconColor: AppColors.danger,
            title: 'Gagal memuat profil',
            subtitle: 'Periksa koneksi internet Anda lalu coba lagi.',
          );
        } else if (user == null) {
          if (snap.connectionState == ConnectionState.waiting) {
            body = const Center(child: CircularProgressIndicator());
          } else {
            body = _buildStatusState(
              context,
              icon: Icons.person_off_outlined,
              iconColor: AppColors.muted,
              title: 'Profil tidak ditemukan',
              subtitle: 'Silakan masuk ulang atau hubungi admin fasilitas.',
            );
          }
        } else {
          body = StreamBuilder<List<Report>>(
            stream: _watchUserReports(context, user),
            builder: (context, reportSnap) {
              final theme = Theme.of(context);
              final identityLabel = user.role == UserRole.pelapor
                  ? (user.subRole == 'mahasiswa'
                        ? 'Nomor Induk Mahasiswa (NIM)'
                        : 'Nomor Induk Pegawai (NIP)')
                  : 'NIP / ID Pegawai';
              final metrics = _metricLabels(user.role);
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
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x080F172A),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _ProfileAvatar(
                          user: user,
                          initials: _getInitials(user.nama),
                          badgeIcon: _roleBadgeIcon(user),
                          uploading: _uploadingPhoto,
                          onTap: () => _editFotoProfil(user),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          user.nama,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.highlight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.highlightBorder,
                            ),
                          ),
                          child: Text(
                            _chipLabel(user),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // 2. Kartu Ringkasan Aktivitas (Sesuai Peran)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.receipt_long_rounded,
                            iconColor: AppColors.primary,
                            nilai: '$totalReports',
                            label: metrics.total,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.pending_actions_rounded,
                            iconColor: AppColors.warning,
                            nilai: '$inProgressCount',
                            label: metrics.active,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _MetricColumn(
                            icon: Icons.task_alt_rounded,
                            iconColor: AppColors.success,
                            nilai: '$resolvedCount',
                            label: metrics.done,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 3. Section INFORMASI AKUN
                  const _ProfileSectionHeader(
                    icon: Icons.person_outline_rounded,
                    title: 'INFORMASI AKUN',
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Nama Lengkap',
                          value: user.nama,
                          action: TextButton(
                            onPressed: () => _editNama(user),
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
                        const Divider(height: 1),
                        _ProfileInfoRow(
                          icon: Icons.credit_card_rounded,
                          label: identityLabel,
                          value: user.identityNumber.isEmpty
                              ? '-'
                              : user.identityNumber,
                        ),
                        const Divider(height: 1),
                        _ProfileInfoRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          value: user.email,
                          action: TextButton(
                            onPressed: () => _editEmail(user),
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
                        if (user.pendingEmail != null &&
                            user.pendingEmail!.toLowerCase() !=
                                user.email.toLowerCase())
                          _PendingEmailNotice(
                            pendingEmail: user.pendingEmail!,
                            syncing: _syncingEmail,
                            onCheckStatus: _syncEmailVerification,
                          ),
                        const Divider(height: 1),
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

                  // 4. Section BANTUAN & INFORMASI
                  const _ProfileSectionHeader(
                    icon: Icons.help_outline_rounded,
                    title: 'BANTUAN & INFORMASI',
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _ProfileNavRow(
                          icon: Icons.menu_book_rounded,
                          label: 'Panduan Pelaporan Fasilitas',
                          onTap: () => _showPanduanDialog(context),
                        ),
                        const Divider(height: 1),
                        _ProfileNavRow(
                          icon: Icons.headset_mic_rounded,
                          label: 'Layanan Pengaduan Sarana Prasarana',
                          onTap: () => _showHelpdeskDialog(context),
                        ),
                        const Divider(height: 1),
                        _ProfileNavRow(
                          icon: Icons.info_outline_rounded,
                          label: 'Tentang Aplikasi SiFasilitas',
                          onTap: () => _showTentangDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // 5. Tombol Keluar dari Akun
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
        }

        final showSubBack =
            widget.showAppBar && (ModalRoute.of(context)?.canPop ?? false);

        return Scaffold(
          backgroundColor: AppColors.surfaceVariant,
          appBar: widget.showAppBar
              ? AppTopBar(
                  title: 'Profil Akun',
                  profileUid: widget.uid,
                  userName: resolvedName,
                  photoUrl: user?.photoUrl,
                  isProfileActive: true,
                )
              : null,
          body: showSubBack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppBackButton(),
                      ),
                    ),
                    Expanded(child: body),
                  ],
                )
              : body,
        );
      },
    );
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  const _ProfileSectionHeader({
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
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
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
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(height: 6),
        Text(
          nilai,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
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
            child: Icon(icon, size: 20, color: AppColors.primary),
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
                    color: AppColors.ink,
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
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.user,
    required this.initials,
    required this.badgeIcon,
    required this.uploading,
    required this.onTap,
  });

  final AppUser user;
  final String initials;
  final IconData badgeIcon;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedPhoto = user.photoUrl?.trim();
    final hasPhoto = trimmedPhoto != null && trimmedPhoto.isNotEmpty;

    final initialsWidget = Text(
      initials,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w700,
      ),
    );

    return Tooltip(
      message: 'Ubah foto profil',
      child: Semantics(
        button: true,
        label: 'Ubah foto profil',
        child: GestureDetector(
          onTap: uploading ? null : onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.highlightBorder,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhoto)
                        ReportPhoto(
                          ref: trimmedPhoto,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorWidget: Center(child: initialsWidget),
                        )
                      else
                        Center(child: initialsWidget),
                      if (uploading)
                        const ColoredBox(
                          color: Color(0x660F172A),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Icon(badgeIcon, size: 13, color: AppColors.surface),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingEmailNotice extends StatelessWidget {
  const _PendingEmailNotice({
    required this.pendingEmail,
    required this.syncing,
    required this.onCheckStatus,
  });

  final String pendingEmail;
  final bool syncing;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Menunggu verifikasi ke $pendingEmail',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: syncing ? null : onCheckStatus,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: syncing
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cek Status'),
          ),
        ],
      ),
    );
  }
}

class _EditEmailDialog extends StatefulWidget {
  const _EditEmailDialog({required this.currentEmail});

  final String currentEmail;

  @override
  State<_EditEmailDialog> createState() => _EditEmailDialogState();
}

class _EditEmailDialogState extends State<_EditEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop((
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Ubah Email'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Email saat ini: ${widget.currentEmail}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email Baru',
                  hintText: 'nama@email.com',
                ),
                validator: (value) {
                  final formatError = Validators.email(value);
                  if (formatError != null) return formatError;
                  if (value!.trim().toLowerCase() ==
                      widget.currentEmail.trim().toLowerCase()) {
                    return 'Email baru harus berbeda dari email saat ini.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Password Saat Ini',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Tampilkan password'
                        : 'Sembunyikan password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => Validators.required(v, 'Password saat ini'),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Tautan verifikasi akan dikirim ke email baru untuk konfirmasi.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
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
