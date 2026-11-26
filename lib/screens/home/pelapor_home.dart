import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/pelapor_bottom_nav_bar.dart';
import '../profile/profile_screen.dart';
import '../report/scan_qr_screen.dart';

/// Halaman utama peran Pelapor dengan navigasi bawah (bottom navbar) interaktif
/// dan beranda yang ringkas, informatif, serta selaras dengan desain sistem.
class PelaporHome extends StatefulWidget {
  const PelaporHome({
    super.key,
    required this.user,
    this.initialTab = PelaporTab.beranda,
  });

  final AppUser user;
  final PelaporTab initialTab;

  @override
  State<PelaporHome> createState() => _PelaporHomeState();
}

class _PelaporHomeState extends State<PelaporHome> {
  late PelaporTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
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

  void _onTabTapped(int index) {
    final selectedTab = PelaporTab.values[index];
    if (selectedTab == PelaporTab.pindai) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ScanQrScreen(user: widget.user),
        ),
      );
      return;
    }
    setState(() => _currentTab = selectedTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppTopBar(
        title: _currentTab == PelaporTab.beranda
            ? 'Beranda Pelapor'
            : _currentTab.label,
        profileUid: widget.user.uid,
        userName: widget.user.nama,
        photoUrl: widget.user.photoUrl,
        isProfileActive: _currentTab == PelaporTab.profil,
      ),
      body: _buildBody(),
      bottomNavigationBar: PelaporBottomNavBar(
        currentIndex: _currentTab.index,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentTab) {
      case PelaporTab.beranda:
        return _buildBeranda();
      case PelaporTab.riwayat:
        return _buildRiwayat();
      case PelaporTab.pindai:
        return _buildBeranda();
      case PelaporTab.profil:
        return ProfileScreen(
          uid: widget.user.uid,
          userName: widget.user.nama,
          showAppBar: false,
        );
    }
  }

  Widget _buildBeranda() {
    final user = widget.user;

    return StreamBuilder<List<Report>>(
      stream: _watchUserReports(context, user.uid),
      builder: (context, snapshot) {
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        final reports = snapshot.data ?? const <Report>[];
        final activeReports = reports.where((r) {
          return r.status != ReportStatus.resolved &&
              r.status != ReportStatus.rejected;
        }).toList();
        final resolvedCount = reports
            .where((r) => r.status == ReportStatus.resolved)
            .length;

        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          children: [
            // 1. Kartu Sapaan & Ringkasan Aktivitas Pelapor
            _PelaporHeaderCard(
              user: user,
              isLoading: isLoading,
              activeCount: activeReports.length,
              resolvedCount: resolvedCount,
              totalCount: reports.length,
            ),

            const SizedBox(height: AppSpacing.lg),

            // 2. Banner Utama Hero: Laporkan Kerusakan Fasilitas
            _BuatLaporanCard(user: user),

            const SizedBox(height: AppSpacing.xl),

            // 3. Status Aduan Aktif (Live Tracker)
            _SectionHeader(
              icon: Icons.pending_actions_rounded,
              title: 'STATUS ADUAN AKTIF',
              trailing: reports.isNotEmpty
                  ? TextButton(
                      onPressed: () =>
                          setState(() => _currentTab = PelaporTab.riwayat),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Lihat riwayat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
            _ActiveReportSection(
              isLoading: isLoading,
              hasError: snapshot.hasError,
              activeReports: activeReports,
              onViewHistory: () =>
                  setState(() => _currentTab = PelaporTab.riwayat),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 4. Kategori & Standar Layanan (SLA) — Terpadu tanpa duplikasi
            const _SectionHeader(
              icon: Icons.category_outlined,
              title: 'KATEGORI & TARGET LAYANAN',
            ),
            _FacilityCategoryGrid(
              onCategoryTap: (cat) => _handleCategoryTap(context, cat),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 5. Alur Penanganan Laporan (3 Langkah)
            const _SectionHeader(
              icon: Icons.route_outlined,
              title: 'ALUR PENANGANAN LAPORAN',
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  _StepRow(
                    nomor: '1',
                    icon: Icons.qr_code_scanner_rounded,
                    accentColor: AppColors.primary,
                    accentBg: AppColors.primaryContainer,
                    judul: 'Pindai Kode QR Ruangan',
                    deskripsi:
                        'Arahkan kamera ke stiker QR yang menempel di pintu atau meja fasilitas.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _StepRow(
                    nomor: '2',
                    icon: Icons.auto_awesome_rounded,
                    accentColor: AppColors.secondary,
                    accentBg: AppColors.secondaryContainer,
                    judul: 'Foto Kerusakan & Analisis AI',
                    deskripsi:
                        'Sistem AI otomatis mendeteksi kategori dan tingkat urgensi penanganan.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _StepRow(
                    nomor: '3',
                    icon: Icons.engineering_rounded,
                    accentColor: AppColors.info,
                    accentBg: AppColors.infoContainer,
                    judul: 'Penanganan & Hasil Perbaikan',
                    deskripsi:
                        'Teknisi diterjunkan ke lokasi dan melampirkan foto hasil perbaikan.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        );
      },
    );
  }

  void _handleCategoryTap(
    BuildContext context,
    _FacilityCategoryData category,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(category.icon, color: AppColors.surface, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${category.label} (Prioritas ${category.prioritas}, target SLA ${category.sla}). Pindai QR ruangan untuk melapor.',
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Pindai',
          textColor: AppColors.accentContainer,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ScanQrScreen(user: widget.user),
              ),
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildRiwayat() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Riwayat Laporan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Daftar tiket dan status perbaikan fasilitas yang Anda laporkan akan tampil di sini.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header & Ringkasan Pelapor ───────────────────────────────────────────────

class _PelaporHeaderCard extends StatelessWidget {
  const _PelaporHeaderCard({
    required this.user,
    required this.isLoading,
    required this.activeCount,
    required this.resolvedCount,
    required this.totalCount,
  });

  final AppUser user;
  final bool isLoading;
  final int activeCount;
  final int resolvedCount;
  final int totalCount;

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static IconData _subRoleIcon(String subRole) {
    switch (subRole) {
      case 'dosen':
        return Icons.cast_for_education_outlined;
      case 'staf':
        return Icons.badge_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  String _subtitleText() {
    if (user.identityNumber.isEmpty) {
      return 'Layanan Pelaporan Kampus';
    }
    final prefix = user.subRole == 'mahasiswa' ? 'NIM' : 'NIP';
    return '$prefix ${user.identityNumber}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, ${user.nama}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitleText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.highlight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.highlightBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _subRoleIcon(user.subRole),
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _capitalize(user.subRole),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _HeaderStatItem(
                  label: 'Aktif',
                  value: isLoading ? '-' : '$activeCount',
                  valueColor:
                      activeCount > 0 ? AppColors.warning : AppColors.primary,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                child: _HeaderStatItem(
                  label: 'Selesai',
                  value: isLoading ? '-' : '$resolvedCount',
                  valueColor: AppColors.success,
                ),
              ),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(
                child: _HeaderStatItem(
                  label: 'Total',
                  value: isLoading ? '-' : '$totalCount',
                  valueColor: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStatItem extends StatelessWidget {
  const _HeaderStatItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Section Header Reusable ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Status Aduan Aktif Section ───────────────────────────────────────────────

class _ActiveReportSection extends StatelessWidget {
  const _ActiveReportSection({
    required this.isLoading,
    required this.hasError,
    required this.activeReports,
    required this.onViewHistory,
  });

  final bool isLoading;
  final bool hasError;
  final List<Report> activeReports;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Memuat status aduan aktif…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dangerContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.danger,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Gagal memuat aduan aktif. Periksa koneksi internet Anda.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (activeReports.isNotEmpty) {
      return _ActiveReportSummaryCard(
        report: activeReports.first,
        totalActive: activeReports.length,
        onViewMore: activeReports.length > 1 ? onViewHistory : null,
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.highlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.highlightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.highlightBorder),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semua Fasilitas Terpantau Aman',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tidak ada aduan aktif saat ini. Laporkan segera bila menemukan kerusakan.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
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

/// Kartu aksi utama dengan banner gradien hijau kampus dan ilustrasi ikon QR.
class _BuatLaporanCard extends StatelessWidget {
  const _BuatLaporanCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              Icons.qr_code_2_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Aduan Cepat & Responsif',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Ada Fasilitas Rusak?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pindai kode QR pada ruangan untuk membuat laporan perbaikan secara instan.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppColors.primaryDark,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScanQrScreen(user: user),
                    ),
                  ),
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: AppColors.primaryDark,
                  ),
                  label: const Text(
                    'Pindai QR ruangan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.primaryDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

// ── Kategori & Standar Layanan Terpadu ───────────────────────────────────────

class _FacilityCategoryData {
  const _FacilityCategoryData({
    required this.icon,
    required this.label,
    required this.sla,
    required this.prioritas,
    required this.iconBg,
    required this.iconColor,
    required this.priorityBg,
    required this.priorityColor,
  });

  final IconData icon;
  final String label;
  final String sla;
  final String prioritas;
  final Color iconBg;
  final Color iconColor;
  final Color priorityBg;
  final Color priorityColor;
}

const List<_FacilityCategoryData> _facilityCategories = [
  _FacilityCategoryData(
    icon: Icons.bolt_rounded,
    label: 'Kelistrikan',
    sla: '2 Jam',
    prioritas: 'Darurat',
    iconBg: AppColors.warningContainer,
    iconColor: AppColors.warning,
    priorityBg: AppColors.dangerContainer,
    priorityColor: AppColors.danger,
  ),
  _FacilityCategoryData(
    icon: Icons.ac_unit_rounded,
    label: 'AC / Ruangan',
    sla: '6 Jam',
    prioritas: 'Tinggi',
    iconBg: AppColors.secondaryContainer,
    iconColor: AppColors.secondary,
    priorityBg: AppColors.warningContainer,
    priorityColor: AppColors.warning,
  ),
  _FacilityCategoryData(
    icon: Icons.videocam_rounded,
    label: 'Proyektor',
    sla: '4 Jam',
    prioritas: 'Tinggi',
    iconBg: AppColors.infoContainer,
    iconColor: AppColors.info,
    priorityBg: AppColors.warningContainer,
    priorityColor: AppColors.warning,
  ),
  _FacilityCategoryData(
    icon: Icons.wifi_rounded,
    label: 'Wi-Fi & Net',
    sla: '4 Jam',
    prioritas: 'Tinggi',
    iconBg: AppColors.primaryContainer,
    iconColor: AppColors.primary,
    priorityBg: AppColors.warningContainer,
    priorityColor: AppColors.warning,
  ),
  _FacilityCategoryData(
    icon: Icons.water_drop_rounded,
    label: 'Sanitasi & Air',
    sla: '8 Jam',
    prioritas: 'Sedang',
    iconBg: AppColors.infoContainer,
    iconColor: AppColors.info,
    priorityBg: AppColors.infoContainer,
    priorityColor: AppColors.info,
  ),
  _FacilityCategoryData(
    icon: Icons.chair_alt_rounded,
    label: 'Mebel Kelas',
    sla: '24 Jam',
    prioritas: 'Rendah',
    iconBg: AppColors.surfaceVariant,
    iconColor: AppColors.muted,
    priorityBg: AppColors.surfaceVariant,
    priorityColor: AppColors.muted,
  ),
];

class _FacilityCategoryGrid extends StatelessWidget {
  const _FacilityCategoryGrid({required this.onCategoryTap});

  final ValueChanged<_FacilityCategoryData> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CategoryQuickItem(
                    data: _facilityCategories[i],
                    onTap: () => onCategoryTap(_facilityCategories[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (int i = 3; i < 6; i++) ...[
                if (i > 3) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CategoryQuickItem(
                    data: _facilityCategories[i],
                    onTap: () => onCategoryTap(_facilityCategories[i]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Item tombol kategori fasilitas cepat lengkap dengan badge target SLA.
class _CategoryQuickItem extends StatelessWidget {
  const _CategoryQuickItem({
    required this.data,
    required this.onTap,
  });

  final _FacilityCategoryData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data.icon,
                color: data.iconColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: data.priorityBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SLA ${data.sla}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: data.priorityColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Kartu Ringkasan Tiket Aktif dengan Status Semantik ───────────────────────

class _StatusBadgeStyle {
  const _StatusBadgeStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  factory _StatusBadgeStyle.fromStatus(ReportStatus status) {
    switch (status) {
      case ReportStatus.reported:
        return const _StatusBadgeStyle(
          label: 'Menunggu Verifikasi',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
          bgColor: AppColors.warningContainer,
        );
      case ReportStatus.verified:
        return const _StatusBadgeStyle(
          label: 'Terverifikasi',
          icon: Icons.verified_outlined,
          color: AppColors.info,
          bgColor: AppColors.infoContainer,
        );
      case ReportStatus.assigned:
        return const _StatusBadgeStyle(
          label: 'Teknisi Ditugaskan',
          icon: Icons.engineering_outlined,
          color: AppColors.secondary,
          bgColor: AppColors.secondaryContainer,
        );
      case ReportStatus.inProgress:
        return const _StatusBadgeStyle(
          label: 'Sedang Dikerjakan',
          icon: Icons.sync_rounded,
          color: AppColors.primary,
          bgColor: AppColors.primaryContainer,
        );
      case ReportStatus.resolved:
        return const _StatusBadgeStyle(
          label: 'Selesai',
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          bgColor: AppColors.successContainer,
        );
      case ReportStatus.rejected:
        return const _StatusBadgeStyle(
          label: 'Ditolak',
          icon: Icons.cancel_outlined,
          color: AppColors.danger,
          bgColor: AppColors.dangerContainer,
        );
    }
  }
}

/// Kartu ringkasan tiket aktif yang sedang berjalan dengan warna semantik status.
class _ActiveReportSummaryCard extends StatelessWidget {
  const _ActiveReportSummaryCard({
    required this.report,
    required this.totalActive,
    this.onViewMore,
  });

  final Report report;
  final int totalActive;
  final VoidCallback? onViewMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStyle = _StatusBadgeStyle.fromStatus(report.status);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusStyle.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusStyle.icon,
                  color: statusStyle.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.namaObjek.isNotEmpty
                          ? report.namaObjek
                          : 'Laporan Fasilitas',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (report.ticketNumber.isNotEmpty)
                      Text(
                        '#${report.ticketNumber}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusStyle.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusStyle.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${report.namaRuangan} (${report.namaGedung})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            report.deskripsi,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink),
          ),
          if (onViewMore != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: onViewMore,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '+${totalActive - 1} aduan aktif lainnya',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Baris langkah alur penanganan dengan ikon dan nomor penunjuk.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.nomor,
    required this.icon,
    required this.judul,
    required this.deskripsi,
    this.accentColor = AppColors.primary,
    this.accentBg = AppColors.primaryContainer,
  });

  final String nomor;
  final IconData icon;
  final String judul;
  final String deskripsi;
  final Color accentColor;
  final Color accentBg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 22,
              ),
            ),
            Positioned(
              top: -5,
              left: -5,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  nomor,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                deskripsi,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
