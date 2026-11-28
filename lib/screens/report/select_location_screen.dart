import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';

/// Nama gedung unik dari [locations], terurut abjad. Nama kosong dilewati
/// karena tidak bisa dipilih dengan jelas oleh pengguna.
List<String> daftarGedung(List<CampusLocation> locations) {
  final gedung = {
    for (final l in locations)
      if (l.namaGedung.trim().isNotEmpty) l.namaGedung,
  };
  return gedung.toList()..sort();
}

/// Ruangan di [gedung], terurut lantai lalu nama ruangan. Kosong bila
/// [gedung] belum dipilih.
List<CampusLocation> ruanganDiGedung(
  List<CampusLocation> locations,
  String? gedung,
) {
  if (gedung == null) return const [];
  return locations.where((l) => l.namaGedung == gedung).toList()..sort((a, b) {
    final lantai = a.lantai.compareTo(b.lantai);
    if (lantai != 0) return lantai;
    return a.namaRuangan.compareTo(b.namaRuangan);
  });
}

/// Jalur cadangan bila QR tidak bisa dipindai: pilih gedung, lalu ruangan.
///
/// Layar ini hanya MEMILIH. Ruangan terpilih dikembalikan lewat
/// `Navigator.pop(location)`, lalu pemindai yang membuka form laporan.
/// Dengan begitu kamera dan navigasi ke form tetap diatur di satu tempat.
class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SelectLocationScreen> createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Pola pertemuan 09: error belum tampil sebelum pengguna menekan tombol;
  /// setelah submit gagal, error diperbarui setiap kali pilihan berubah.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// Disimpan di state, bukan dibuat di build(): setiap setState (mis. saat
  /// memilih gedung) akan membuat langganan Firestore baru dan dropdown sempat
  /// kembali ke tampilan loading.
  late Stream<List<CampusLocation>> _locations;

  String? _gedung;
  String? _ruanganId;

  @override
  void initState() {
    super.initState();
    _locations = context.read<ReportRepository>().watchLocations();
  }

  void _muatUlang() {
    setState(() {
      _locations = context.read<ReportRepository>().watchLocations();
    });
  }

  void _lanjut(CampusLocation? terpilih) {
    final valid = _formKey.currentState!.validate();
    if (!valid || terpilih == null) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.of(context).pop(terpilih);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Pilih ruangan',
        profileUid: widget.user.uid,
        userName: widget.user.nama,
        photoUrl: widget.user.photoUrl,
      ),
      body: SafeArea(
        child: Column(
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
            Expanded(
              child: StreamBuilder<List<CampusLocation>>(
                stream: _locations,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StatusMessage(
                      icon: Icons.cloud_off_outlined,
                      message:
                          'Gagal memuat daftar ruangan. Periksa koneksi '
                          'internet lalu coba lagi.',
                      actionLabel: 'Coba lagi',
                      onAction: _muatUlang,
                    );
                  }
                  final locations = snapshot.data;
                  if (locations == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (daftarGedung(locations).isEmpty) {
                    return const _StatusMessage(
                      icon: Icons.domain_disabled_outlined,
                      message:
                          'Daftar ruangan belum tersedia. Minta admin mengisi '
                          'data master ruangan; daftar akan muncul otomatis.',
                    );
                  }
                  return _buildForm(locations);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<CampusLocation> locations) {
    final theme = Theme.of(context);
    final gedungList = daftarGedung(locations);
    // Data master bisa berubah saat layar terbuka. Pilihan yang sudah tidak
    // ada di daftar dianggap kosong, supaya dropdown tidak menerima nilai
    // tanpa item (assert "exactly one item").
    final gedung = gedungList.contains(_gedung) ? _gedung : null;
    final ruanganList = ruanganDiGedung(locations, gedung);
    final terpilih = ruanganList.where((l) => l.id == _ruanganId).firstOrNull;

    return SingleChildScrollView(
      padding: AppSpacing.paddingAllLg,
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih gedung, lalu ruangan tempat fasilitas yang rusak.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // initialValue (bukan `value`, yang deprecated sejak Flutter
            // 3.33). Bila initialValue berubah, field ikut memperbarui nilainya.
            DropdownButtonFormField<String>(
              initialValue: gedung,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Gedung'),
              hint: const Text('Pilih gedung'),
              items: [
                for (final g in gedungList)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (value) => setState(() {
                // Dropdown dependen: ganti gedung = pilihan ruangan dikosongkan.
                if (value != _gedung) _ruanganId = null;
                _gedung = value;
              }),
              validator: (value) =>
                  value == null ? 'Pilih gedung terlebih dahulu.' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              initialValue: terpilih?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ruangan'),
              hint: const Text('Pilih ruangan di gedung ini'),
              disabledHint: const Text('Pilih gedung dulu'),
              items: [
                for (final r in ruanganList)
                  DropdownMenuItem(
                    value: r.id,
                    child: Text(
                      '${r.namaRuangan} · Lantai ${r.lantai}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _ruanganId = value),
              validator: (value) =>
                  value == null ? 'Pilih ruangan terlebih dahulu.' : null,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => _lanjut(terpilih),
              child: const Text('Lanjut buat laporan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pesan penuh layar untuk keadaan error atau data kosong.
class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingAllXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface),
            ),
            if (label != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
