import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/loading_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _subRoleLabels = {
    'mahasiswa': 'Mahasiswa',
    'dosen': 'Dosen',
    'staf': 'Staf',
  };

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _identityController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _subRole = AuthService.pelaporSubRoles.first;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _identityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<AuthService>().register(
        nama: _namaController.text,
        identityNumber: _identityController.text,
        email: _emailController.text,
        password: _passwordController.text,
        subRole: _subRole,
      );
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Akun berhasil dibuat. Cek email kampus Anda untuk verifikasi.',
          ),
        ),
      );
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identityLabel = Validators.identityLabel(_subRole);
    final passwordToggle = IconButton(
      tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun Pelapor')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _namaController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Nama Lengkap',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: Validators.nama,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _subRole,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: [
                          for (final role in AuthService.pelaporSubRoles)
                            DropdownMenuItem(
                              value: role,
                              child: Text(_subRoleLabels[role] ?? role),
                            ),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _subRole = value);
                              },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _identityController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            Validators.identityLength(_subRole),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: identityLabel,
                          helperText:
                              '${Validators.identityLength(_subRole)} digit angka',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        validator: (v) =>
                            Validators.identityNumber(v, _subRole),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email Kampus',
                          helperText: '@students.usu.ac.id atau @usu.ac.id',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: Validators.emailKampus,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText:
                              'Minimal ${Validators.minPasswordLength} karakter, kombinasi huruf dan angka',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: passwordToggle,
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Konfirmasi Password',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (v) => Validators.confirmPassword(
                          v,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 24),
                      LoadingButton(
                        label: 'Daftar',
                        loading: _loading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
