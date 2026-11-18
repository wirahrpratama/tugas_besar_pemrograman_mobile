import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import 'create_report_screen.dart';

/// Layar pindai QR ruangan. Langkah 1: kerangka saja.
///
/// StatefulWidget sejak awal karena langkah 2 akan menyimpan
/// `MobileScannerController` (dibuat di initState, dibuang di dispose).
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  // TODO(langkah 3): hapus data contoh ini; lokasi asli dari getLocationByQr.
  static const _contohLokasi = CampusLocation(
    id: 'contoh',
    kodeRuangan: 'QR-GDA-201',
    namaGedung: 'Gedung A',
    namaRuangan: 'Ruang 201 (contoh)',
    lantai: 2,
  );

  void _bukaFormLaporan(CampusLocation location) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CreateReportScreen(user: widget.user, location: location),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai QR ruangan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'Pratinjau kamera (langkah 2)',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Arahkan kamera ke QR Code di pintu ruangan atau stiker aset.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // TODO(langkah 3): hapus tombol sementara ini.
              FilledButton(
                onPressed: () => _bukaFormLaporan(_contohLokasi),
                child: const Text('Lanjut (contoh, sementara)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
