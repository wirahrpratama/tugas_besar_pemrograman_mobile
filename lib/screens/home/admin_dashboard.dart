import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../services/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
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
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    ReportRepository? repository;
    try {
      repository = context.read<ReportRepository>();
    } on ProviderNotFoundException {
      return _buildWithoutData(context);
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
            return _EmptyMessage(
              icon: Icons.error_outline,
              message: 'Gagal memuat antrean tiket.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReports = snapshot.data!;
          final reports = allReports
              .where(
                (report) =>
                    _categoryId == null ||
                    report.categoryId == _categoryId ||
                    report.namaObjek == _categoryId,
              )
              .toList();

          return Column(
            children: [
              _AdminFilters(
                status: _status,
                priority: _priority,
                categoryId: _categoryId,
                reports: allReports,
                onStatusChanged: (value) => setState(() => _status = value),
                onPriorityChanged: (value) => setState(() => _priority = value),
                onCategoryChanged: (value) =>
                    setState(() => _categoryId = value),
              ),
              Expanded(
                child: reports.isEmpty
                    ? const _EmptyMessage(
                        icon: Icons.inbox_outlined,
                        message: 'Tidak ada tiket pada filter ini.',
                      )
                    : ListView.separated(
                        padding:
                            AppSpacing.paddingHorizontalLg +
                            const EdgeInsets.only(top: AppSpacing.sm),
                        itemCount: reports.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, index) => _AdminReportCard(
                          report: reports[index],
                          actorUid: widget.user.uid,
                        ),
                      ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: SeedMasterDataButton(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWithoutData(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Admin')),
      body: const SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _EmptyMessage(
              icon: Icons.admin_panel_settings_outlined,
              message: 'Antrean tiket akan ditampilkan di sini.',
            ),
            SizedBox(height: AppSpacing.sm),
            SeedMasterDataButton(),
          ],
        ),
      ),
    );
  }
}

class _AdminFilters extends StatelessWidget {
  const _AdminFilters({
    required this.status,
    required this.priority,
    required this.categoryId,
    required this.reports,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onCategoryChanged,
  });

  final ReportStatus? status;
  final String? priority;
  final String? categoryId;
  final List<Report> reports;
  final ValueChanged<ReportStatus?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final categories = <String, String>{};
    for (final report in reports) {
      categories.putIfAbsent(report.categoryId, () => report.namaObjek);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _FilterDropdown<ReportStatus?>(
            label: 'Status',
            value: status,
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua status')),
              ...ReportStatus.values.map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text(value.label)),
              ),
            ],
            onChanged: onStatusChanged,
          ),
          _FilterDropdown<String?>(
            label: 'Urgensi',
            value: priority,
            items: const [
              DropdownMenuItem(value: null, child: Text('Semua urgensi')),
              DropdownMenuItem(value: 'darurat', child: Text('Darurat')),
              DropdownMenuItem(value: 'tinggi', child: Text('Tinggi')),
              DropdownMenuItem(value: 'sedang', child: Text('Sedang')),
              DropdownMenuItem(value: 'rendah', child: Text('Rendah')),
            ],
            onChanged: onPriorityChanged,
          ),
          _FilterDropdown<String?>(
            label: 'Kategori',
            value: categoryId,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Semua kategori'),
              ),
              ...categories.entries.map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  const _AdminReportCard({required this.report, required this.actorUid});

  final Report report;
  final String actorUid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: _PriorityIcon(priority: report.prioritas),
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
          _StatusAndPriority(report: report),
          if (report.fotoSebelumUrl.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ReportPhoto(
              ref: report.fotoSebelumUrl,
              width: double.infinity,
              height: 160,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(report.deskripsi),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Pelapor: ${report.reporterName} · ${report.upvotesCount} upvote',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          _AdminActions(report: report, actorUid: actorUid),
        ],
      ),
    );
  }
}

class _StatusAndPriority extends StatelessWidget {
  const _StatusAndPriority({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        Chip(
          avatar: const Icon(Icons.info_outline, size: 16),
          label: Text(report.status.label),
        ),
        Chip(
          label: Text('Prioritas: ${report.prioritas}'),
          backgroundColor: _priorityContainer(report.prioritas),
        ),
        if (report.assignedTeknisiNama != null &&
            report.assignedTeknisiNama!.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.engineering_outlined, size: 16),
            label: Text(report.assignedTeknisiNama!),
          ),
      ],
    );
  }

  static Color _priorityContainer(String priority) {
    switch (priority.toLowerCase()) {
      case 'darurat':
        return AppColors.dangerContainer;
      case 'tinggi':
        return AppColors.warningContainer;
      case 'sedang':
        return AppColors.infoContainer;
      default:
        return AppColors.successContainer;
    }
  }
}

class _AdminActions extends StatelessWidget {
  const _AdminActions({required this.report, required this.actorUid});

  final Report report;
  final String actorUid;

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status tiket ${report.ticketNumber} diperbarui.'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak laporan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan',
            hintText: 'Tuliskan alasan penolakan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && note.isNotEmpty && context.mounted) {
      await _update(context, ReportStatus.rejected, catatan: note);
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
              ? const [
                  Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Text('Belum ada akun teknisi.'),
                  ),
                ]
              : technicians
                    .map(
                      (technician) => SimpleDialogOption(
                        onPressed: () =>
                            Navigator.pop(dialogContext, technician),
                        child: ListTile(
                          leading: const Icon(Icons.engineering_outlined),
                          title: Text(technician.nama),
                          subtitle: Text(technician.email),
                        ),
                      ),
                    )
                    .toList(),
        ),
      );
      if (selected != null && context.mounted) {
        await _update(context, ReportStatus.assigned, teknisiUid: selected.uid);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (report.status) {
      case ReportStatus.reported:
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: () => _update(context, ReportStatus.verified),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Verifikasi'),
            ),
            OutlinedButton.icon(
              onPressed: () => _reject(context),
              icon: const Icon(Icons.close),
              label: const Text('Tolak'),
            ),
          ],
        );
      case ReportStatus.verified:
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: () => _assign(context),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Tugaskan Teknisi'),
            ),
            OutlinedButton.icon(
              onPressed: () => _reject(context),
              icon: const Icon(Icons.close),
              label: const Text('Tolak'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _PriorityIcon extends StatelessWidget {
  const _PriorityIcon({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (priority.toLowerCase()) {
      'darurat' => (AppColors.dangerContainer, AppColors.danger),
      'tinggi' => (AppColors.warningContainer, AppColors.warning),
      'sedang' => (AppColors.infoContainer, AppColors.info),
      _ => (AppColors.successContainer, AppColors.success),
    };
    return CircleAvatar(
      backgroundColor: background,
      foregroundColor: foreground,
      child: Text(
        priority.isNotEmpty ? priority.substring(0, 1).toUpperCase() : '-',
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
