import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../services/ai_classifier_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';
import 'report_form_logic.dart';

/// Bagian "Fasilitas & prioritas": kartu saran AI, tombol minta saran,
/// dropdown fasilitas (master `categories`, bisa diubah pelapor), lalu chip
/// prioritas + target SLA. Di UI disebut "fasilitas" karena isi master adalah
/// objek fasilitas (mis. "Proyektor & Layar Presentasi"), bukan jenis rusak.
///
/// Hanya tampilan. Memanggil classifier, memuat kategori, dan aturan
/// prioritas ada di layar form / `report_form_logic.dart`.
class CategorySection extends StatelessWidget {
  const CategorySection({
    super.key,
    required this.fieldKey,
    required this.kategoriList,
    required this.gagalMemuatKategori,
    required this.onMuatUlangKategori,
    required this.kategoriId,
    required this.onKategoriChanged,
    required this.saran,
    required this.memintaSaran,
    required this.pesanSaranGagal,
    required this.onMintaSaran,
  });

  /// Kunci FormField dropdown, agar layar bisa memvalidasi ulang field ini.
  final GlobalKey<FormFieldState<String>> fieldKey;

  /// Null = masih memuat.
  final List<FacilityCategory>? kategoriList;
  final bool gagalMemuatKategori;
  final VoidCallback onMuatUlangKategori;

  /// Id kategori terpilih; null bila belum ada atau tidak ada di daftar.
  final String? kategoriId;
  final ValueChanged<String?> onKategoriChanged;

  final DamageClassificationResult? saran;
  final bool memintaSaran;
  final String? pesanSaranGagal;
  final VoidCallback onMintaSaran;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = kategoriList ?? const <FacilityCategory>[];
    final terpilih = list.where((c) => c.id == kategoriId).firstOrNull;
    final saran = this.saran;
    final pesanGagal = pesanSaranGagal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saran != null) ...[
          _SaranCard(saran: saran, kategoriList: kategoriList),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (memintaSaran)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSpacing.sm),
                Text('Meminta saran AI…'),
              ],
            ),
          ),
        if (pesanGagal != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _InfoText(icon: Icons.info_outline, text: pesanGagal),
          ),
        AppButton(
          variant: AppButtonVariant.outline,
          icon: Icons.auto_awesome_outlined,
          label: saran == null ? 'Minta saran AI' : 'Minta saran ulang',
          onPressed: memintaSaran ? null : onMintaSaran,
        ),
        const SizedBox(height: AppSpacing.lg),
        // Nilai = id kategori (String), bukan objek FacilityCategory: model
        // tidak meng-override ==, jadi objek baru dari stream tidak akan
        // "sama" dengan pilihan lama (pelajaran dari langkah 4).
        DropdownButtonFormField<String>(
          key: fieldKey,
          initialValue: terpilih?.id,
          isExpanded: true,
          // Bawaan DropdownButton memakai titleMedium (w600) sehingga nilai
          // terpilih tampak lebih tebal dari teks input; samakan ke bodyLarge
          // seperti TextFormField.
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          decoration: const InputDecoration(labelText: 'Fasilitas yang rusak'),
          hint: const Text('Pilih fasilitas'),
          disabledHint: Text(
            kategoriList == null && !gagalMemuatKategori
                ? 'Memuat daftar fasilitas…'
                : 'Daftar fasilitas tidak tersedia',
          ),
          items: [
            for (final c in list)
              DropdownMenuItem(value: c.id, child: Text(c.namaObjek)),
          ],
          onChanged: onKategoriChanged,
          validator: (value) =>
              value == null ? 'Pilih fasilitas yang rusak.' : null,
        ),
        if (gagalMemuatKategori) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Expanded(
                child: _InfoText(
                  icon: Icons.cloud_off_outlined,
                  text: 'Gagal memuat daftar fasilitas. Periksa koneksi.',
                ),
              ),
              TextButton(
                onPressed: onMuatUlangKategori,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ] else if (kategoriList != null && list.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          const _InfoText(
            icon: Icons.inventory_2_outlined,
            text:
                'Daftar fasilitas belum tersedia. Minta admin mengisi data '
                'master kategori.',
          ),
        ],
        if (terpilih != null) ...[
          const SizedBox(height: AppSpacing.md),
          _PrioritasRow(saran: saran, kategori: terpilih),
        ],
        if (terpilih == null && kategoriList != null && list.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Prioritas dan target penanganan tampil setelah fasilitas '
              'dipilih.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SaranCard extends StatelessWidget {
  const _SaranCard({required this.saran, required this.kategoriList});

  final DamageClassificationResult saran;
  final List<FacilityCategory>? kategoriList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final list = kategoriList;
    final kategori = list?.where((c) => c.id == saran.categoryId).firstOrNull;
    // Daftar sudah dimuat tapi id saran tidak ada: saran tidak bisa dipakai.
    final tidakDitemukan = list != null && kategori == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        // secondaryContainer = teal muda; AppColors menandainya untuk elemen AI.
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: AppSpacing.paddingAllLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Saran AI: ${kategori?.namaObjek ?? saran.categoryId}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tidakDitemukan
                  ? 'Fasilitas saran tidak ada di daftar. Pilih fasilitas '
                        'secara manual.'
                  : saran.alasanSingkat,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritasRow extends StatelessWidget {
  const _PrioritasRow({required this.saran, required this.kategori});

  final DamageClassificationResult? saran;
  final FacilityCategory kategori;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasil = prioritasTampil(saran, kategori);
    return Row(
      children: [
        PriorityChip(prioritas: hasil.prioritas),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            'Target penanganan ${kategori.targetSlaJam} jam · '
            '${hasil.dariAi ? 'disarankan AI' : 'bawaan fasilitas'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip prioritas. Warna mengikuti pemetaan tim di `admin_dashboard.dart`
/// (danger/warning/info/success) supaya sama di semua layar; label teks dan
/// ikon tetap ada sehingga makna tidak hanya dari warna.
class PriorityChip extends StatelessWidget {
  const PriorityChip({super.key, required this.prioritas});

  final String prioritas;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (prioritas.toLowerCase()) {
      'darurat' => (
        AppColors.dangerContainer,
        AppColors.danger,
        Icons.priority_high,
      ),
      'tinggi' => (
        AppColors.warningContainer,
        AppColors.warning,
        Icons.keyboard_double_arrow_up,
      ),
      'sedang' => (AppColors.infoContainer, AppColors.info, Icons.drag_handle),
      _ => (
        AppColors.successContainer,
        AppColors.success,
        Icons.keyboard_arrow_down,
      ),
    };
    return Semantics(
      label: 'Prioritas ${labelPrioritas(prioritas)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Text(
              labelPrioritas(prioritas),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
