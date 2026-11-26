import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';
import 'report_submitted_screen.dart';

/// Layar form laporan. Langkah 1: kerangka saja.
///
/// StatefulWidget sejak awal karena langkah 5 akan menyimpan
/// `GlobalKey<FormState>` dan `TextEditingController` deskripsi.
class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({
    super.key,
    required this.user,
    required this.location,
  });

  final AppUser user;
  final CampusLocation location;

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  // TODO(langkah 8): hapus; hasil asli dari ReportService.submitReport.
  void _kirimContoh() {
    // pushReplacement: form dikeluarkan dari tumpukan, jadi back dari layar
    // hasil tidak kembali ke form yang sudah terkirim.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportSubmittedScreen(
          userUid: widget.user.uid,
          userName: widget.user.nama,
          result: const {
            'merged': false,
            'ticket_number': 'CONTOH-0001',
            'message': 'Data contoh, belum dikirim ke server.',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = widget.location;
    return Scaffold(
      appBar: AppTopBar(
        title: 'Buat laporan',
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Lokasi', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.meeting_room_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(location.namaRuangan),
                      subtitle: Text(
                        '${location.namaGedung} · ${location.kodeRuangan} · '
                        'Lantai ${location.lantai}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _PlaceholderSection(
                    judul: 'Foto kerusakan',
                    keterangan: 'Langkah 6',
                  ),
                  const _PlaceholderSection(
                    judul: 'Deskripsi kerusakan',
                    keterangan: 'Langkah 5',
                  ),
                  const _PlaceholderSection(
                    judul: 'Saran kategori dari AI',
                    keterangan: 'Langkah 7',
                  ),
                  const SizedBox(height: 8),
                  // TODO(langkah 8): ganti dengan LoadingButton "Kirim laporan".
                  FilledButton(
                    onPressed: _kirimContoh,
                    child: const Text('Kirim (contoh, sementara)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.judul, required this.keterangan});

  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Belum dibuat ($keterangan).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
