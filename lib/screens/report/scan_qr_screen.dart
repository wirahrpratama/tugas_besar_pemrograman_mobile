import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/report_repository.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';
import 'create_report_screen.dart';

/// Layar pindai QR ruangan.
///
/// Kamera + bingkai bidik + senter + penanganan izin kamera. Isi QR dicocokkan
/// ke master `locations` lewat [ReportRepository.getLocationByQr]; bila cocok,
/// panel ruangan tampil dengan tombol "Lanjut buat laporan".
class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen>
    with WidgetsBindingObserver {
  /// Lama QR yang ditolak diabaikan, supaya QR asing yang masih di depan
  /// kamera tidak memicu SnackBar dan query Firestore berulang-ulang.
  static const _rejectCooldown = Duration(seconds: 3);

  // Controller memegang sesi kamera native, jadi dibuat sekali di initState
  // dan wajib dibebaskan di dispose (sama seperti TextEditingController).
  late final MobileScannerController _controller;

  /// Kunci agar satu QR tidak diproses berkali-kali: `onDetect` bisa
  /// terpanggil beruntun selama QR yang sama masih di depan kamera, dan
  /// kunci ini menahan deteksi baru selama `await getLocationByQr` berjalan.
  bool _isProcessing = false;

  /// Ruangan hasil pencocokan QR. Selama tidak null, panel ruangan tampil dan
  /// deteksi baru diabaikan sampai pengguna menekan "Pindai lagi".
  CampusLocation? _foundLocation;

  /// Isi QR yang baru saja ditolak (tidak dikenal atau gagal diperiksa).
  /// Diabaikan selama [_rejectCooldown], lalu dihapus oleh [_rejectTimer].
  String? _rejectedValue;
  Timer? _rejectTimer;

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
    _rejectTimer?.cancel();
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _foundLocation != null) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty || raw == _rejectedValue) return;

    // Ambil service SEBELUM await: setelah await, context belum tentu masih
    // terpasang (lint use_build_context_synchronously).
    final repo = context.read<ReportRepository>();
    setState(() => _isProcessing = true);

    CampusLocation? location;
    String? errorMessage;
    try {
      location = await repo.getLocationByQr(raw);
      if (location == null) {
        errorMessage = 'QR tidak dikenali sebagai ruangan kampus.';
      }
    } on Exception {
      // Jaringan putus, izin Firestore ditolak, dsb. Jangan tampilkan detail
      // teknis ke pengguna.
      errorMessage =
          'Gagal memeriksa QR. Periksa koneksi internet lalu coba lagi.';
    }
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _foundLocation = location;
    });
    final messenger = ScaffoldMessenger.of(context);
    // SnackBar penolakan sebelumnya ditutup agar tidak menutupi tombol panel.
    messenger.hideCurrentSnackBar();
    if (errorMessage != null) {
      _rejectTemporarily(raw);
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _rejectTemporarily(String value) {
    _rejectTimer?.cancel();
    _rejectedValue = value;
    // Tidak perlu setState: nilai ini tidak ditampilkan, hanya dipakai filter.
    _rejectTimer = Timer(_rejectCooldown, () => _rejectedValue = null);
  }

  void _scanAgain() {
    setState(() => _foundLocation = null);
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

    // Kembali dari form (mis. tombol "Ubah" lokasi) berarti pengguna ingin
    // memilih ruangan lain, jadi panel lama ditutup dan pemindaian dimulai lagi.
    _isCoveredByOtherRoute = false;
    setState(() => _foundLocation = null);
    await _startCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Pindai QR ruangan',
        profileUid: widget.user.uid,
        userName: widget.user.nama,
        photoUrl: widget.user.photoUrl,
        extraActions: [_TorchButton(controller: _controller)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildScanner(),
                const Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.md,
                  child: AppBackButton(),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (_foundLocation) {
                final location? => _LocationPanel(
                  location: location,
                  onContinue: () => _bukaFormLaporan(location),
                  onScanAgain: _scanAgain,
                ),
                null => _buildHint(),
              },
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
          onDetect: (capture) => unawaited(_onDetect(capture)),
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
    if (_isProcessing) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Memeriksa QR…'),
        ],
      );
    }
    return const Text(
      'Arahkan kamera ke QR Code di pintu ruangan atau stiker aset.',
      textAlign: TextAlign.center,
    );
  }
}

/// Panel bawah setelah QR cocok dengan ruangan kampus.
class _LocationPanel extends StatelessWidget {
  const _LocationPanel({
    required this.location,
    required this.onContinue,
    required this.onScanAgain,
  });

  final CampusLocation location;
  final VoidCallback onContinue;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.meeting_room_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(location.namaRuangan, style: textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${location.kodeRuangan} · ${location.namaGedung} · '
          'Lantai ${location.lantai}',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: onContinue,
          child: const Text('Lanjut buat laporan'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: onScanAgain,
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
