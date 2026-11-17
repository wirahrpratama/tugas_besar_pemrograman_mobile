import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import 'role_home_scaffold.dart';

class PelaporHome extends StatelessWidget {
  const PelaporHome({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      user: user,
      title: 'Beranda Pelapor',
      icon: Icons.report_outlined,
      placeholderText:
          'Fitur buat laporan (M2) dan riwayat laporan (M3) akan tampil di sini.',
    );
  }
}
