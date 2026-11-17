import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import 'role_home_scaffold.dart';

class TeknisiDashboard extends StatelessWidget {
  const TeknisiDashboard({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      user: user,
      title: 'Tugas Teknisi',
      icon: Icons.engineering_outlined,
      placeholderText: 'Daftar tugas perbaikan (M4) akan tampil di sini.',
    );
  }
}
