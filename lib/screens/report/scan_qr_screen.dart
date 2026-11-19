import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/report_models.dart';
import 'create_report_screen.dart';

/// Layar pindai QR ruangan.
///
/// Langkah 2: kamera, bingkai bidik, senter, penanganan izin kamera, dan
/// pencegahan deteksi ganda. Pencocokan QR ke `locations` menyusul (langkah 3).
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with WidgetsBindingObserver {
  // TODO(langkah 3): hapus data contoh ini; lokasi asli dari getLocationByQr.
  static const _contohLokasi = CampusLocation(
    id: 'contoh',
    kodeRuangan: 'QR-GDA-201',
    namaGedung: 'Gedung A',
    namaRuangan: 'Ruang 201 (contoh)',
    lantai: 2,
  );

  // Controller memegang sesi kamera native, jadi dibuat sekali di initState
  // dan wajib dibebaskan di dispose (sama seperti TextEditingController).
  late final MobileScannerController _controller;

  /// Kunci agar satu QR tidak diproses berkali-kali: `onDetect` bisa
  /// terpanggil beruntun selama QR yang sama masih di depan kamera.
  /// Di langkah 3 kunci ini juga menahan deteksi selama `await getLocationByQr`.
  bool _isProcessing = false;

  /// Isi QR terakhir yang terbaca. Selama tidak null, deteksi baru diabaikan
  /// sampai pengguna menekan "Pindai lagi".
  String? _scannedValue;

  /// True saat layar lain (form laporan) sedang di atas layar ini, supaya
  /// kamera tidak dinyalakan lagi ketika app kembali dari background.
  bool _isCoveredByOtherRoute = false;

  @override
  void initState() {
    super.initState();
    // autoStart: false. Bila true, MobileScanner memanggil start() di tengah
    // fase build dan mengubah `value` controller, padahal tombol senter di
    // AppBar ikut mendengarkan controller -> assert "setState() called during
    // build". start() manual di bawah menunggu widget terpasang dulu.
    _controller = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );
    // Karena controller kita berikan sendiri, widget MobileScanner TIDAK
    // memantau lifecycle app; layar ini yang menyalakan/mematikan kamera.
    WidgetsBinding.instance.addObserver(this);
    unawaited(_startCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Belum ada izin (atau dialog izin sedang tampil): jangan ikut campur.
    if (!_controller.value.hasCameraPermission || _isCoveredByOtherRoute) {
      return;
    }
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_startCamera());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _startCamera() async {
    try {
      await _controller.start();
    } on MobileScannerException {
      // Kegagalan start (mis. izin ditolak) sudah tercatat di
      // `_controller.value.error` dan ditampilkan oleh `_buildCameraError`.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scannedValue != null) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    _isProcessing = true;
    // TODO(langkah 3): ganti dengan getLocationByQr(raw) + panel ruangan.
    setState(() => _scannedValue = raw);
    _isProcessing = false;
  }

  void _scanAgain() {
    setState(() => _scannedValue = null);
  }

  Future<void> _bukaFormLaporan(CampusLocation location) async {
    // Matikan kamera selama form terbuka agar tidak menyala di belakang layar.
    _isCoveredByOtherRoute = true;
    await _controller.stop();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CreateReportScreen(user: widget.user, location: location),
      ),
    );
    if (!mounted) return;

    _isCoveredByOtherRoute = false;
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai QR ruangan'),
        actions: [_TorchButton(controller: _controller)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildScanner()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _scannedValue == null
                  ? _buildHint()
                  : _buildScannedPanel(_scannedValue!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = Theme.of(context).colorScheme;
        // Bingkai bidik persegi di tengah. Rect yang sama dipakai untuk
        // overlay DAN scanWindow, jadi QR di luar bingkai tidak ikut terbaca.
        final side = constraints.biggest.shortestSide * 0.7;
        final scanWindow = Rect.fromCenter(
          center: constraints.biggest.center(Offset.zero),
          width: side,
          height: side,
        );
        return MobileScanner(
          controller: _controller,
          scanWindow: scanWindow,
          onDetect: _onDetect,
          placeholderBuilder: (context) => ColoredBox(
            color: colorScheme.surfaceContainerHighest,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorBuilder: _buildCameraError,
          overlayBuilder: (context, _) => ScanWindowOverlay(
            controller: _controller,
            scanWindow: scanWindow,
            borderColor: colorScheme.primary,
            borderWidth: 4,
            borderRadius: BorderRadius.circular(16),
            color: colorScheme.scrim.withValues(alpha: 0.5),
          ),
        );
      },
    );
  }

  Widget _buildCameraError(BuildContext context, MobileScannerException error) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPermission =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Izin kamera ditolak. Izinkan kamera di Pengaturan > Aplikasi > '
            'SiFasilitas > Izin, lalu tekan "Coba lagi".',
      MobileScannerErrorCode.unsupported =>
        'Perangkat ini tidak memiliki kamera yang bisa dipakai untuk memindai.',
      _ => 'Kamera tidak dapat dibuka. Silakan coba lagi.',
    };
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPermission ? Icons.no_photography_outlined : Icons.error,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    );
  }

  // TODO(langkah 3): ganti isi panel dengan data ruangan hasil getLocationByQr.
  Widget _buildScannedPanel(String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QR terbaca: $value',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _scanAgain,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Pindai lagi'),
        ),
      ],
    );
  }
}

/// Tombol senter di AppBar. Membaca `torchState` langsung dari controller
/// (ValueNotifier milik paket), jadi tidak perlu disalin ke setState.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final isOn = state.torchState == TorchState.on;
        final available =
            state.isRunning && state.torchState != TorchState.unavailable;
        return IconButton(
          tooltip: isOn ? 'Matikan senter' : 'Nyalakan senter',
          icon: Icon(isOn ? Icons.flash_on : Icons.flash_off),
          onPressed: available ? controller.toggleTorch : null,
        );
      },
    );
  }
}
