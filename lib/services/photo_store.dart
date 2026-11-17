import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

typedef PhotoCompressor = Future<Uint8List?> Function(
  File file, {
  required int minWidth,
  required int minHeight,
  required int quality,
});

/// Abstraksi penyimpanan foto laporan agar UI tidak bergantung langsung pada
/// detail implementasi penyimpanan (Firestore base64 / Storage).
abstract class PhotoStore {
  static const String prefix = 'photo:';
  static const int maxBytes = 200 * 1024; // 200 KB
  static const int maxDimensionPx = 1024;
  static const int defaultQuality = 60;

  static bool isPhotoRef(String? ref) =>
      ref != null && photoIdFromRef(ref) != null;

  static String? photoIdFromRef(String ref) {
    final trimmed = ref.trim();
    if (!trimmed.startsWith(prefix)) return null;
    final id = trimmed.substring(prefix.length).trim();
    return id.isEmpty ? null : id;
  }

  /// Mengompres dan menyimpan [file], mengembalikan referensi `"photo:{photoId}"`.
  Future<String> uploadPhoto(File file);

  /// Mengambil byte gambar dari referensi `"photo:{photoId}"`.
  Future<Uint8List> loadPhoto(String ref);
}

/// Implementasi [PhotoStore] yang menyimpan gambar terkompresi sebagai base64
/// di koleksi Firestore `report_photos/{photoId}` beserta cache memori.
class FirestorePhotoStore implements PhotoStore {
  FirestorePhotoStore({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    PhotoCompressor? compressor,
    int maxCacheEntries = 50,
  })  : _dbOverride = firestore,
        _authOverride = auth,
        _compressorOverride = compressor,
        _maxCacheEntries = maxCacheEntries;

  static FirestorePhotoStore? _shared;
  static FirestorePhotoStore get shared => _shared ??= FirestorePhotoStore();

  static const List<int> _qualitySteps = [60, 45, 35, 25];

  final FirebaseFirestore? _dbOverride;
  final FirebaseAuth? _authOverride;
  final PhotoCompressor? _compressorOverride;
  final int _maxCacheEntries;

  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  void clearCache() => _cache.clear();

  @override
  Future<String> uploadPhoto(File file) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        '401 Unauthorized: Pengguna harus login sebelum mengunggah foto.',
      );
    }

    final bytes = await _compressUnderLimit(file);
    final docRef = _db.collection('report_photos').doc();
    await docRef.set({
      'data_base64': base64Encode(bytes),
      'mime_type': 'image/jpeg',
      'owner_uid': uid,
      'created_at': FieldValue.serverTimestamp(),
    });

    _putCache(docRef.id, bytes);
    return '${PhotoStore.prefix}${docRef.id}';
  }

  @override
  Future<Uint8List> loadPhoto(String ref) {
    final photoId = PhotoStore.photoIdFromRef(ref);
    if (photoId == null) {
      return Future<Uint8List>.error(
        ArgumentError.value(ref, 'ref', 'Referensi foto tidak valid.'),
      );
    }

    final cached = _cache.remove(photoId);
    if (cached != null) {
      _cache[photoId] = cached;
      return Future<Uint8List>.value(cached);
    }

    final pending = _inFlight[photoId];
    if (pending != null) return pending;

    final future = _fetchAndDecode(photoId);
    _inFlight[photoId] = future;
    return future.whenComplete(() => _inFlight.remove(photoId));
  }

  Future<Uint8List> _fetchAndDecode(String photoId) async {
    final snap = await _db.collection('report_photos').doc(photoId).get();
    final data = snap.data();
    if (!snap.exists || data == null) {
      throw StateError('Foto $photoId tidak ditemukan.');
    }
    final encoded = data['data_base64'];
    if (encoded is! String || encoded.isEmpty) {
      throw FormatException('Data base64 foto $photoId kosong atau tidak valid.');
    }
    final bytes = base64Decode(encoded);
    _putCache(photoId, bytes);
    return bytes;
  }

  Future<Uint8List> _compressUnderLimit(File file) async {
    final compressor = _compressorOverride ?? _defaultCompressor;
    final dims = _compressorOverride != null
        ? (PhotoStore.maxDimensionPx, PhotoStore.maxDimensionPx)
        : await _resolveTargetDimensions(file);

    Uint8List? best;
    for (final quality in _qualitySteps) {
      final result = await compressor(
        file,
        minWidth: dims.$1,
        minHeight: dims.$2,
        quality: quality,
      );
      if (result == null || result.isEmpty) continue;
      best = result;
      if (result.length < PhotoStore.maxBytes) {
        return result;
      }
    }

    if (best == null || best.isEmpty) {
      throw StateError('Gagal memproses atau mengompres file foto.');
    }
    throw StateError(
      'Ukuran foto setelah kompresi (${(best.length / 1024).ceil()} KB) '
      'melebihi batas maksimal 200 KB.',
    );
  }

  Future<Uint8List?> _defaultCompressor(
    File file, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    if (!await file.exists()) {
      throw ArgumentError('File foto tidak ditemukan: ${file.path}');
    }
    return FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
  }

  Future<(int, int)> _resolveTargetDimensions(File file) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      if (w <= 0 || h <= 0) {
        return (PhotoStore.maxDimensionPx, PhotoStore.maxDimensionPx);
      }
      const maxDim = PhotoStore.maxDimensionPx;
      if (w <= maxDim && h <= maxDim) {
        return (w, h);
      }
      if (w >= h) {
        return (maxDim, math.max(1, (h * maxDim / w).round()));
      }
      return (math.max(1, (w * maxDim / h).round()), maxDim);
    } catch (_) {
      return (PhotoStore.maxDimensionPx, PhotoStore.maxDimensionPx);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _putCache(String photoId, Uint8List bytes) {
    if (_maxCacheEntries <= 0) return;
    _cache.remove(photoId);
    _cache[photoId] = bytes;
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}
