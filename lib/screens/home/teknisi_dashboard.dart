import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/photo_store.dart';
import '../../services/report_repository.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/report_photo.dart';
import '../profile/profile_screen.dart';

class TeknisiDashboard extends StatelessWidget {
  const TeknisiDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    ReportRepository? repository;
    try {
      repository = context.read<ReportRepository>();
    } on ProviderNotFoundException {
      return _TechnicianScaffold(
        user: user,
        body: const _TechnicianUnavailable(),
      );
    }

    return _TechnicianScaffold(
      user: user,
      body: _TechnicianTaskList(
        user: user,
        reports: repository.watchReportsForTeknisi(user.uid),
      ),
    );
  }
}

class _TechnicianScaffold extends StatelessWidget {
  const _TechnicianScaffold({required this.user, required this.body});

  final AppUser user;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('Tugas Teknisi'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _TechnicianTaskList extends StatefulWidget {
  const _TechnicianTaskList({required this.user, required this.reports});

  final AppUser user;
  final Stream<List<Report>> reports;

  @override
  State<_TechnicianTaskList> createState() => _TechnicianTaskListState();
}

class _TechnicianTaskListState extends State<_TechnicianTaskList> {
  ReportStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: widget.reports,
      builder: (context, snapshot) {
        final reports = snapshot.data ?? const <Report>[];
        final assignedCount = reports
            .where((report) => report.status == ReportStatus.assigned)
            .length;
        final inProgressCount = reports
            .where((report) => report.status == ReportStatus.inProgress)
            .length;
        final visibleReports = _statusFilter == null
            ? reports
            : reports
                  .where((report) => report.status == _statusFilter)
                  .toList();

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Column(
                  children: [
                    _TechnicianWelcomeCard(user: widget.user),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: _TechnicianSummaryCard(
                            icon: Icons.assignment_outlined,
                            label: 'Ditugaskan',
                            count: assignedCount,
                            color: AppColors.warning,
                            background: AppColors.warningContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TechnicianSummaryCard(
                            icon: Icons.handyman_outlined,
                            label: 'Dikerjakan',
                            count: inProgressCount,
                            color: AppColors.info,
                            background: AppColors.infoContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Daftar tugas',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (snapshot.hasData)
                          Text(
                            '${visibleReports.length} tiket',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatusFilterChip(
                            label: 'Semua',
                            selected: _statusFilter == null,
                            onSelected: () =>
                                setState(() => _statusFilter = null),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusFilterChip(
                            label: 'Ditugaskan',
                            selected: _statusFilter == ReportStatus.assigned,
                            onSelected: () => setState(
                              () => _statusFilter = ReportStatus.assigned,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _StatusFilterChip(
                            label: 'Dikerjakan',
                            selected: _statusFilter == ReportStatus.inProgress,
                            onSelected: () => setState(
                              () => _statusFilter = ReportStatus.inProgress,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: snapshot.hasError
                    ? const _TechnicianEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Tugas gagal dimuat',
                        message:
                            'Periksa koneksi internet lalu coba lagi nanti.',
                      )
                    : !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : visibleReports.isEmpty
                    ? _TechnicianEmptyState(
                        icon: Icons.inbox_outlined,
                        title: _statusFilter == null
                            ? 'Belum ada tugas'
                            : 'Tidak ada tugas pada status ini',
                        message: _statusFilter == null
                            ? 'Tugas baru akan muncul di sini setelah admin menugaskan tiket kepada Anda.'
                            : 'Tiket dengan status ini akan muncul di sini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.xs,
                          AppSpacing.lg,
                          AppSpacing.xl,
                        ),
                        itemCount: visibleReports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) => _TechnicianReportCard(
                          report: visibleReports[index],
                          actorUid: widget.user.uid,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TechnicianWelcomeCard extends StatelessWidget {
  const _TechnicianWelcomeCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.nama.trim().isEmpty ? 'Teknisi' : user.nama.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Siap membantu fasilitas kampus tetap nyaman.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const CircleAvatar(
            radius: 25,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            child: Icon(Icons.engineering_outlined, size: 28),
          ),
        ],
      ),
    );
  }
}

class _TechnicianSummaryCard extends StatelessWidget {
  const _TechnicianSummaryCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: background,
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: AppColors.primaryContainer,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? AppColors.primary : AppColors.muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.35)
            : Colors.grey.shade300,
      ),
    );
  }
}

class _TechnicianEmptyState extends StatelessWidget {
  const _TechnicianEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TechnicianUnavailable extends StatelessWidget {
  const _TechnicianUnavailable();

  @override
  Widget build(BuildContext context) {
    return const _TechnicianEmptyState(
      icon: Icons.assignment_outlined,
      title: 'Tugas belum tersedia',
      message: 'Daftar tugas perbaikan akan ditampilkan di sini.',
    );
  }
}

class _TechnicianReportCard extends StatefulWidget {
  const _TechnicianReportCard({required this.report, required this.actorUid});

  final Report report;
  final String actorUid;

  @override
  State<_TechnicianReportCard> createState() => _TechnicianReportCardState();
}

class _TechnicianReportCardState extends State<_TechnicianReportCard> {
  bool _loading = false;

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _startWork() async {
    setState(() => _loading = true);
    try {
      await context.read<ReportService>().updateReportStatus(
        reportId: widget.report.id,
        actorUid: widget.actorUid,
        newStatus: ReportStatus.inProgress,
        catatan: 'Teknisi mulai mengerjakan tiket.',
      );
      _notify('Pengerjaan dimulai.');
    } catch (error) {
      _notify(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolveWithPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    PhotoStore photoStore;
    try {
      photoStore = context.read<PhotoStore>();
    } on ProviderNotFoundException {
      photoStore = FirestorePhotoStore.shared;
    }
    final reportService = context.read<ReportService>();

    setState(() => _loading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
      );
      if (picked == null) {
        _notify('Foto bukti belum dipilih.');
        return;
      }

      final photoRef = await photoStore.uploadPhoto(File(picked.path));
      await reportService.updateReportStatus(
        reportId: widget.report.id,
        actorUid: widget.actorUid,
        newStatus: ReportStatus.resolved,
        catatan: 'Perbaikan selesai dan bukti foto dilampirkan.',
        fotoSesudahUrl: photoRef,
      );
      _notify('Tiket berhasil diselesaikan.');
    } catch (error) {
      _notify(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: const CircleAvatar(
          backgroundColor: AppColors.infoContainer,
          foregroundColor: AppColors.info,
          child: Icon(Icons.build_outlined),
        ),
        title: Text(report.ticketNumber),
        subtitle: Text(
          '${report.namaObjek}\n'
          '${report.namaGedung} · ${report.namaRuangan}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: const Icon(Icons.info_outline, size: 16),
              label: Text(report.status.label),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (report.fotoSebelumUrl.isNotEmpty)
            ReportPhoto(
              ref: report.fotoSebelumUrl,
              width: double.infinity,
              height: 160,
              borderRadius: BorderRadius.circular(10),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(report.deskripsi),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pelapor: ${report.reporterName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (report.fotoSesudahUrl != null &&
              report.fotoSesudahUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Foto hasil perbaikan',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ReportPhoto(
              ref: report.fotoSesudahUrl!,
              width: double.infinity,
              height: 160,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (report.status == ReportStatus.assigned)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startWork,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Mulai Kerjakan'),
              ),
            )
          else if (report.status == ReportStatus.inProgress)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _resolveWithPhoto,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Selesaikan dengan Foto'),
              ),
            )
          else
            const Text('Menunggu konfirmasi pelapor.'),
        ],
      ),
    );
  }
}
