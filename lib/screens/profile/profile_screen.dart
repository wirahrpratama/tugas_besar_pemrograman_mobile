import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.uid});

  final String uid;

  static const _roleLabels = {
    UserRole.pelapor: 'Pelapor',
    UserRole.admin: 'Admin Fasilitas',
    UserRole.teknisi: 'Teknisi',
  };

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _editNama(BuildContext context, AppUser user) async {
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final newNama = await showDialog<String>(
      context: context,
      builder: (_) => _EditNamaDialog(initialNama: user.nama),
    );
    if (newNama == null || newNama.trim() == user.nama) return;
    try {
      await auth.updateNama(uid, newNama);
      messenger.showSnackBar(const SnackBar(content: Text('Nama diperbarui.')));
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthService>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: StreamBuilder<AppUser?>(
        stream: auth.watchAppUser(uid),
        builder: (context, snap) {
          final user = snap.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final theme = Theme.of(context);
          final identityLabel = user.role == UserRole.pelapor
              ? Validators.identityLabel(user.subRole)
              : 'NIP / ID Pegawai';
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Text(
                    user.nama.isEmpty ? '?' : user.nama[0].toUpperCase(),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nama'),
                subtitle: Text(user.nama),
                trailing: IconButton(
                  tooltip: 'Ubah nama',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editNama(context, user),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.numbers),
                title: Text(identityLabel),
                subtitle: Text(
                  user.identityNumber.isEmpty ? '-' : user.identityNumber,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user.email),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Peran'),
                subtitle: Text(
                  user.role == UserRole.pelapor
                      ? '${_roleLabels[user.role]} (${_capitalize(user.subRole)})'
                      : _roleLabels[user.role]!,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Keluar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditNamaDialog extends StatefulWidget {
  const _EditNamaDialog({required this.initialNama});

  final String initialNama;

  @override
  State<_EditNamaDialog> createState() => _EditNamaDialogState();
}

class _EditNamaDialogState extends State<_EditNamaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialNama);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Nama'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          validator: Validators.nama,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
