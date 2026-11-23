import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Pengganti plugin kamera native untuk widget test.
///
/// Di test tidak ada kamera/plugin native, jadi tanpa ini `MobileScanner`
/// gagal dengan MissingPluginException. Pasang lewat
/// `MobileScannerPlatform.instance = FakeScannerPlatform();`.
class FakeScannerPlatform extends MobileScannerPlatform {
  FakeScannerPlatform({this.startError});

  /// Bila diisi, `start()` melempar exception ini (mis. izin ditolak).
  MobileScannerException? startError;

  final _barcodes = StreamController<BarcodeCapture?>.broadcast();
  final _torch = StreamController<TorchState>.broadcast();
  final _zoom = StreamController<double>.broadcast();

  int startCalls = 0;
  int stopCalls = 0;

  /// Simulasikan kamera membaca QR berisi [rawValue].
  void emitQr(String rawValue) {
    _barcodes.add(
      BarcodeCapture(
        barcodes: [Barcode(rawValue: rawValue, format: BarcodeFormat.qrCode)],
      ),
    );
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    final error = startError;
    if (error != null) throw error;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(480, 640),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> pause() async {}

  @override
  Future<void> toggleTorch() async {}

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Future<void> setFocusPoint(Offset position) async {}

  @override
  Widget buildCameraView() => const SizedBox(width: 480, height: 640);

  @override
  Future<void> dispose() async {}
}
