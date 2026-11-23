import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../theme/app_spacing.dart';
import '../profile/profile_screen.dart';

/// Kerangka sementara beranda tiap peran sampai modul M2–M4 mengisinya.
class RoleHomeScaffold extends StatelessWidget {
  const RoleHomeScaffold({
    super.key,
    required this.user,
    required this.title,
    required this.icon,
    required this.placeholderText,
    this.extraContent = const <Widget>[],
  });

  final AppUser user;
  final String title;
  final IconData icon;
  final String placeholderText;

  /// Widget tambahan di bawah teks placeholder (mis. aksi khusus peran).
  final List<Widget> extraContent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingAllXl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.lg),
              Text('Halo, ${user.nama}', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(placeholderText, textAlign: TextAlign.center),
              ...extraContent,
            ],
          ),
        ),
      ),
    );
  }
}
