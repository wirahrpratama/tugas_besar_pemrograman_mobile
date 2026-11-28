import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/report_models.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_top_bar.dart';
import 'photo_picker_field.dart';
import 'report_form_logic.dart';
import 'report_submitted_screen.dart';

/// Layar form laporan: lokasi, foto (langkah 6), deskripsi, saran AI
/// (langkah 7), lalu kirim (langkah 8).
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

  /// Foto terpilih. `XFile` hanya berlaku selama sesi app; langkah 8
  /// mengunggahnya lewat `PhotoStore.uploadPhoto(File(_foto!.path))`.
  XFile? _foto;

  /// True selama kamera/galeri terbuka; mencegah picker dibuka dua kali.
  bool _sedangMemilihFoto = false;

  /// Kunci ke FormField foto, untuk memberi tahu Form bahwa nilainya berubah
  /// (didChange) sehingga error foto ikut diperbarui seperti field teks.
  final _fotoFieldKey = GlobalKey<FormFieldState<XFile>>();

  @override
  void initState() {
    super.initState();
    _picker = context.read<ImagePicker?>() ?? ImagePicker();
  }

  @override
  void dispose() {
    _deskripsi.dispose();
    super.dispose();
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
      if (hasil != null) _foto = hasil;
    });
    if (hasil != null) _fotoFieldKey.currentState?.didChange(hasil);
    if (pesanError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(pesanError)));
    }
  }

  void _kirim() {
    // Tutup keyboard supaya pesan error dan tombol tidak tertutup.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    _kirimContoh();
  }

  // TODO(langkah 8): hapus; hasil asli dari ReportService.submitReport.
  void _kirimContoh() {
    // pushReplacement: form dikeluarkan dari tumpukan, jadi back dari layar
    // hasil tidak kembali ke form yang sudah terkirim.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportSubmittedScreen(
          userUid: widget.user.uid,
          userName: widget.user.nama,
          result: const {
            'merged': false,
            'ticket_number': 'CONTOH-0001',
            'message': 'Data contoh, belum dikirim ke server.',
          },
        ),
      ),
    );
  }

  /// Dipanggil [PopScope] setiap kali layar akan ditutup: tombol back
  /// sistem, [AppBackButton], atau tombol "Ubah" lokasi.
  Future<void> _onPop(bool didPop, Object? result) async {
    if (didPop) return;
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
    final theme = Theme.of(context);
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Lokasi', style: theme.textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        _LocationCard(
                          location: widget.location,
                          // maybePop agar tetap lewat konfirmasi di _onPop.
                          onChange: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Foto kerusakan',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
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
                        Text(
                          'Deskripsi kerusakan',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _deskripsi,
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
                            helperText:
                                'Jelaskan apa yang rusak dan sejak kapan.',
                            helperMaxLines: 2,
                            errorMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const _PlaceholderSection(
                          judul: 'Saran kategori dari AI',
                          keterangan: 'Langkah 7',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // TODO(langkah 8): ganti dengan LoadingButton
                        // "Kirim laporan" yang memanggil submitReport.
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _kirim,
                          child: const Text('Kirim (contoh, sementara)'),
                        ),
                      ],
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

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({required this.judul, required this.keterangan});

  final String judul;
  final String keterangan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Belum dibuat ($keterangan).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
