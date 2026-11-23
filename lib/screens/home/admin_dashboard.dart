import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../services/report_service.dart';
import '../../widgets/report_photo.dart';
import '../../widgets/seed_master_data_button.dart';
import '../profile/profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  ReportStatus? _status;
  String? _priority;
  String? _category;

  @override
  Widget build(BuildContext context) {
    ReportRepository? repository;
    try {
      repository = context.read<ReportRepository>();
    } on ProviderNotFoundException {
      return _buildFallback();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProfileScreen(uid: widget.user.uid),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Report>>(
        stream: repository.watchReportsForAdmin(
          status: _status,
          prioritas: _priority,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(text: 'Gagal memuat antrean: ${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!
              .where(
                (report) => _category == null || report.categoryId == _category,
              )
              .toList();
          return Column(
            children: [
              _FilterBar(
                status: _status,
                priority: _priority,
                category: _category,
                reports: snapshot.data!,
                onStatusChanged: (value) => setState(() => _status = value),
                onPriorityChanged: (value) => setState(() => _priority = value),
                onCategoryChanged: (value) => setState(() => _category = value),
              ),
              Expanded(
                child: reports.isEmpty
                    ? const _Message(text: 'Belum ada tiket pada filter ini.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: reports.length,
                        itemBuilder: (_, index) => _AdminReportCard(
                          report: reports[index],
                          actorUid: widget.user.uid,
                          onChanged: _showMessage,
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: SeedMasterDataButton(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFallback() {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Admin')),
      body: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Message(text: 'Antrean tiket belum dapat dimuat.'),
          SeedMasterDataButton(),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminReportCard extends StatelessWidget {
  const _AdminReportCard({
    required this.report,
    required this.actorUid,
    required this.onChanged,
  });

  final Report report;
  final String actorUid;
  final ValueChanged<String> onChanged;

  Future<void> _update(
    BuildContext context,
    ReportStatus status, {
    String catatan = '',
    String? teknisiUid,
  }) async {
    try {
      await context.read<ReportService>().updateReportStatus(
        reportId: report.id,
        actorUid: actorUid,
        newStatus: status,
        catatan: catatan,
        assignedTeknisiUid: teknisiUid,
      );
      onChanged('Status tiket ${report.ticketNumber} berhasil diperbarui.');
    } catch (error) {
      onChanged(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: _PriorityBadge(priority: report.prioritas),
        title: Text(report.ticketNumber),
        subtitle: Text(
          '${report.namaObjek} • ${report.namaGedung} ${report.namaRuangan}\n'
          '${report.status.label}',
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
            subtitle: Text(
              'Pelapor: ${report.reporterName} • Upvote: ${report.upvotesCount}',
            ),
          ),
          _actions(context),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    switch (report.status) {
      case ReportStatus.reported:
        return _ActionRow(
          children: [
            FilledButton.icon(
              onPressed: () => _update(context, ReportStatus.verified),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verifikasi'),
            ),
            OutlinedButton.icon(
              onPressed: () => _askNote(context, ReportStatus.rejected),
              icon: const Icon(Icons.close),
              label: const Text('Tolak'),
            ),
          ],
        );
      case ReportStatus.verified:
        return _ActionRow(
          children: [
            FilledButton.icon(
              onPressed: () => _assign(context),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Tugaskan Teknisi'),
            ),
            OutlinedButton.icon(
              onPressed: () => _askNote(context, ReportStatus.rejected),
              icon: const Icon(Icons.close),
              label: const Text('Tolak'),
            ),
          ],
        );
      default:
        return const SizedBox(height: 8);
    }
  }

  Future<void> _askNote(BuildContext context, ReportStatus status) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alasan penolakan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Tulis alasan wajib...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && note.isNotEmpty && context.mounted) {
      await _update(context, status, catatan: note);
    }
  }

  Future<void> _assign(BuildContext context) async {
    try {
      final technicians = await context.read<ReportRepository>().listTeknisi();
      if (!context.mounted) return;
      final selected = await showDialog<AppUser>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Pilih Teknisi'),
          children: technicians.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada akun teknisi.'),
                  ),
                ]
              : technicians
                    .map(
                      (technician) => SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(dialogContext, technician),
                        child: Text(technician.nama),
                      ),
                    )
                    .toList(),
        ),
      );
      if (selected != null && context.mounted) {
        await _update(context, ReportStatus.assigned, teknisiUid: selected.uid);
      }
    } catch (error) {
      onChanged(error.toString());
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.priority,
    required this.category,
    required this.reports,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
  });

  final ReportStatus? status;
  final String? priority;
  final String? category;
  final List<Report> reports;
  final ValueChanged<ReportStatus?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final categories = reports.map((e) => e.categoryId).toSet().toList()
      ..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DropdownButton<ReportStatus?>(
            value: status,
            hint: const Text('Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua status')),
              ...ReportStatus.values.map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label.split(' ').first),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: priority,
            hint: const Text('Urgensi'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Semua urgensi')),
              DropdownMenuItem(value: 'darurat', child: Text('Darurat')),
              DropdownMenuItem(value: 'tinggi', child: Text('Tinggi')),
              DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
              DropdownMenuItem(value: 'rendah', child: Text('Rendah')),
            ],
            onChanged: onPriorityChanged,
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: category,
            hint: const Text('Kategori'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Semua kategori'),
              ),
              ...categories.map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: priority == 'darurat'
        ? Colors.red.shade100
        : priority == 'tinggi'
        ? Colors.orange.shade100
        : Colors.green.shade100,
    child: Text(priority.substring(0, 1).toUpperCase()),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
