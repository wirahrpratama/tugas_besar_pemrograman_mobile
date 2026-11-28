import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/pelapor_bottom_nav_bar.dart' show PelaporTab;
import '../home/pelapor_home.dart';
import 'category_section.dart' show PriorityChip;
import 'report_form_logic.dart';
import 'report_section_header.dart';

/// Layar hasil kirim laporan dengan tiga varian (lihat [VarianHasil]).
///
/// [result] = Map apa adanya dari `ReportService.submitReport`. Map itu hanya
/// berisi `merged`, `already_supported`, `report_id`, `ticket_number`, dan
/// `message`, jadi lokasi, fasilitas, dan prioritas dioper dari form.
class ReportSubmittedScreen extends StatelessWidget {
  const ReportSubmittedScreen({
    super.key,
    required this.result,
    required this.user,
    required this.location,
    required this.category,
    required this.prioritas,
  });

  final Map<String, dynamic> result;
  final AppUser user;
  final CampusLocation location;
  final FacilityCategory category;

  /// Prioritas yang dikirim (hasil `prioritasTampil`); hanya ditampilkan
  /// untuk tiket baru, karena prioritas tiket lama bisa sudah berbeda.
  final String prioritas;

  void _kembaliKeBeranda(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Sementara layar detail tiket (milik Rafi, `lib/screens/tracking/`) belum
  /// ada: buka tab Riwayat beranda pelapor, yang menampilkan status laporan.
  /// Bila layar detail sudah ada, cukup buka detail dengan
  /// `result['report_id']`.
  void _lihatStatus(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PelaporHome(user: user, initialTab: PelaporTab.riwayat),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final varian = varianHasil(result);
    final ticketNumber = result['ticket_number']?.toString().trim();

    // canPop: false: back sistem tidak kembali ke form yang sudah terkirim,
    // melainkan ke beranda.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _kembaliKeBeranda(context);
      },
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Hasil laporan',
          profileUid: user.uid,
          userName: user.nama,
          photoUrl: user.photoUrl,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingAllXl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusHeader(varian: varian),
                const SizedBox(height: AppSpacing.xl),
                const ReportSectionHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'Ringkasan',
                ),
                _RingkasanCard(
                  varian: varian,
                  ticketNumber: (ticketNumber == null || ticketNumber.isEmpty)
                      ? '-'
                      : ticketNumber,
                  location: location,
                  category: category,
                  prioritas: prioritas,
                ),
                const SizedBox(height: AppSpacing.xl),
                // Tanpa ikon: AppButton dengan ikon memakai Row yang tidak
                // bisa melipat label, dan label ini overflow di HP 360 dp.
                AppButton(
                  label: 'Lihat status laporan',
                  onPressed: () => _lihatStatus(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.outline,
                  label: 'Kembali ke beranda',
                  onPressed: () => _kembaliKeBeranda(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.varian});

  final VarianHasil varian;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, warna, latar, judul, penjelasan) = switch (varian) {
      VarianHasil.tiketBaru => (
        Icons.check_circle_outline,
        colorScheme.primary,
        colorScheme.primaryContainer,
        'Laporan terkirim',
        'Tiket baru sudah dibuat. Admin fasilitas akan memverifikasi '
            'laporan Anda, lalu menugaskan teknisi.',
      ),
      VarianHasil.digabung => (
        Icons.group_add_outlined,
        colorScheme.secondary,
        colorScheme.secondaryContainer,
        'Dukungan Anda tercatat',
        'Kerusakan ini sudah dilaporkan dan sedang ditangani. Laporan Anda '
            'digabung ke tiket yang sama sebagai +1 dukungan, sehingga '
            'prioritasnya bisa naik.',
      ),
      VarianHasil.sudahMendukung => (
        Icons.info_outline,
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
        'Anda sudah mendukung laporan ini',
        'Anda sudah tercatat sebagai pelapor atau pendukung tiket ini, jadi '
            'tidak ada perubahan. Pantau statusnya di riwayat.',
      ),
    };

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
          child: Icon(icon, size: 48, color: warna),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          judul,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          penjelasan,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RingkasanCard extends StatelessWidget {
  const _RingkasanCard({
    required this.varian,
    required this.ticketNumber,
    required this.location,
    required this.category,
    required this.prioritas,
  });

  final VarianHasil varian;
  final String ticketNumber;
  final CampusLocation location;
  final FacilityCategory category;
  final String prioritas;

  @override
  Widget build(BuildContext context) {
    final tiketBaru = varian == VarianHasil.tiketBaru;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingAllLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Baris(
              label: tiketBaru ? 'Nomor tiket' : 'Nomor tiket (yang sudah ada)',
              child: SelectableText(ticketNumber),
            ),
            _Baris(
              label: 'Lokasi',
              child: Text('${location.namaRuangan} · ${location.namaGedung}'),
            ),
            _Baris(label: 'Fasilitas', child: Text(category.namaObjek)),
            if (tiketBaru) ...[
              _Baris(
                label: 'Prioritas',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PriorityChip(prioritas: prioritas),
                ),
              ),
              _Baris(
                label: 'Target penanganan',
                terakhir: true,
                child: Text('${category.targetSlaJam} jam'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu baris label (kecil, abu-abu) + nilai (titleSmall) di kartu ringkasan.
class _Baris extends StatelessWidget {
  const _Baris({
    required this.label,
    required this.child,
    this.terakhir = false,
  });

  final String label;
  final Widget child;
  final bool terakhir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: terakhir ? 0 : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          DefaultTextStyle.merge(
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
