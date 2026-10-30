/// Validator form autentikasi. Mengembalikan pesan error, atau `null` jika valid.
class Validators {
  Validators._();

  static const allowedEmailDomains = ['usu.ac.id', 'students.usu.ac.id'];
  static const nimLength = 9;
  static const nipLength = 18;
  static const minPasswordLength = 8;

  static final _emailPattern = RegExp(r'^[^@\s]+@([^@\s]+\.[^@\s]+)$');
  static final _digitsOnly = RegExp(r'^\d+$');
  static final _hasLetter = RegExp(r'[A-Za-z]');
  static final _hasDigit = RegExp(r'\d');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
    return null;
  }

  static String? nama(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nama wajib diisi.';
    if (v.length < 3) return 'Nama minimal 3 karakter.';
    if (v.length > 100) return 'Nama maksimal 100 karakter.';
    return null;
  }

  /// Validasi format email saja (dipakai untuk login & lupa password).
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email wajib diisi.';
    if (!_emailPattern.hasMatch(v)) return 'Format email tidak valid.';
    return null;
  }

  /// Validasi email kampus USU (dipakai saat registrasi).
  static String? emailKampus(String? value) {
    final formatError = email(value);
    if (formatError != null) return formatError;
    final domain = _emailPattern
        .firstMatch(value!.trim().toLowerCase())!
        .group(1);
    if (!allowedEmailDomains.contains(domain)) {
      return 'Gunakan email kampus (@students.usu.ac.id atau @usu.ac.id).';
    }
    return null;
  }

  static String identityLabel(String subRole) =>
      subRole == 'mahasiswa' ? 'NIM' : 'NIP';

  static int identityLength(String subRole) =>
      subRole == 'mahasiswa' ? nimLength : nipLength;

  /// NIM untuk mahasiswa, NIP untuk dosen/staf.
  static String? identityNumber(String? value, String subRole) {
    final v = value?.trim() ?? '';
    final label = identityLabel(subRole);
    if (v.isEmpty) return '$label wajib diisi.';
    if (!_digitsOnly.hasMatch(v)) return '$label hanya boleh berisi angka.';
    final expected = identityLength(subRole);
    if (v.length != expected) return '$label harus $expected digit.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password wajib diisi.';
    if (v.length < minPasswordLength) {
      return 'Password minimal $minPasswordLength karakter.';
    }
    if (!_hasLetter.hasMatch(v) || !_hasDigit.hasMatch(v)) {
      return 'Password harus kombinasi huruf dan angka.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi.';
    }
    if (value != original) return 'Konfirmasi password tidak sama.';
    return null;
  }
}
