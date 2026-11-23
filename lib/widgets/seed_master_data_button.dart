import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import '../services/firebase_seeder.dart';
import '../theme/app_spacing.dart';

typedef SeedAction = Future<SeedResult> Function();

/// Aksi manual sekali jalan untuk admin: mengisi master data kategori dan
/// lokasi. Sengaja TIDAK dipanggil otomatis dari `main()`.
class SeedMasterDataButton extends StatefulWidget {
  const SeedMasterDataButton({
    super.key,
    this.onSeed,
    this.timeout = const Duration(seconds: 20),
  });

  /// Pengganti aksi seeding (untuk pengujian). Default: [FirebaseSeeder].
  final SeedAction? onSeed;

  /// Batas waktu seluruh proses seeding.
  final Duration timeout;

  @override
  State<SeedMasterDataButton> createState() => _SeedMasterDataButtonState();
}

class _SeedMasterDataButtonState extends State<SeedMasterDataButton> {
  bool _loading = false;

  Future<void> _seed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Isi Data Master?'),
        content: Text(
          'Aksi ini mengisi ${FirebaseSeeder.categoryData.length} kategori '
          'kerusakan dan ${FirebaseSeeder.locationData.length} lokasi/QR '
          'ruangan. Koleksi yang sudah berisi tidak akan diubah.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Isi Data'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    String message;
    try {
      final action =
          widget.onSeed ?? () => FirebaseSeeder().seedMasterDataIfNeeded();
      final result = await action().timeout(widget.timeout);
      message = _summary(result);
    } on TimeoutException {
      message = 'Waktu habis. Periksa koneksi internet lalu coba lagi.';
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          message =
              'Akses ditolak. Hanya akun admin yang boleh mengisi data master '
              '(pastikan firestore.rules terbaru sudah di-deploy).';
        case 'unavailable':
          message = 'Tidak ada koneksi ke server. Coba lagi saat online.';
        default:
          message = 'Gagal mengisi data master (${e.code}).';
      }
    } catch (_) {
      message = 'Gagal mengisi data master. Silakan coba lagi.';
    }

    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _summary(SeedResult result) {
    if (result.nothingToDo) {
      return 'Data master sudah lengkap. Tidak ada yang diubah.';
    }
    final categories = result.categoriesSeeded > 0
        ? '${result.categoriesSeeded} kategori ditambahkan'
        : 'kategori sudah ada';
    final locations = result.locationsSeeded > 0
        ? '${result.locationsSeeded} lokasi ditambahkan'
        : 'lokasi sudah ada';
    return 'Selesai: $categories, $locations.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _seed,
          icon: _loading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.dataset_outlined),
          label: const Text('Isi Data Master'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Aksi sekali jalan untuk mengisi kategori dan lokasi awal.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
