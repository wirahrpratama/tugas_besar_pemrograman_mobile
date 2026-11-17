import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/photo_store.dart';

/// Menampilkan foto laporan dari referensi `"photo:{photoId}"` (via [PhotoStore])
/// atau URL gambar biasa (`http`/`https`).
class ReportPhoto extends StatefulWidget {
  const ReportPhoto({
    super.key,
    required this.ref,
    this.photoStore,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String ref;
  final PhotoStore? photoStore;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<ReportPhoto> {
  Future<Uint8List>? _photoFuture;
  PhotoStore? _resolvedStore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = _findStore();
    if (_photoFuture == null || !identical(store, _resolvedStore)) {
      _resolvedStore = store;
      _startLoadIfNeeded();
    }
  }

  @override
  void didUpdateWidget(covariant ReportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    final store = _findStore();
    if (oldWidget.ref != widget.ref || !identical(store, _resolvedStore)) {
      _resolvedStore = store;
      _startLoadIfNeeded();
    }
  }

  PhotoStore _findStore() {
    if (widget.photoStore != null) return widget.photoStore!;
    try {
      return context.read<PhotoStore>();
    } on ProviderNotFoundException {
      return FirestorePhotoStore.shared;
    }
  }

  void _startLoadIfNeeded() {
    if (PhotoStore.isPhotoRef(widget.ref)) {
      _photoFuture = _resolvedStore!.loadPhoto(widget.ref);
    } else {
      _photoFuture = null;
    }
  }

  Widget _wrapClip(Widget child) {
    final radius = widget.borderRadius;
    if (radius == null) return child;
    return ClipRRect(borderRadius: radius, child: child);
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  Widget _buildError() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        );
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.ref.trim();
    if (trimmed.isEmpty) {
      return _wrapClip(_buildError());
    }

    if (!PhotoStore.isPhotoRef(trimmed)) {
      final uri = Uri.tryParse(trimmed);
      final isHttp = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      if (!isHttp) {
        return _wrapClip(_buildError());
      }
      return _wrapClip(
        Image.network(
          trimmed,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _buildPlaceholder();
          },
          errorBuilder: (_, __, ___) => _buildError(),
        ),
      );
    }

    return _wrapClip(
      FutureBuilder<Uint8List>(
        future: _photoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildPlaceholder();
          }
          final bytes = snapshot.data;
          if (snapshot.hasError || bytes == null || bytes.isEmpty) {
            return _buildError();
          }
          return Image.memory(
            bytes,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => _buildError(),
          );
        },
      ),
    );
  }
}
