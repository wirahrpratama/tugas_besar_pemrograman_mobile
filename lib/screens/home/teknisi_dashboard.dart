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
        body: const Center(
          child: Padding(
            padding: AppSpacing.paddingAllXl,
            child: Text(
              'Daftar tugas perbaikan akan ditampilkan di sini.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return _TechnicianScaffold(
      user: user,
      body: StreamBuilder<List<Report>>(
        stream: repository.watchReportsForTeknisi(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: AppSpacing.paddingAllXl,
                child: Text(
                  'Gagal memuat daftar tugas.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: AppSpacing.paddingAllXl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 48,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Belum ada tugas yang ditugaskan.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding:
                AppSpacing.paddingHorizontalLg +
                const EdgeInsets.only(top: AppSpacing.sm),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, index) => _TechnicianReportCard(
              report: reports[index],
              actorUid: user.uid,
            ),
          );
        },
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
      appBar: AppBar(
        title: const Text('Tugas Teknisi'),
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
