import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/app_button.dart';

/// Tampilan bagian "Foto kerusakan": pratinjau atau area kosong, dua tombol
/// sumber foto, lalu teks bantu atau pesan error.
///
/// Hanya tampilan. Membuka picker, menyimpan foto, dan validasi ada di
/// layar form; widget ini menerima hasilnya lewat parameter.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.foto,
    required this.busy,
    required this.errorText,
    required this.onPick,
  });

  final XFile? foto;

  /// True selama picker terbuka: tombol dinonaktifkan agar tidak dobel.
  final bool busy;

  /// Pesan dari validator `FormField`; null bila tidak ada error.
  final String? errorText;

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = errorText;
    final foto = this.foto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? colorScheme.error
                  : colorScheme.outlineVariant,
              width: error != null ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              height: 200,
              child: foto == null
                  ? _EmptyPhoto(colorScheme: colorScheme)
                  : _Preview(path: foto.path),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Ditumpuk vertikal, lebar penuh: AppButton tidak memotong label,
        // jadi dua tombol berdampingan overflow di HP 360 dp (terlebih bila
        // ukuran huruf sistem diperbesar). Dibuktikan oleh test 360 dp.
        AppButton(
          variant: AppButtonVariant.outline,
          icon: Icons.photo_camera_outlined,
          label: foto == null ? 'Ambil foto' : 'Ambil ulang',
          onPressed: busy ? null : () => onPick(ImageSource.camera),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          variant: AppButtonVariant.outline,
          icon: Icons.photo_library_outlined,
          label: 'Pilih dari galeri',
          onPressed: busy ? null : () => onPick(ImageSource.gallery),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Error memakai ikon + teks, bukan hanya warna bingkai (slide 26).
        if (error != null)
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: colorScheme.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            'Foto dikompres otomatis saat dikirim.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Belum ada foto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // cacheWidth: foto kamera bisa 4000 px lebih. Gambar didekode
        // seukuran tampilan saja supaya hemat memori; file aslinya TIDAK
        // diubah (kompresi tetap tugas PhotoStore saat upload).
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = (constraints.maxWidth * dpr).round();
        Widget gagal(BuildContext context, Object _, StackTrace? _) =>
            ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: Text(
                  'Pratinjau tidak dapat ditampilkan. Coba ambil ulang.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
        // Image.file tidak didukung di Flutter Web; di web `XFile.path`
        // berupa URL blob sehingga dibuka dengan Image.network (anjuran
        // dokumentasi image_picker). Target utama tetap Android.
        return kIsWeb
            ? Image.network(
                path,
                key: const ValueKey('foto-pratinjau'),
                width: double.infinity,
                height: constraints.maxHeight,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                semanticLabel: 'Pratinjau foto kerusakan',
                errorBuilder: gagal,
              )
            : Image.file(
                File(path),
                key: const ValueKey('foto-pratinjau'),
                width: double.infinity,
                height: constraints.maxHeight,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                semanticLabel: 'Pratinjau foto kerusakan',
                errorBuilder: gagal,
              );
      },
    );
  }
}
