import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/photo_store.dart';
import '../../services/report_repository.dart';
import '../../services/report_service.dart';
import '../../widgets/report_photo.dart';
import '../profile/profile_screen.dart';

class TeknisiDashboard extends StatelessWidget {
  const TeknisiDashboard({super.key, required this.user});

  final AppUser user;

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
      body: StreamBuilder<List<Report>>(
        stream: context.read<ReportRepository>().watchReportsForTeknisi(
          user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Gagal memuat tugas: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(
              child: Text('Belum ada tugas yang ditugaskan.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
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

class _TechnicianReportCard extends StatefulWidget {
  const _TechnicianReportCard({required this.report, required this.actorUid});
  final Report report;
  final String actorUid;

  @override
  State<_TechnicianReportCard> createState() => _TechnicianReportCardState();
}

class _TechnicianReportCardState extends State<_TechnicianReportCard> {
  bool _loading = false;

  Future<void> _startWork() async {
    await _update(ReportStatus.inProgress);
  }

  Future<void> _resolve() async {
    final photoStore = context.read<PhotoStore>();
    final reportService = context.read<ReportService>();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final picked = await ImagePicker().pickImage(source: source);
      if (picked == null || !mounted) return;
      setState(() => _loading = true);
      final ref = await photoStore.uploadPhoto(File(picked.path));
      await reportService.updateReportStatus(
        reportId: widget.report.id,
        actorUid: widget.actorUid,
        newStatus: ReportStatus.resolved,
        catatan: 'Perbaikan selesai dan bukti foto dilampirkan.',
        fotoSesudahUrl: ref,
      );
      _notify('Tiket ditandai selesai.');
    } catch (error) {
      _notify(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update(ReportStatus status) async {
    setState(() => _loading = true);
    try {
      await context.read<ReportService>().updateReportStatus(
        reportId: widget.report.id,
        actorUid: widget.actorUid,
        newStatus: status,
        catatan: status == ReportStatus.inProgress
            ? 'Teknisi mulai mengerjakan tiket.'
            : '',
      );
      _notify('Status tiket diperbarui.');
    } catch (error) {
      _notify(error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.build_circle_outlined),
        title: Text(report.ticketNumber),
        subtitle: Text(
          '${report.namaObjek} • ${report.namaRuangan}\n${report.status.label}',
        ),
        children: [
          if (report.fotoSebelumUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReportPhoto(
                ref: report.fotoSebelumUrl,
                width: double.infinity,
                height: 150,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ListTile(
            title: Text(report.deskripsi),
            subtitle: Text('Pelapor: ${report.reporterName}'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _loading
                  ? const CircularProgressIndicator()
                  : report.status == ReportStatus.assigned
                  ? FilledButton.icon(
                      onPressed: _startWork,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Mulai Kerjakan'),
                    )
                  : report.status == ReportStatus.inProgress
                  ? FilledButton.icon(
                      onPressed: _resolve,
                      icon: const Icon(Icons.check),
                      label: const Text('Selesaikan dengan Foto'),
                    )
                  : const Text('Menunggu konfirmasi pelapor.'),
            ),
          ),
        ],
      ),
    );
  }
}
