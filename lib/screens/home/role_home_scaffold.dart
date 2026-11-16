import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../profile/profile_screen.dart';

/// Kerangka sementara beranda tiap peran sampai modul M2–M4 mengisinya.
class RoleHomeScaffold extends StatelessWidget {
  const RoleHomeScaffold({
    super.key,
    required this.user,
    required this.title,
    required this.icon,
    required this.placeholderText,
  });

  final AppUser user;
  final String title;
  final IconData icon;
  final String placeholderText;

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Halo, ${user.nama}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(placeholderText, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
