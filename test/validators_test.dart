import 'package:flutter_test/flutter_test.dart';

import 'package:sifasilitas/utils/validators.dart';

void main() {
  group('Validators.emailKampus', () {
    test('menerima domain kampus USU', () {
      expect(Validators.emailKampus('leondo@students.usu.ac.id'), isNull);
      expect(Validators.emailKampus(' Dosen@USU.ac.id '), isNull);
    });

    test('menolak domain lain atau domain tiruan', () {
      expect(Validators.emailKampus('leondo@gmail.com'), isNotNull);
      expect(Validators.emailKampus('a@fake-usu.ac.id'), isNotNull);
      expect(
        Validators.emailKampus('a@students.usu.ac.id.evil.com'),
        isNotNull,
      );
    });

    test('menolak email kosong atau format salah', () {
      expect(Validators.emailKampus(''), 'Email wajib diisi.');
      expect(
        Validators.emailKampus('bukan-email'),
        'Format email tidak valid.',
      );
    });
  });

  group('Validators.identityNumber', () {
    test('NIM mahasiswa harus 9 digit angka', () {
      expect(Validators.identityNumber('241402053', 'mahasiswa'), isNull);
      expect(
        Validators.identityNumber('24140205', 'mahasiswa'),
        'NIM harus 9 digit.',
      );
      expect(
        Validators.identityNumber('24140205a', 'mahasiswa'),
        'NIM hanya boleh berisi angka.',
      );
      expect(Validators.identityNumber('', 'mahasiswa'), 'NIM wajib diisi.');
    });

    test('NIP dosen/staf harus 18 digit angka', () {
      expect(Validators.identityNumber('198001012005011001', 'dosen'), isNull);
      expect(Validators.identityNumber('198001012005011001', 'staf'), isNull);
      expect(
        Validators.identityNumber('241402053', 'dosen'),
        'NIP harus 18 digit.',
      );
    });
  });

  group('Validators.password', () {
    test('menerima kombinasi huruf dan angka minimal 8 karakter', () {
      expect(Validators.password('abc12345'), isNull);
    });

    test('menolak password lemah', () {
      expect(Validators.password(''), 'Password wajib diisi.');
      expect(Validators.password('ab1'), 'Password minimal 8 karakter.');
      expect(
        Validators.password('abcdefgh'),
        'Password harus kombinasi huruf dan angka.',
      );
      expect(
        Validators.password('12345678'),
        'Password harus kombinasi huruf dan angka.',
      );
    });

    test('konfirmasi password harus sama', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(
        Validators.confirmPassword('abc12346', 'abc12345'),
        'Konfirmasi password tidak sama.',
      );
    });
  });

  group('Validators.nama', () {
    test('minimal 3 karakter setelah trim', () {
      expect(Validators.nama('Leondo Admiral Purba'), isNull);
      expect(Validators.nama('  Al '), 'Nama minimal 3 karakter.');
      expect(Validators.nama(''), 'Nama wajib diisi.');
    });
  });
}
