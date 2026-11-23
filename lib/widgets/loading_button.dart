import 'package:flutter/material.dart';

import 'app_button.dart';

/// [AppButton] varian primary dengan state loading.
///
/// Dipertahankan untuk kompatibilitas; untuk varian lain gunakan [AppButton]
/// secara langsung.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      loading: loading,
      onPressed: onPressed,
    );
  }
}
