import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/seed_master_data_button.dart';
import 'role_home_scaffold.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      user: user,
      title: 'Dashboard Admin',
      icon: Icons.admin_panel_settings_outlined,
      placeholderText:
          'Antrean tiket dan penugasan teknisi (M4) akan tampil di sini.',
      extraContent: const [SizedBox(height: AppSpacing.xxl), SeedMasterDataButton()],
    );
  }
}
