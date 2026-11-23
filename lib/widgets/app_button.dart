import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_theme.dart';

/// Varian visual [AppButton].
enum AppButtonVariant { primary, secondary, outline, danger, text }

/// Tombol reusable SiFasilitas.
///
/// Membungkus `FilledButton`/`OutlinedButton`/`TextButton` Material dengan
/// gaya yang konsisten (tinggi minimum 48, sudut 10, font Poppins) dan
/// mendukung state loading.
///
/// Contoh:
/// ```dart
/// AppButton(label: 'Masuk', onPressed: _submit, loading: _loading)
/// AppButton(label: 'Batal', variant: AppButtonVariant.outline, onPressed: _cancel)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  bool get _enabled => !loading && onPressed != null;

  Widget _label() {
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label),
                ],
              )
            : Text(label);
    return Center(child: child);
  }

  ButtonStyle _style(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    return switch (variant) {
      AppButtonVariant.danger => FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(48),
          shape: shape,
          textStyle: AppTextTheme.theme.labelLarge,
        ),
      AppButtonVariant.secondary => FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          shape: shape,
          textStyle: AppTextTheme.theme.labelLarge,
        ),
      AppButtonVariant.outline => OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: shape,
          textStyle: AppTextTheme.theme.labelLarge,
        ),
      AppButtonVariant.text => TextButton.styleFrom(
          textStyle: AppTextTheme.theme.labelLarge,
        ),
      AppButtonVariant.primary => FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: shape,
          textStyle: AppTextTheme.theme.labelLarge,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final child = _label();
    final onTap = _enabled ? onPressed : null;

    final Widget button = switch (variant) {
      AppButtonVariant.outline => OutlinedButton(
          onPressed: onTap,
          style: _style(context),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: onTap,
          style: _style(context),
          child: child,
        ),
      _ => FilledButton(
          onPressed: onTap,
          style: _style(context),
          child: child,
        ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
