import 'package:flutter/material.dart';

import '../../theme/app_icon_size.dart';
import '../../theme/app_spacing.dart';

/// Kerangka layout konsisten untuk seluruh halaman autentikasi.
///
/// Menyediakan SafeArea, scroll, padding [AppSpacing.paddingAllXl], dan
/// lebar maksimum 420 agar form auth seragam di semua layar.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, this.appBar, required this.child});

  final PreferredSizeWidget? appBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingAllXl,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Header halaman auth: ikon brand, judul, dan subtitle opsional.
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: AppIconSize.large, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
