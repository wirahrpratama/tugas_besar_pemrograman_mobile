import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sifasilitas/models/report_models.dart';
import 'package:sifasilitas/screens/report/create_report_screen.dart';
import 'package:sifasilitas/screens/report/report_submitted_screen.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:sifasilitas/services/ai_classifier_service.dart';
import 'package:sifasilitas/services/photo_store.dart';
import 'package:sifasilitas/services/report_service.dart';
import 'package:sifasilitas/widgets/loading_button.dart';
import 'package:sifasilitas/services/report_repository.dart';

import 'fake_ai_classifier.dart';
import 'fake_image_picker.dart';
import 'fake_photo_store.dart';
import 'fake_report_service.dart';
import 'fake_report_repository.dart';

const _user = AppUser(
  uid: 'u1',
  nama: 'Pelapor Uji',
  identityNumber: '241402000',
  email: 'uji@example.com',
  subRole: 'mahasiswa',
  role: UserRole.pelapor,
);

const _gda201 = CampusLocation(
  id: 'loc_gda_201',
  kodeRuangan: 'QR-GDA-201',
  namaGedung: 'Gedung A',
  namaRuangan: 'Ruang Kelas 201',
  lantai: 2,
);

const _kirim = 'Kirim laporan';
const _wajib = 'Deskripsi kerusakan wajib diisi.';
const _valid = 'Proyektor tidak menyala sejak Senin pagi.';
const _fotoWajib = 'Foto kerusakan wajib dilampirkan.';
const _kategoriWajib = 'Pilih fasilitas yang rusak.';

const _proyektor = FacilityCategory(
  id: 'cat_proyektor',
  namaObjek: 'Proyektor',
  prioritasDefault: 'tinggi',
  targetSlaJam: 4,
);
const _toilet = FacilityCategory(
  id: 'cat_toilet',
  namaObjek: 'Toilet',
  prioritasDefault: 'sedang',
  targetSlaJam: 8,
);
const _lampu = FacilityCategory(
  id: 'cat_lampu',
  namaObjek: 'Lampu',
  prioritasDefault: 'darurat',
  targetSlaJam: 2,
);

void main() {
  late FakeImagePicker picker;
  late FakeReportRepository repo;
  late FakeAiClassifier ai;
  late FakePhotoStore photos;
  late FakeReportService service;

  setUp(() {
    // Path tidak harus ada: pratinjau gagal dimuat ditangani errorBuilder.
    picker = FakeImagePicker()..hasil = XFile('/tmp/sifasilitas_uji.jpg');
    repo = FakeReportRepository()
      ..categories = const [_lampu, _proyektor, _toilet];
    ai = FakeAiClassifier();
    photos = FakePhotoStore();
    service = FakeReportService();
  });

  /// Form dibuka dari halaman awal ("pemindai" palsu), supaya pop bisa diuji.
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ImagePicker>.value(value: picker),
          Provider<ReportRepository>.value(value: repo),
          Provider<AiClassifierService>.value(value: ai),
          Provider<PhotoStore>.value(value: photos),
          Provider<ReportService>.value(value: service),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateReportScreen(
                      user: _user,
                      location: _gda201,
                    ),
                  ),
                ),
                child: const Text('pemindai'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pemindai'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKirim(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_kirim));
    await tester.tap(find.text(_kirim));
    await tester.pumpAndSettle();
  }

  Finder deskripsi() => find.byType(TextFormField);

  Future<void> tapTombol(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Finder pratinjau() => find.byKey(const ValueKey('foto-pratinjau'));

  /// Tekan "Selesai" di keyboard: field deskripsi kehilangan fokus, sama
  /// seperti di HP, sehingga saran AI otomatis diminta.
  Future<void> selesaiMengetik(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> pilihKategori(WidgetTester tester, String nama) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(nama).last);
    await tester.pumpAndSettle();
  }

  testWidgets('kartu lokasi, teks bantu, dan penghitung tampil', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Ruang Kelas 201'), findsOneWidget);
    expect(find.text('Gedung A · QR-GDA-201 · Lantai 2'), findsOneWidget);
    expect(
      find.text(
        'Jelaskan apa yang rusak dan sejak kapan. Jangan tulis data pribadi '
        '(nama, NIM, nomor HP).',
      ),
      findsOneWidget,
    );
    expect(find.text('0/500'), findsOneWidget);
  });

  testWidgets('error belum tampil sebelum submit', (tester) async {
    await pumpForm(tester);

    await tester.enterText(deskripsi(), 'rusak');
    await tester.pumpAndSettle();

    expect(find.textContaining('minimal 15 karakter'), findsNothing);
  });

  testWidgets(
    'submit kosong menampilkan error teks; hilang setelah diperbaiki',
    (tester) async {
      await pumpForm(tester);

      await tapKirim(tester);
      expect(find.text(_wajib), findsOneWidget);
      expect(find.byType(ReportSubmittedScreen), findsNothing);

      // Setelah submit gagal, validasi berjalan tiap kali mengetik.
      await tester.enterText(deskripsi(), 'Lampu mati');
      await tester.pumpAndSettle();
      expect(
        find.text('Deskripsi minimal 15 karakter (sekarang 10).'),
        findsOneWidget,
      );

      await tester.enterText(deskripsi(), _valid);
      await tester.pumpAndSettle();
      expect(find.textContaining('Deskripsi minimal'), findsNothing);
      expect(find.text(_wajib), findsNothing);
    },
  );

  testWidgets('foto + deskripsi valid membuka layar hasil', (tester) async {
    await pumpForm(tester);

    await tapTombol(tester, 'Ambil foto');
    await tester.enterText(deskripsi(), _valid);
    await selesaiMengetik(tester);
    await tapKirim(tester);

    expect(find.byType(ReportSubmittedScreen), findsOneWidget);
    expect(find.byType(CreateReportScreen), findsNothing);
  });

  testWidgets('back saat form kosong langsung keluar', (tester) async {
    await pumpForm(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CreateReportScreen), findsNothing);
  });

  testWidgets(
    'back saat terisi minta konfirmasi; Lanjut mengisi tetap di form',
    (tester) async {
      await pumpForm(tester);
      await tester.enterText(deskripsi(), _valid);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Buang laporan ini?'), findsOneWidget);

      await tester.tap(find.text('Lanjut mengisi'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateReportScreen), findsOneWidget);
      expect(find.text(_valid), findsOneWidget);
    },
  );

  testWidgets('back sistem saat terisi lalu Buang laporan menutup form', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(deskripsi(), _valid);

    // Tombol back Android.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buang laporan'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateReportScreen), findsNothing);
    expect(find.text('pemindai'), findsOneWidget);
  });

  testWidgets('Ubah lokasi kembali ke pemindai, lewat konfirmasi bila terisi', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('pemindai'), findsOneWidget);

    await tester.tap(find.text('pemindai'));
    await tester.pumpAndSettle();
    await tester.enterText(deskripsi(), _valid);
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('Buang laporan ini?'), findsOneWidget);
  });

  group('foto kerusakan', () {
    testWidgets('kosong: dua tombol + teks bantu, tanpa pratinjau', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.text('Belum ada foto'), findsOneWidget);
      expect(find.text('Ambil foto'), findsOneWidget);
      expect(find.text('Pilih dari galeri'), findsOneWidget);
      expect(
        find.text('Foto dikompres otomatis saat dikirim.'),
        findsOneWidget,
      );
      expect(pratinjau(), findsNothing);
    });

    testWidgets(
      'submit tanpa foto: error di bagian foto, hilang setelah pilih',
      (tester) async {
        await pumpForm(tester);
        await tester.enterText(deskripsi(), _valid);

        await tapKirim(tester);
        expect(find.text(_fotoWajib), findsOneWidget);
        expect(find.byType(ReportSubmittedScreen), findsNothing);

        await tapTombol(tester, 'Pilih dari galeri');
        expect(find.text(_fotoWajib), findsNothing);
        expect(pratinjau(), findsOneWidget);
      },
    );

    testWidgets('sumber sesuai tombol; tanpa metadata penuh', (tester) async {
      await pumpForm(tester);

      await tapTombol(tester, 'Ambil foto');
      expect(find.text('Ambil ulang'), findsOneWidget);
      await tapTombol(tester, 'Pilih dari galeri');

      expect(picker.sources, [ImageSource.camera, ImageSource.gallery]);
      expect(picker.lastRequestFullMetadata, isFalse);
    });

    testWidgets('batal memilih tidak menghapus foto lama', (tester) async {
      await pumpForm(tester);
      await tapTombol(tester, 'Ambil foto');

      picker.hasil = null;
      await tapTombol(tester, 'Ambil ulang');

      expect(pratinjau(), findsOneWidget);
    });

    testWidgets('izin kamera ditolak: SnackBar ramah tanpa detail teknis', (
      tester,
    ) async {
      picker.error = PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access.',
      );
      await pumpForm(tester);

      await tapTombol(tester, 'Ambil foto');

      expect(find.textContaining('Izin kamera ditolak'), findsOneWidget);
      expect(find.textContaining('did not allow'), findsNothing);
      expect(pratinjau(), findsNothing);
    });

    testWidgets('tombol nonaktif selama picker terbuka', (tester) async {
      final buka = Completer<XFile?>();
      picker.pending = buka;
      await pumpForm(tester);

      await tapTombol(tester, 'Ambil foto');
      await tapTombol(tester, 'Pilih dari galeri');
      expect(picker.sources, [ImageSource.camera]);

      buka.complete(XFile('/tmp/sifasilitas_uji.jpg'));
      await tester.pumpAndSettle();
      expect(pratinjau(), findsOneWidget);
    });

    testWidgets('back saat hanya ada foto minta konfirmasi', (tester) async {
      await pumpForm(tester);
      await tapTombol(tester, 'Ambil foto');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Buang laporan ini?'), findsOneWidget);
    });
  });

  group('kategori & saran AI', () {
    testWidgets('fokus lepas: saran terisi, chip prioritas AI + target SLA', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);

      expect(ai.permintaan, [_valid]);
      expect(find.text('Saran AI: Proyektor'), findsOneWidget);
      expect(
        find.text('Proyektor dibutuhkan langsung untuk perkuliahan.'),
        findsOneWidget,
      );
      // Dropdown terisi kategori saran.
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.text('Proyektor'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tinggi'), findsOneWidget);
      expect(
        find.text('Target penanganan 4 jam · disarankan AI'),
        findsOneWidget,
      );
    });

    testWidgets(
      'deskripsi belum valid atau tidak berubah: AI tidak dipanggil',
      (tester) async {
        await pumpForm(tester);

        await tester.enterText(deskripsi(), 'rusak');
        await selesaiMengetik(tester);
        expect(ai.permintaan, isEmpty);

        await tester.enterText(deskripsi(), _valid);
        await selesaiMengetik(tester);
        await tester.tap(deskripsi());
        await selesaiMengetik(tester);
        expect(ai.permintaan, hasLength(1));
      },
    );

    testWidgets('ganti kategori: prioritas bawaan fasilitas', (tester) async {
      await pumpForm(tester);
      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);

      await pilihKategori(tester, 'Toilet');

      expect(find.text('Sedang'), findsOneWidget);
      expect(
        find.text('Target penanganan 8 jam · bawaan fasilitas'),
        findsOneWidget,
      );
    });

    testWidgets('pilihan manual tidak ditimpa saran otomatis berikutnya', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);
      await pilihKategori(tester, 'Toilet');

      ai.hasil = const DamageClassificationResult(
        categoryId: 'cat_lampu',
        prioritas: 'darurat',
        alasanSingkat: 'Indikasi korsleting.',
      );
      await tester.enterText(
        deskripsi(),
        'Lampu berkedip dan ada percikan api.',
      );
      await selesaiMengetik(tester);

      expect(find.text('Saran AI: Lampu'), findsOneWidget);
      expect(find.text('Sedang'), findsOneWidget);

      // Tombol eksplisit tetap menerapkan saran.
      await tapTombol(tester, 'Minta saran ulang');
      expect(find.text('Darurat'), findsOneWidget);
      expect(
        find.text('Target penanganan 2 jam · disarankan AI'),
        findsOneWidget,
      );
    });

    testWidgets('tombol minta saran dengan deskripsi kosong: error inline', (
      tester,
    ) async {
      await pumpForm(tester);

      await tapTombol(tester, 'Minta saran AI');

      expect(find.text(_wajib), findsOneWidget);
      expect(ai.permintaan, isEmpty);
    });

    testWidgets('indikator selama menunggu; hasil lama diabaikan', (
      tester,
    ) async {
      final lambat = Completer<DamageClassificationResult>();
      ai.handler = (_) => lambat.future;
      await pumpForm(tester);

      await tester.enterText(deskripsi(), _valid);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Meminta saran AI…'), findsOneWidget);

      // Teks diubah; permintaan kedua langsung selesai dengan Toilet.
      ai.handler = (_) async => const DamageClassificationResult(
        categoryId: 'cat_toilet',
        prioritas: 'sedang',
        alasanSingkat: 'Masalah sanitasi.',
      );
      await tester.enterText(deskripsi(), 'Keran toilet bocor sejak pagi ini.');
      await selesaiMengetik(tester);
      expect(find.text('Saran AI: Toilet'), findsOneWidget);

      // Respons lama baru datang: tidak boleh menimpa.
      lambat.complete(ai.hasil);
      await tester.pumpAndSettle();
      expect(find.text('Saran AI: Toilet'), findsOneWidget);
      expect(find.text('Saran AI: Proyektor'), findsNothing);
    });

    testWidgets('classifier gagal: pesan ramah, dropdown tetap bisa dipakai', (
      tester,
    ) async {
      ai.handler = (_) => Future.error(Exception('HTTP 500 detail teknis'));
      await pumpForm(tester);

      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);

      expect(
        find.text('Saran AI tidak tersedia. Pilih fasilitas secara manual.'),
        findsOneWidget,
      );
      expect(find.textContaining('HTTP 500'), findsNothing);
      await pilihKategori(tester, 'Lampu');
      expect(find.text('Darurat'), findsOneWidget);
    });

    testWidgets('kategori saran tidak ada di master: dropdown kosong', (
      tester,
    ) async {
      ai.hasil = const DamageClassificationResult(
        categoryId: 'cat_ac',
        prioritas: 'tinggi',
        alasanSingkat: 'AC.',
      );
      await pumpForm(tester);

      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);

      expect(find.textContaining('tidak ada di daftar'), findsOneWidget);
      expect(find.text('Pilih fasilitas'), findsOneWidget);
    });

    testWidgets('submit tanpa kategori: error, hilang saat saran datang', (
      tester,
    ) async {
      final lambat = Completer<DamageClassificationResult>();
      ai.handler = (_) => lambat.future;
      await pumpForm(tester);
      await tapTombol(tester, 'Ambil foto');
      await tester.enterText(deskripsi(), _valid);

      // Kirim saat field masih fokus: fokus lepas memicu saran (masih
      // menunggu), validasi kategori gagal.
      await tester.ensureVisible(find.text(_kirim));
      await tester.tap(find.text(_kirim));
      await tester.pump();
      expect(find.text(_kategoriWajib), findsOneWidget);
      expect(find.byType(ReportSubmittedScreen), findsNothing);

      lambat.complete(ai.hasil);
      await tester.pumpAndSettle();
      expect(find.text(_kategoriWajib), findsNothing);
    });

    testWidgets('master kategori kosong: pesan data master', (tester) async {
      repo.categories = const [];
      await pumpForm(tester);

      expect(
        find.textContaining('Daftar fasilitas belum tersedia'),
        findsOneWidget,
      );
    });

    testWidgets('gagal memuat kategori lalu Coba lagi', (tester) async {
      repo.categoriesStream = Stream.error(Exception('unavailable'));
      await pumpForm(tester);
      expect(
        find.textContaining('Gagal memuat daftar fasilitas'),
        findsOneWidget,
      );

      repo.categoriesStream = null;
      await tapTombol(tester, 'Coba lagi');

      expect(repo.watchCategoriesCalls, 2);
      expect(find.textContaining('Gagal memuat'), findsNothing);
    });
  });

  group('tata letak & tipografi', () {
    testWidgets('HP 360 dp: tidak ada overflow, judul section huruf besar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpForm(tester);

      // Overflow akan tercatat sebagai exception render.
      expect(tester.takeException(), isNull);
      expect(find.text('FOTO KERUSAKAN'), findsOneWidget);
      expect(find.text('FASILITAS & PRIORITAS'), findsOneWidget);

      await tapTombol(tester, 'Ambil foto');
      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Ambil ulang'), findsOneWidget);
    });

    testWidgets('nilai dropdown memakai gaya teks input (bodyLarge)', (
      tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(deskripsi(), _valid);
      await selesaiMengetik(tester);

      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      final context = tester.element(find.byType(DropdownButton<String>));
      expect(
        dropdown.style?.fontSize,
        Theme.of(context).textTheme.bodyLarge?.fontSize,
      );
      expect(
        dropdown.style?.fontWeight,
        Theme.of(context).textTheme.bodyLarge?.fontWeight,
      );
    });
  });

  group('kirim laporan', () {
    const koneksi =
        'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba '
        'lagi.';

    /// Aksi "Coba lagi" di SnackBar error.

    Future<void> cobaLagi(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Coba lagi'),
        ),
      );

      await tester.pumpAndSettle();
    }

    Future<void> isiLengkap(WidgetTester tester, {String teks = _valid}) async {
      await tapTombol(tester, 'Ambil foto');
      await tester.enterText(deskripsi(), teks);
      await selesaiMengetik(tester);
    }

    testWidgets('sukses: upload, submitReport dengan argumen benar, hasil', (
      tester,
    ) async {
      await pumpForm(tester);
      await isiLengkap(tester, teks: '  $_valid  ');

      await tapKirim(tester);

      expect(photos.uploads, ['/tmp/sifasilitas_uji.jpg']);
      final call = service.calls.single;
      expect(call.reporter.uid, 'u1');
      expect(call.location.id, 'loc_gda_201');
      expect(call.category.id, 'cat_proyektor');
      expect(call.deskripsi, _valid); // sudah di-trim
      expect(call.fotoSebelumUrl, 'photo:uji1');
      expect(call.aiSuggestedPriority, 'tinggi');
      expect(find.byType(ReportSubmittedScreen), findsOneWidget);
      expect(find.text('SF-UJI-0001'), findsOneWidget);
    });

    testWidgets('fasilitas diganti: aiSuggestedPriority null', (tester) async {
      await pumpForm(tester);
      await isiLengkap(tester);
      await pilihKategori(tester, 'Toilet');

      await tapKirim(tester);

      expect(service.calls.single.category.id, 'cat_toilet');
      expect(service.calls.single.aiSuggestedPriority, isNull);
    });

    testWidgets(
      'selama mengirim: loading, tahap, tanpa dobel, back diabaikan',
      (tester) async {
        final upload = Completer<String>();
        photos.pending = upload;
        await pumpForm(tester);
        await isiLengkap(tester);

        await tester.ensureVisible(find.text(_kirim));
        await tester.tap(find.text(_kirim));
        await tester.pump();
        expect(find.text('Mengunggah foto…'), findsOneWidget);
        expect(
          tester.widget<LoadingButton>(find.byType(LoadingButton)).loading,
          isTrue,
        );

        // Tekan lagi + tombol back sistem: tidak berpengaruh.
        await tester.tap(find.byType(LoadingButton), warnIfMissed: false);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(photos.uploads, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(CreateReportScreen), findsOneWidget);

        upload.complete('photo:uji1');
        await tester.pumpAndSettle();
        expect(service.calls, hasLength(1));
        expect(find.byType(ReportSubmittedScreen), findsOneWidget);
      },
    );

    testWidgets('upload gagal: pesan koneksi, form utuh, bisa coba lagi', (
      tester,
    ) async {
      photos.error = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await pumpForm(tester);
      await isiLengkap(tester);

      await tapKirim(tester);
      expect(find.text(koneksi), findsOneWidget);
      expect(find.text(_valid), findsOneWidget);
      expect(pratinjau(), findsOneWidget);
      expect(service.calls, isEmpty);

      photos.error = null;
      await cobaLagi(tester);
      expect(photos.uploads, hasLength(2));
      expect(find.byType(ReportSubmittedScreen), findsOneWidget);
    });

    testWidgets('submit gagal: coba lagi tanpa upload ulang', (tester) async {
      service.error = Exception('transaksi gagal');
      await pumpForm(tester);
      await isiLengkap(tester);

      await tapKirim(tester);
      expect(find.text('Gagal mengirim laporan. Coba lagi.'), findsOneWidget);
      expect(find.textContaining('transaksi gagal'), findsNothing);

      service.error = null;
      await cobaLagi(tester);
      expect(photos.uploads, hasLength(1));
      expect(service.calls, hasLength(2));
      expect(service.calls.last.fotoSebelumUrl, 'photo:uji1');
    });

    testWidgets('ganti foto setelah gagal: foto baru diunggah', (tester) async {
      service.error = Exception('transaksi gagal');
      await pumpForm(tester);
      await isiLengkap(tester);
      await tapKirim(tester);

      // Tutup SnackBar dulu (menutupi tombol bawah), lalu ganti foto.

      ScaffoldMessenger.of(
        tester.element(find.byType(CreateReportScreen)),
      ).hideCurrentSnackBar();

      await tester.pumpAndSettle();

      picker.hasil = XFile('/tmp/sifasilitas_baru.jpg');
      await tapTombol(tester, 'Ambil ulang');
      service.error = null;
      photos.ref = 'photo:uji2';
      await tapKirim(tester);

      expect(photos.uploads, [
        '/tmp/sifasilitas_uji.jpg',
        '/tmp/sifasilitas_baru.jpg',
      ]);
      expect(service.calls.last.fotoSebelumUrl, 'photo:uji2');
    });

    testWidgets('pesan 403 dari service tampil apa adanya', (tester) async {
      service.error = Exception('403 Forbidden: Akun pelapor tidak aktif.');
      await pumpForm(tester);
      await isiLengkap(tester);

      await tapKirim(tester);

      expect(
        find.text('403 Forbidden: Akun pelapor tidak aktif.'),
        findsOneWidget,
      );
    });

    testWidgets('upload menggantung (offline): berhenti setelah 30 detik', (
      tester,
    ) async {
      photos.pending = Completer<String>(); // tidak pernah selesai
      await pumpForm(tester);
      await isiLengkap(tester);

      await tester.ensureVisible(find.text(_kirim));
      await tester.tap(find.text(_kirim));
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      expect(find.text(koneksi), findsOneWidget);
      expect(
        tester.widget<LoadingButton>(find.byType(LoadingButton)).loading,
        isFalse,
      );
    });
  });
}
