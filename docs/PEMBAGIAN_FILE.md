# Pembagian File & Aturan Kolaborasi Tim — SiFasilitas

Dokumen ini menjadi acuan kepemilikan file/folder dan alur kerja Git agar seluruh anggota tim dapat mengembangkan fitur secara paralel tanpa konflik merge maupun merusak fondasi aplikasi.

---

## 1. Kepemilikan File & Folder

| Anggota | Peran / Modul | File & Folder yang Dikelola |
|---|---|---|
| **Aldrik Noel Sianipar** | Reporting, Kamera & QR Scanner | `lib/screens/report/` (form pembuatan laporan, pemindai QR ruangan, ambil/kompres foto) |
| **Rafi Andara Nasution** | Tracking, Timeline & Konfirmasi | `lib/screens/tracking/` (riwayat laporan, detail timeline/log, konfirmasi pelapor) |
| **Vincent Christian Simbolon** | Dashboard Admin & Teknisi | `lib/screens/home/admin_dashboard.dart`, `lib/screens/home/teknisi_dashboard.dart`, serta sub-halaman/widget di bawah `lib/screens/home/` khusus admin & teknisi |
| **Yosia Marcel Simanjuntak** | AI Classifier & Anti-Duplikasi | `lib/services/ai_classifier_service.dart` (klasifikasi Gemini 2.5 Flash & heuristik fallback) |
| **Leondo Admiral Purba** | Auth & RBAC | `lib/screens/auth/`, `lib/screens/auth_gate.dart`, `lib/screens/profile/`, `lib/services/auth_service.dart`, `lib/utils/validators.dart` |
| **Wira Hari Pratama** *(File Inti / Terkunci)* | Arsitektur Inti, Model, Service & Rules | `lib/main.dart`, `lib/models/report_models.dart`, `lib/services/report_service.dart`, `lib/services/report_repository.dart`, `lib/services/photo_store.dart`, `lib/widgets/report_photo.dart`, `lib/services/firebase_seeder.dart`, `lib/widgets/seed_master_data_button.dart`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `pubspec.yaml` |

### Catatan Area Titik Temu & File Inti
* **File inti (`lib/main.dart`, `lib/models/report_models.dart`, `lib/services/report_service.dart`, `lib/services/report_repository.dart`, `lib/services/photo_store.dart`, `lib/widgets/report_photo.dart`, `lib/services/firebase_seeder.dart`, `lib/widgets/seed_master_data_button.dart`, `firestore.rules`, `firestore.indexes.json`):** hanya boleh diubah lewat **Wira**. Jika fitur Anda memerlukan field model baru, method/query baru di `ReportService`/`ReportRepository`, provider baru di `main.dart`, atau penyesuaian rule/indeks Firestore, ajukan permintaan atau PR ke Wira terlebih dahulu—jangan mengedit langsung di branch fitur Anda.
* **`lib/screens/home/pelapor_home.dart`:** menjadi titik temu antara fitur **Aldrik** (buat laporan) dan **Rafi** (riwayat/tracking). Koordinasikan lewat **Wira** sebelum mengubah file ini agar tidak saling menimpa.
* **`lib/screens/home/admin_dashboard.dart`:** dikelola oleh **Vincent**, tetapi **wajib tetap mempertahankan widget `SeedMasterDataButton()`** di dalam widget tree `AdminDashboard` agar aksi seeding admin dan pengujian `test/seed_master_data_button_test.dart` tetap berjalan.
* **Konfigurasi platform (`android/`, `ios/`):** izin kamera dan deployment target sudah disiapkan; jangan diubah kecuali disepakati bersama.

---

## 2. Aturan Kerja Git & Pull Request

1. **Selalu buat branch dari `main` terbaru.**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b fitur/<nama-fitur>
   ```
2. **Buat PR berukuran kecil dan terfokus.** Satu PR untuk satu fitur/sub-fitur yang jelas agar mudah di-review dan minim konflik.
3. **Jangan ubah file milik orang lain tanpa izin.** Pastikan perubahan pada PR hanya menyentuh folder/file milik Anda sendiri (cek dengan `git status` dan `git diff --stat` sebelum commit).
4. **Perubahan file inti hanya lewat Wira.** Jangan menyertakan edit pada `lib/main.dart`, `lib/models/report_models.dart`, `lib/services/report_service.dart`, `lib/services/report_repository.dart`, `lib/services/photo_store.dart`, `lib/widgets/report_photo.dart`, `firestore.rules`, atau `firestore.indexes.json` tanpa persetujuan/penanganan Wira.
5. **Wajib lolos pengecekan sebelum membuka PR.** Pastikan tidak ada error maupun warning sebelum push dan membuat PR:
   ```bash
   flutter analyze
   flutter test
   ```
