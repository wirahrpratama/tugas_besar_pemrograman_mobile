import 'package:flutter_test/flutter_test.dart';
import 'package:sifasilitas/services/firebase_seeder.dart';

void main() {
  group('FirebaseSeeder.categoryData', () {
    test('berisi 6 kategori dengan id unik sesuai AiClassifierService', () {
      final ids = FirebaseSeeder.categoryData.map((c) => c['id']).toSet();
      expect(FirebaseSeeder.categoryData, hasLength(6));
      expect(ids, {
        'cat_ac',
        'cat_proyektor',
        'cat_jaringan',
        'cat_lampu',
        'cat_toilet',
        'cat_ruang_kelas',
      });
    });

    test('field lengkap dan nilai valid', () {
      const priorities = {'rendah', 'sedang', 'tinggi', 'darurat'};
      for (final c in FirebaseSeeder.categoryData) {
        expect(c['nama_objek'], isA<String>(), reason: '${c['id']}');
        expect(priorities, contains(c['prioritas_default']));
        expect(c['target_sla_jam'], isA<int>());
        expect(c['target_sla_jam'] as int, greaterThan(0));
      }
    });
  });

  group('FirebaseSeeder.locationData', () {
    test('berisi 10 lokasi dengan id dan kode_ruangan unik', () {
      final data = FirebaseSeeder.locationData;
      expect(data, hasLength(10));
      expect(data.map((l) => l['id']).toSet(), hasLength(10));
      expect(data.map((l) => l['kode_ruangan']).toSet(), hasLength(10));
    });

    test('field lengkap dan nilai valid', () {
      for (final l in FirebaseSeeder.locationData) {
        expect(l['kode_ruangan'], startsWith('QR-'), reason: '${l['id']}');
        expect(l['nama_gedung'], isA<String>());
        expect(l['nama_ruangan'], isA<String>());
        expect(l['lantai'], isA<int>());
        expect(l['lantai'] as int, greaterThan(0));
      }
    });
  });

  group('SeedResult', () {
    test('nothingToDo hanya true bila kedua koleksi dilewati', () {
      expect(
        const SeedResult(categoriesSeeded: 0, locationsSeeded: 0).nothingToDo,
        isTrue,
      );
      expect(
        const SeedResult(categoriesSeeded: 6, locationsSeeded: 0).nothingToDo,
        isFalse,
      );
      expect(
        const SeedResult(categoriesSeeded: 0, locationsSeeded: 10).nothingToDo,
        isFalse,
      );
    });
  });
}
