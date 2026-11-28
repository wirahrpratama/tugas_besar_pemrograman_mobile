import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../services/ai_classifier_service.dart';
import '../../services/photo_store.dart';
import '../../services/report_repository.dart';
import '../../services/report_service.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/loading_button.dart';
import 'category_section.dart';
import 'photo_picker_field.dart';
import 'report_form_logic.dart';
import 'report_section_header.dart';
import 'report_submitted_screen.dart';

/// Layar form laporan: lokasi, foto, deskripsi, fasilitas + saran AI, lalu
/// kirim (upload foto → `submitReport`).
class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({
    super.key,
    required this.user,
    required this.location,
  });

  final AppUser user;
  final CampusLocation location;

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Isi deskripsi tersimpan di controller milik State, jadi tidak hilang
  /// saat layar di-rebuild (rotasi, keyboard muncul, app ke background).
  final _deskripsi = TextEditingController();

  /// Pola pertemuan 09: error belum tampil sebelum submit pertama; setelah
  /// submit gagal, error diperbarui setiap kali pengguna mengetik.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  /// Bukan service tim, jadi tidak ada di `main.dart`: di app asli selalu
  /// `ImagePicker()`. Lookup nullable ke Provider hanya agar test bisa
  /// memasang picker palsu (lihat test/report/fake_image_picker.dart).
  late final ImagePicker _picker;

  /// Foto terpilih. `XFile` hanya berlaku selama sesi app; diunggah saat
  /// kirim lewat `PhotoStore.uploadPhoto(File(_foto!.path))`.
  XFile? _foto;

  /// True selama kamera/galeri terbuka; mencegah picker dibuka dua kali.
  bool _sedangMemilihFoto = false;

  /// Kunci ke FormField foto, untuk memberi tahu Form bahwa nilainya berubah
  /// (didChange) sehingga error foto ikut diperbarui seperti field teks.
  final _fotoFieldKey = GlobalKey<FormFieldState<XFile>>();

  // --- Kirim (langkah 8) ---

  /// Batas tunggu upload dan submit. Penting: saat offline, `set()` Firestore
  /// tidak gagal melainkan menunggu sampai online, jadi tanpa batas ini
  /// tombol bisa loading selamanya.
  static const _batasWaktu = Duration(seconds: 30);

  /// Submission state (slide 13): idle (false) / loading (true). Sukses =
  /// pindah layar; gagal = kembali false + SnackBar.
  bool _mengirim = false;

  /// Teks tahap di bawah tombol: "Mengunggah foto…" / "Mengirim laporan…".
  String? _tahapKirim;

  /// Referensi `"photo:{id}"` hasil upload yang berhasil. Bila hanya
  /// `submitReport` yang gagal, percobaan berikutnya memakai ref ini (tidak
  /// upload ulang). Dikosongkan saat pelapor mengganti foto.
  String? _fotoRef;

  // --- Deskripsi & saran AI (langkah 7) ---

  /// Saat field deskripsi kehilangan fokus, saran kategori diminta otomatis.
  final _deskripsiFocus = FocusNode();
  final _deskripsiFieldKey = GlobalKey<FormFieldState<String>>();
  final _kategoriFieldKey = GlobalKey<FormFieldState<String>>();

  /// Master kategori. Didengarkan lewat StreamSubscription (bukan
  /// StreamBuilder) karena daftar ini juga dibutuhkan saat tombol Kirim
  /// ditekan, di luar builder. Subscription wajib di-cancel di dispose.
  StreamSubscription<List<FacilityCategory>>? _kategoriSub;
  List<FacilityCategory>? _kategoriList;
  bool _gagalMemuatKategori = false;

  DamageClassificationResult? _saran;
  String? _kategoriId;

  /// True setelah pelapor memilih kategori sendiri. Saran otomatis (saat
  /// fokus lepas) tidak lagi menimpa pilihannya; tombol "Minta saran" tetap
  /// menerapkan saran karena itu permintaan eksplisit.
  bool _kategoriDipilihManual = false;

  bool _memintaSaran = false;
  String? _pesanSaranGagal;

  /// Deskripsi terakhir yang dikirim ke classifier, agar fokus lepas tanpa
  /// perubahan teks tidak memanggil AI lagi.
  String? _teksTerakhirDiklasifikasi;

  /// Nomor permintaan terbaru; hasil permintaan lama yang datang terlambat
  /// diabaikan supaya tidak menimpa hasil yang lebih baru.
  int _nomorPermintaan = 0;

  @override
  void initState() {
    super.initState();
    _picker = context.read<ImagePicker?>() ?? ImagePicker();
    _deskripsiFocus.addListener(_onFokusDeskripsiBerubah);
    _muatKategori();
  }

  @override
  void dispose() {
    _kategoriSub?.cancel();
    _deskripsiFocus.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  void _muatKategori() {
    _kategoriSub?.cancel();
    _kategoriSub = context.read<ReportRepository>().watchCategories().listen(
      (list) => setState(() {
        _kategoriList = list;
        _gagalMemuatKategori = false;
      }),
      onError: (Object _) => setState(() => _gagalMemuatKategori = true),
    );
  }

  void _muatUlangKategori() {
    setState(() {
      _kategoriList = null;
      _gagalMemuatKategori = false;
    });
    _muatKategori();
  }

  /// Kategori terpilih yang benar-benar ada di master (null bila belum ada,
  /// masih memuat, atau id saran tidak ditemukan).
  FacilityCategory? get _kategoriTerpilih =>
      _kategoriList?.where((c) => c.id == _kategoriId).firstOrNull;

  void _onFokusDeskripsiBerubah() {
    if (_deskripsiFocus.hasFocus) return;
    final teks = _deskripsi.text.trim();
    if (validasiDeskripsi(teks) != null) return;
    if (teks == _teksTerakhirDiklasifikasi) return;
    unawaited(_mintaSaran(terapkan: !_kategoriDipilihManual));
  }

  void _tekanMintaSaran() {
    // Validasi field deskripsi saja: error tampil inline di field itu.
    if (!(_deskripsiFieldKey.currentState?.validate() ?? false)) return;
    unawaited(_mintaSaran(terapkan: true));
  }

  Future<void> _mintaSaran({required bool terapkan}) async {
    // Ambil service SEBELUM await (context belum tentu masih terpasang).
    final ai = context.read<AiClassifierService>();
    final teks = _deskripsi.text.trim();
    final nomor = ++_nomorPermintaan;
    _teksTerakhirDiklasifikasi = teks;
    setState(() {
      _memintaSaran = true;
      _pesanSaranGagal = null;
    });

    DamageClassificationResult? hasil;
    try {
      // Service sudah jatuh ke heuristik offline bila Gemini gagal, jadi
      // exception di sini seharusnya jarang; tetap ditangani.
      hasil = await ai.classifyComplaint(teks);
    } on Exception {
      hasil = null;
    }
    if (!mounted || nomor != _nomorPermintaan) return;

    setState(() {
      _memintaSaran = false;
      if (hasil == null) {
        _pesanSaranGagal =
            'Saran AI tidak tersedia. Pilih fasilitas secara manual.';
        _teksTerakhirDiklasifikasi = null;
        return;
      }
      _saran = hasil;
      if (terapkan) {
        _kategoriId = hasil.categoryId;
        _kategoriDipilihManual = false;
      }
    });
    // Bila error "Pilih kategori" sudah tampil (submit gagal sebelumnya),
    // perbarui setelah frame ini, saat dropdown sudah memakai nilai saran.
    if (terapkan && _autovalidateMode != AutovalidateMode.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _kategoriFieldKey.currentState?.validate();
      });
    }
  }

  void _onKategoriChanged(String? id) {
    setState(() {
      _kategoriId = id;
      _kategoriDipilihManual = true;
    });
  }

  /// True bila ada isian yang akan hilang kalau layar ditutup.
  bool get _adaIsian => _foto != null || _deskripsi.text.trim().isNotEmpty;

  Future<void> _pilihFoto(ImageSource source) async {
    if (_sedangMemilihFoto) return;
    setState(() => _sedangMemilihFoto = true);

    XFile? hasil;
    String? pesanError;
    try {
      // Tanpa imageQuality/maxWidth: layar tidak mengompres, PhotoStore yang
      // mengompres saat upload. requestFullMetadata: false menghindari izin
      // Photo Library tambahan di iOS (metadata EXIF tidak kita pakai).
      hasil = await _picker.pickImage(
        source: source,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      pesanError = pesanGagalAmbilFoto(e.code, source);
    } on Exception {
      pesanError = pesanGagalAmbilFoto('', source);
    }
    if (!mounted) return;

    // hasil null = pengguna membatalkan: foto lama tetap dipakai.
    setState(() {
      _sedangMemilihFoto = false;
      if (hasil != null) {
        _foto = hasil;
        _fotoRef = null; // foto baru harus diunggah ulang
      }
    });
    if (hasil != null) _fotoFieldKey.currentState?.didChange(hasil);
    if (pesanError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanError)));
    }
  }

  Future<void> _kirim() async {
    if (_mengirim) return; // cegah submit ganda (slide 26)
    // Tutup keyboard supaya pesan error dan tombol tidak tertutup.
    FocusScope.of(context).unfocus();
    final kategori = _kategoriTerpilih;
    final foto = _foto;
    if (!_formKey.currentState!.validate() ||
        kategori == null ||
        foto == null) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    // Ambil semua yang butuh context SEBELUM await pertama.
    final photoStore = context.read<PhotoStore>();
    final reportService = context.read<ReportService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _mengirim = true;
      _tahapKirim = 'Mengunggah foto…';
    });

    var saatUpload = true;
    try {
      var ref = _fotoRef;
      if (ref == null) {
        // Kompresi otomatis di dalam uploadPhoto; layar tidak mengompres.
        ref = await photoStore
            .uploadPhoto(File(foto.path))
            .timeout(_batasWaktu);
        _fotoRef = ref;
      }
      saatUpload = false;
      if (!mounted) return;
      setState(() => _tahapKirim = 'Mengirim laporan…');

      final hasil = await reportService
          .submitReport(
            reporter: widget.user,
            location: widget.location,
            category: kategori,
            deskripsi: _deskripsi.text.trim(),
            fotoSebelumUrl: ref,
            aiSuggestedPriority: prioritasUntukDikirim(_saran, kategori.id),
          )
          .timeout(_batasWaktu);
      if (!mounted) return;

      // pushReplacement: form dikeluarkan dari tumpukan, jadi back dari layar
      // hasil tidak kembali ke form yang sudah terkirim.
      unawaited(
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReportSubmittedScreen(
              result: hasil,
              user: widget.user,
              location: widget.location,
              category: kategori,
              prioritas: prioritasTampil(_saran, kategori).prioritas,
            ),
          ),
        ),
      );
    } catch (e) {
      // Sengaja menangkap semua (bukan hanya Exception): uploadPhoto juga
      // melempar StateError/ArgumentError. Detail teknis tidak ditampilkan.
      if (!mounted) return;
      setState(() {
        _mengirim = false;
        _tahapKirim = null;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(pesanGagalKirim(e, saatUpload: saatUpload)),
            // SnackBar muncul di bawah dan menutupi tombol Kirim selama
            // beberapa detik, jadi aksi coba lagi disediakan di sini.
            action: SnackBarAction(label: 'Coba lagi', onPressed: _kirim),
          ),
        );
    }
  }

  /// Dipanggil [PopScope] setiap kali layar akan ditutup: tombol back
  /// sistem, [AppBackButton], atau tombol "Ubah" lokasi.
  Future<void> _onPop(bool didPop, Object? result) async {
    // Selama mengirim, back diabaikan: bila layar ditutup, laporan tetap
    // terkirim di belakang tanpa pelapor melihat hasilnya.
    if (didPop || _mengirim) return;
    final keluar = !_adaIsian || await _konfirmasiBuang();
    if (!keluar || !mounted) return;
    // pop() langsung, bukan maybePop(), supaya tidak memicu PopScope lagi.
    Navigator.of(context).pop();
  }

  Future<bool> _konfirmasiBuang() async {
    final buang = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang laporan ini?'),
        content: const Text('Foto dan deskripsi yang sudah diisi akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Lanjut mengisi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Buang laporan'),
          ),
        ],
      ),
    );
    return buang ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false = setiap upaya menutup layar lewat _onPop dulu, yang
    // memutuskan perlu konfirmasi atau tidak. Konsekuensi: gesture geser
    // kembali iOS dan animasi predictive back Android tidak aktif di sini.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        appBar: AppTopBar(
          title: 'Buat laporan',
          profileUid: widget.user.uid,
          userName: widget.user.nama,
          photoUrl: widget.user.photoUrl,
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackButton(),
                ),
              ),
              Expanded(
                // SingleChildScrollView + Column, BUKAN ListView: ListView
                // hanya membangun item yang terlihat, jadi field yang belum
                // di-scroll tidak terdaftar di Form dan lolos dari validate().
                child: SingleChildScrollView(
                  padding: AppSpacing.paddingAllLg,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
                    // Selama mengirim, seluruh form dikunci dari sentuhan.
                    // Bukan dengan menonaktifkan tiap field: dropdown yang
                    // nonaktif menyembunyikan nilainya (menampilkan
                    // disabledHint), padahal pelapor perlu tetap melihatnya.
                    child: AbsorbPointer(
                      absorbing: _mengirim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ReportSectionHeader(
                            icon: Icons.place_outlined,
                            title: 'Lokasi',
                          ),
                          _LocationCard(
                            location: widget.location,
                            // maybePop agar tetap lewat konfirmasi di _onPop.
                            onChange: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const ReportSectionHeader(
                            icon: Icons.photo_camera_outlined,
                            title: 'Foto kerusakan',
                          ),
                          // FormField agar foto ikut validate() dan
                          // AutovalidateMode yang sama dengan deskripsi.
                          // Nilai sebenarnya tetap _foto di State.
                          FormField<XFile>(
                            key: _fotoFieldKey,
                            validator: (_) => validasiFoto(_foto),
                            builder: (field) => PhotoPickerField(
                              foto: _foto,
                              busy: _sedangMemilihFoto,
                              errorText: field.errorText,
                              onPick: _pilihFoto,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const ReportSectionHeader(
                            icon: Icons.notes_outlined,
                            title: 'Deskripsi kerusakan',
                          ),
                          TextFormField(
                            key: _deskripsiFieldKey,
                            controller: _deskripsi,
                            focusNode: _deskripsiFocus,
                            readOnly: _mengirim,
                            validator: validasiDeskripsi,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: deskripsiMaksimal,
                            decoration: const InputDecoration(
                              labelText: 'Deskripsi',
                              alignLabelWithHint: true,
                              hintText:
                                  'Contoh: Proyektor tidak menyala sejak '
                                  'Senin pagi.',
                              // Privasi (checklist slide 26): bila kunci
                              // Gemini aktif, deskripsi dikirim ke layanan AI.
                              helperText:
                                  'Jelaskan apa yang rusak dan sejak kapan. '
                                  'Jangan tulis data pribadi (nama, NIM, '
                                  'nomor HP).',
                              helperMaxLines: 3,
                              errorMaxLines: 2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const ReportSectionHeader(
                            icon: Icons.category_outlined,
                            title: 'Fasilitas & prioritas',
                          ),
                          CategorySection(
                            fieldKey: _kategoriFieldKey,
                            kategoriList: _kategoriList,
                            gagalMemuatKategori: _gagalMemuatKategori,
                            onMuatUlangKategori: _muatUlangKategori,
                            kategoriId: _kategoriTerpilih?.id,
                            onKategoriChanged: _onKategoriChanged,
                            saran: _saran,
                            memintaSaran: _memintaSaran,
                            pesanSaranGagal: _pesanSaranGagal,
                            onMintaSaran: _tekanMintaSaran,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          // LoadingButton = AppButton tim + spinner; saat
                          // loading tombol nonaktif (cegah submit ganda).
                          LoadingButton(
                            label: 'Kirim laporan',
                            loading: _mengirim,
                            onPressed: _kirim,
                          ),
                          if (_tahapKirim case final tahap?)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.sm,
                              ),
                              child: Text(
                                tahap,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu ringkas ruangan yang dilaporkan + tombol "Ubah".
class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onChange});

  final CampusLocation location;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.meeting_room_outlined, color: colorScheme.primary),
        title: Text(location.namaRuangan),
        subtitle: Text(
          '${location.namaGedung} · ${location.kodeRuangan} · '
          'Lantai ${location.lantai}',
        ),
        trailing: TextButton(onPressed: onChange, child: const Text('Ubah')),
      ),
    );
  }
}
