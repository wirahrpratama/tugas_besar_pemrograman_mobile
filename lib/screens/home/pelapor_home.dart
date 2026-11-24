import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/pelapor_bottom_nav_bar.dart';
import '../profile/profile_screen.dart';
import '../report/scan_qr_screen.dart';

/// Halaman utama peran Pelapor dengan navigasi bawah (bottom navbar) interaktif
/// dan tampilan beranda yang modern, informatif, serta dilengkapi ikon penunjang yang profesional.
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

  void _onTabTapped(int index) {
    final selectedTab = PelaporTab.values[index];
    if (selectedTab == PelaporTab.pindai) {
      // Membuka pemindai kamera QR ruangan
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
      appBar: AppBar(
        title: Text(_currentTab == PelaporTab.beranda
            ? 'Beranda Pelapor'
            : _currentTab.label),
        backgroundColor: AppColors.surface,
        actions: [
          if (_currentTab != PelaporTab.profil)
            IconButton(
              tooltip: 'Profil Akun',
              icon: const Icon(Icons.account_circle_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(uid: widget.user.uid),
                ),
              ),
            ),
        ],
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
          showAppBar: false,
        );
    }
  }

  Widget _buildBeranda() {
    final theme = Theme.of(context);
    final user = widget.user;

    return StreamBuilder<List<Report>>(
      stream: _watchUserReports(context, user.uid),
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <Report>[];
        final activeReports = reports.where((r) {
          return r.status != ReportStatus.resolved &&
              r.status != ReportStatus.rejected;
        }).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          children: [
            // 1. Header Salam & Identitas Sivitas
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Avatar inisial dengan sentuhan primer
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(user.nama),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user.nama}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'SiFasilitas',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _capitalize(user.subRole),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 2. Banner Utama Hero: Laporkan Kerusakan Fasilitas
            _BuatLaporanCard(user: user),

            const SizedBox(height: AppSpacing.xl),

            // 3. Kategori Fasilitas Populer (Grid Akses Cepat dengan Ikon)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'KATEGORI FASILITAS',
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
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.bolt_rounded,
                          label: 'Kelistrikan',
                          bgColor: const Color(0xFFFFF8E1),
                          iconColor: const Color(0xFFF57F17),
                          onTap: () => _handleCategoryTap(context, 'Kelistrikan'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.ac_unit_rounded,
                          label: 'AC / Ruangan',
                          bgColor: const Color(0xFFE0F7FA),
                          iconColor: const Color(0xFF00838F),
                          onTap: () => _handleCategoryTap(context, 'AC'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.videocam_rounded,
                          label: 'Proyektor',
                          bgColor: const Color(0xFFEDE7F6),
                          iconColor: const Color(0xFF5E35B1),
                          onTap: () => _handleCategoryTap(context, 'Proyektor'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.wifi_rounded,
                          label: 'Wi-Fi & Net',
                          bgColor: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF2E7D32),
                          onTap: () => _handleCategoryTap(context, 'Wi-Fi'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.water_drop_rounded,
                          label: 'Sanitasi & Air',
                          bgColor: const Color(0xFFE3F2FD),
                          iconColor: const Color(0xFF1565C0),
                          onTap: () => _handleCategoryTap(context, 'Sanitasi'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _CategoryQuickItem(
                          icon: Icons.chair_alt_rounded,
                          label: 'Mebel Kelas',
                          bgColor: const Color(0xFFFBE9E7),
                          iconColor: const Color(0xFFD84315),
                          onTap: () => _handleCategoryTap(context, 'Mebel'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 4. Status Aduan Aktif (Live Tracker)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'STATUS ADUAN AKTIF',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            if (activeReports.isNotEmpty)
              _ActiveReportSummaryCard(report: activeReports.first)
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 26,
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Tidak ada aduan aktif saat ini. Fasilitas kampus siap mendukung kegiatan perkuliahan.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 5. Standar Layanan Fasilitas Kampus (SLA)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'STANDAR LAYANAN FASILITAS',
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
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  _ServiceCategoryRow(
                    icon: Icons.bolt_rounded,
                    iconBg: Color(0xFFFFF8E1),
                    iconColor: Color(0xFFF57F17),
                    nama: 'Kelistrikan & Lampu',
                    sla: '2 Jam',
                    prioritas: 'Darurat',
                  ),
                  Divider(height: 1),
                  _ServiceCategoryRow(
                    icon: Icons.ac_unit_rounded,
                    iconBg: Color(0xFFE0F7FA),
                    iconColor: Color(0xFF00838F),
                    nama: 'AC & Pendingin Ruangan',
                    sla: '6 Jam',
                    prioritas: 'Tinggi',
                  ),
                  Divider(height: 1),
                  _ServiceCategoryRow(
                    icon: Icons.videocam_rounded,
                    iconBg: Color(0xFFEDE7F6),
                    iconColor: Color(0xFF5E35B1),
                    nama: 'Proyektor & Presentasi',
                    sla: '4 Jam',
                    prioritas: 'Tinggi',
                  ),
                  Divider(height: 1),
                  _ServiceCategoryRow(
                    icon: Icons.wifi_rounded,
                    iconBg: Color(0xFFE8F5E9),
                    iconColor: Color(0xFF2E7D32),
                    nama: 'Wi-Fi & Jaringan Internet',
                    sla: '4 Jam',
                    prioritas: 'Tinggi',
                  ),
                  Divider(height: 1),
                  _ServiceCategoryRow(
                    icon: Icons.water_drop_rounded,
                    iconBg: Color(0xFFE3F2FD),
                    iconColor: Color(0xFF1565C0),
                    nama: 'Toilet & Sanitasi',
                    sla: '8 Jam',
                    prioritas: 'Sedang',
                  ),
                  Divider(height: 1),
                  _ServiceCategoryRow(
                    icon: Icons.chair_alt_rounded,
                    iconBg: Color(0xFFFBE9E7),
                    iconColor: Color(0xFFD84315),
                    nama: 'Ruang Kelas & Mebel',
                    sla: '24 Jam',
                    prioritas: 'Rendah',
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 6. Alur Penanganan Laporan (3 Langkah Mudah)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ALUR PENANGANAN LAPORAN',
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                children: [
                  _StepRow(
                    nomor: '1',
                    icon: Icons.qr_code_scanner_rounded,
                    judul: 'Pindai Kode QR Ruangan',
                    deskripsi:
                        'Arahkan kamera ke stiker QR yang menempel di pintu atau meja fasilitas.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _StepRow(
                    nomor: '2',
                    icon: Icons.auto_awesome_rounded,
                    judul: 'Foto Kerusakan & Analisis AI',
                    deskripsi:
                        'Sistem cerdas AI otomatis mendeteksi kategori dan tingkat urgensi penanganan.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _StepRow(
                    nomor: '3',
                    icon: Icons.engineering_rounded,
                    judul: 'Penanganan & Hasil Perbaikan',
                    deskripsi:
                        'Teknisi diterjunkan ke lokasi dan melampirkan foto hasil selesai perbaikan.',
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

  void _handleCategoryTap(BuildContext context, String kategori) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Silakan pindai QR ruangan untuk melapor $kategori.',
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Pindai Sekarang',
          textColor: Colors.amber,
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

/// Kartu aksi utama dengan banner gradien hijau kampus dan ilustrasi ikon QR.
class _BuatLaporanCard extends StatelessWidget {
  const _BuatLaporanCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F7A3C),
            Color(0xFF13964B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF108A43).withValues(alpha: 0.25),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Aksen dekoratif ikon QR transparan di pojok kanan
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
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
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
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'Pindai QR ruangan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
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

/// Item tombol kategori fasilitas cepat dengan ikon berwarna.
class _CategoryQuickItem extends StatelessWidget {
  const _CategoryQuickItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
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
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkasan tiket aktif yang sedang berjalan dengan ikon indikator status.
class _ActiveReportSummaryCard extends StatelessWidget {
  const _ActiveReportSummaryCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.build_rounded,
                  color: AppColors.primary,
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
                      ),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.sync_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.status.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            report.deskripsi,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Baris kategori layanan fasilitas kampus beserta target SLA dan ikon.
class _ServiceCategoryRow extends StatelessWidget {
  const _ServiceCategoryRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.nama,
    required this.sla,
    required this.prioritas,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String nama;
  final String sla;
  final String prioritas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              nama,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                Text(
                  sla,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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

/// Baris langkah alur penanganan dengan ikon dan nomor penunjuk.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.nomor,
    required this.icon,
    required this.judul,
    required this.deskripsi,
  });

  final String nomor;
  final IconData icon;
  final String judul;
  final String deskripsi;

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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  nomor,
                  style: const TextStyle(
                    color: Colors.white,
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
                  fontWeight: FontWeight.w600,
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
