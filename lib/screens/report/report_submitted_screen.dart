import 'package:flutter/material.dart';

/// Layar hasil kirim laporan. Langkah 1: kerangka saja; tiga varian
/// (tiket baru / digabung / sudah mendukung) dibuat di langkah 9.
///
/// [result] = Map apa adanya dari `ReportService.submitReport`
/// (`merged`, `already_supported`, `ticket_number`, `message`).
class ReportSubmittedScreen extends StatelessWidget {
  const ReportSubmittedScreen({super.key, required this.result});

  final Map<String, dynamic> result;

  void _kembaliKeBeranda(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticketNumber = result['ticket_number']?.toString() ?? '-';
    final message = result['message']?.toString() ?? '-';

    // canPop: false mencegah back sistem melakukan pop biasa; sebagai gantinya
    // kita arahkan ke beranda agar pengguna tidak kembali ke alur yang selesai.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _kembaliKeBeranda(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hasil laporan'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Laporan terkirim',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Nomor tiket'),
                  subtitle: Text(ticketNumber),
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => _kembaliKeBeranda(context),
                child: const Text('Kembali ke beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
