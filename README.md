# SiFasilitas (Campus Facility Care)

> Sistem pelaporan dan penanganan kerusakan fasilitas kampus berbasis mobile dengan arsitektur multi-peran (*Pelapor*, *Admin Fasilitas*, dan *Teknisi*), didukung verifikasi berbasis QR Code, *smart triage* AI (Gemini), serta *state machine* pelacakan tiket secara terintegrasi.

---

## 📱 Deskripsi Proyek
**SiFasilitas** adalah aplikasi mobile berbasis Flutter dan Google Firebase yang dirancang untuk mendigitalkan dan mengoptimalkan proses penanganan aduan sarana-prasarana kampus. Sistem ini menggantikan proses pelaporan manual dengan alur kerja yang transparan, terukur (berbasis SLA), dan terhindar dari duplikasi tiket.

Aplikasi menerapkan **Role-Based Access Control (RBAC)** dengan 3 peran utama:
1. **Pelapor (Mahasiswa, Dosen, Staf):** Memindai QR Code lokasi fasilitas, mengambil foto kerusakan fisik, mendapatkan rekomendasi kategori dan prioritas otomatis via AI, serta memantau linimasa perbaikan tiket secara *real-time*.
2. **Admin Fasilitas:** Memverifikasi tiket masuk, menolak aduan yang tidak relevan/valid (*Rejected*), memprioritaskan antrean, dan menugaskan tiket kepada teknisi lapangan yang bertugas (*Assigned*).
3. **Teknisi Perbaikan:** Menerima penugasan tugas kerja, memperbarui status pengerjaan ke tahap pengerjaan (*In Progress*), serta menutup tiket (*Resolved*) dengan kewajiban melampirkan foto bukti hasil perbaikan.

> Deskripsi peran di atas adalah target fungsional aplikasi. Bagian mana yang sudah ada kodenya tercantum di [Status Implementasi](#-status-implementasi).

---

## 👥 Anggota Tim & Pembagian Tanggung Jawab

| No | Nama Lengkap | NIM | Peran Utama | Fokus Tanggung Jawab |
|---|---|---|---|---|
| 1 | Wira Hari Pratama | 241402111 | **Project Lead & Core Architecture** | Setup fondasi Flutter & Firebase, perancangan model entitas data, implementasi *state machine engine* & transaksi Firestore, serta standarisasi master data seeder. |
| 2 | Leondo Admiral Purba | 241402053 | **Frontend Dev (Auth & RBAC)** | Implementasi UI & alur autentikasi (Firebase Auth), sistem validasi identitas (NIM/NIP), serta *role-based navigation gate* (Pelapor, Admin, Teknisi). |
| 3 | Aldrik Noel Sianipar | 241402049 | **Frontend Dev (Reporting & Hardware)** | Antarmuka pembuatan tiket laporan, integrasi kamera & kompresi gambar (`image_picker`, `flutter_image_compress`), dan integrasi pemindai QR Code ruangan/aset (`mobile_scanner`). |
| 4 | Rafi Andara Nasution | 241402095 | **Frontend Dev (Tracking & Timeline)** | Antarmuka riwayat aduan, visualisasi tahapan status tiket (*Reported* ➔ *Resolved*), log riwayat perubahan status (*audit trail*), serta konfirmasi penyelesaian oleh pelapor. |
| 5 | Vincent Christian Simbolon | 241402039 | **Frontend Dev (Dashboard Admin/Teknisi)** | Dashboard manajemen antrean tiket masuk bagi Admin & Teknisi: filter kategori & urgensi, alur disposisi teknisi, serta form penyelesaian tiket berlampiran foto sesudah pengerjaan. |
| 6 | Yosia Marcel Simanjuntak | 241402114 | **BaaS, AI Integration & Data Engineer** | Konfigurasi Cloud Firestore, integrasi *Smart AI Classifier* (Google Gemini 2.5 Flash & NLP Heuristic), logika *anti-duplikasi merge*, dan sistem *auto-upvoting* tiket. |

---

## ✅ Status Implementasi

| Komponen | Status | Keterangan |
|---|---|---|
| Autentikasi & RBAC | Ada | `AuthService` (daftar, masuk, lupa password, verifikasi email, ubah nama), layar `screens/auth/`, `screens/profile/`, dan `AuthGate` (navigasi berdasarkan `users/{uid}.role`). |
| Beranda per peran | Sebagian | Dashboard admin menampilkan antrean, filter, verifikasi, dan penugasan teknisi. Dashboard teknisi menampilkan tugas yang ditugaskan, progres pengerjaan, serta penyelesaian tiket dengan foto. Beranda pelapor tersedia; beberapa alur lanjutan masih belum dibuat. |
| Mesin tiket (`ReportService`) & query (`ReportRepository`) | Ada, siap dipakai UI | Buat tiket + anti-duplikasi + upvote (`submitReport`), ubah status dengan state machine (`updateReportStatus`), konfirmasi penyelesaian oleh pelapor (`confirmResolution`), otorisasi peran, audit log, serta query real-time & lookup QR (`ReportRepository`). Tersedia juga lewat `Provider` di `main.dart`. |
| Klasifikasi AI (`AiClassifierService`) | Ada, belum dipakai UI | Gemini 2.5 Flash bila `GEMINI_API_KEY` diberikan; selain itu heuristik kata kunci. Sudah didaftarkan di `MultiProvider` pada `main.dart`. |
| Seeder master data | Ada | Aksi manual admin di dashboard admin (`SeedMasterDataButton`). |
| Aturan keamanan & indeks (`firestore.rules`, `firestore.indexes.json`) | Ada | Perlu di-deploy sendiri (lihat [Deploy Firestore Rules & Indexes](#5-deploy-firestore-rules--indexes)). |
| Pemindai QR (`mobile_scanner`) | Belum UI | Dependensi, izin kamera (Android `CAMERA`, iOS `NSCameraUsageDescription`), dan `ReportRepository.getLocationByQr` sudah ada; layar pemindai QR belum dibuat. |
| Foto kerusakan (`PhotoStore`, `ReportPhoto`) | Layanan & widget ada, belum ada UI picker | `FirestorePhotoStore` mengompres gambar (`< 200 KB`, maks 1024 px) dan menyimpannya sebagai base64 di `report_photos/{photoId}` (`"photo:{photoId}"`); widget `ReportPhoto` menampilkan referensi tersebut maupun URL. Layar kamera/galeri (`image_picker`) belum dibuat. |
| Daftar/riwayat tiket, timeline log, konfirmasi pelapor | Layanan ada, belum ada UI | Kontrak `ReportRepository` (`watchReportsForReporter`, `watchReport`, `watchLogs`), `ReportService.confirmResolution`, serta aturan `firestore.rules` sudah tersedia; layar UI belum dibuat. |
| Dashboard antrean admin/teknisi | Sebagian | `AdminDashboard` menyediakan antrean dengan filter status, urgensi, kategori serta aksi verifikasi/penugasan. `TeknisiDashboard` menyediakan daftar tugas, filter status, aksi mulai pengerjaan, dan penyelesaian dengan foto. |

---

## 🔄 Alur Siklus Hidup Tiket (State Machine)

Siklus hidup setiap tiket laporan dikontrol oleh *state machine* ketat pada `ReportService` untuk menjamin integritas alur operasional:

```mermaid
stateDiagram-v2
    [*] --> Reported: Pelapor membuat laporan baru
    Reported --> Verified: Diverifikasi oleh Admin
    Reported --> Rejected: Ditolak oleh Admin (tidak valid)
    Verified --> Assigned: Admin menugaskan Teknisi
    Verified --> Rejected: Ditolak oleh Admin
    Assigned --> InProgress: Teknisi memulai pengerjaan
    InProgress --> Resolved: Teknisi mengunggah bukti perbaikan
    Resolved --> InProgress: Pelapor menolak hasil perbaikan
    Resolved --> [*]
    Rejected --> [*]
```

### Penjelasan Status Tiket:
* **`reported` (Reported / Menunggu Verifikasi):** Aduan berhasil dibuat oleh pelapor dan masuk ke dalam antrean sistem.
* **`verified` (Verified / Terverifikasi Admin):** Admin fasilitas memvalidasi kelayakan fisik dan substansi aduan.
* **`assigned` (Assigned / Teknisi Ditugaskan):** Admin menugaskan teknisi spesifik (`assigned_teknisi_uid`) untuk menangani masalah tersebut.
* **`in_progress` (In Progress / Sedang Dikerjakan):** Teknisi mengonfirmasi bahwa penanganan di lapangan sedang berlangsung.
* **`resolved` (Resolved / Selesai Diperbaiki):** Perbaikan tuntas dan teknisi mengunggah foto bukti penyelesaian (`foto_sesudah_url`).
* **`rejected` (Rejected / Ditolak):** Laporan dibatalkan/ditolak oleh admin disertai alasan tertulis.

### Siapa yang Boleh Mengubah Status

| Status tujuan | Aktor | Syarat tambahan |
|---|---|---|
| `verified` | Admin | |
| `rejected` | Admin | `catatan` (alasan) wajib diisi |
| `assigned` | Admin | `assignedTeknisiUid` wajib dan harus akun berperan `teknisi` |
| `in_progress` | Teknisi yang ditugaskan pada tiket | |
| `resolved` | Teknisi yang ditugaskan pada tiket | `fotoSesudahUrl` wajib |
| `reported` | Tidak ada | Hanya terjadi saat tiket dibuat |
| Konfirmasi / tolak hasil (`resolved` ➔ `resolved` atau `in_progress`) | Pelapor asli tiket | Lewat `ReportService.confirmResolution`; `catatan` wajib diisi jika menolak (`diterima: false`) |

Aturan ini ditegakkan dua kali: di `ReportService` (`canChangeStatus`, `isValidTransition`, `confirmResolution`) dan di `firestore.rules`.

---

## 💡 Fitur Utama Sistem

### 1. Smart Triage & AI Classifier (`AiClassifierService`)
* Memanggil **Google Gemini 2.5 Flash API** untuk menganalisis deskripsi keluhan bila `GEMINI_API_KEY` diberikan lewat `--dart-define` (batas waktu 8 detik). Cara memberikannya ada di [Menjalankan Aplikasi](#6-menjalankan-aplikasi).
* Menentukan kategori fasilitas (AC, Proyektor, Jaringan, Lampu, Toilet, Ruang Kelas) dan tingkat prioritas (*rendah*, *sedang*, *tinggi*, *darurat*). Target SLA mengikuti kategori yang dipilih (`target_sla_jam`), bukan dihitung oleh AI.
* Bila kunci tidak diberikan, perangkat sedang offline, kuota API habis, atau permintaan melewati batas waktu, klasifikasi beralih ke **heuristik kata kunci lokal**. Hasilnya lebih sederhana dan kurang akurat daripada Gemini.

### 2. QR Code Scanner Ruangan & Aset (`mobile_scanner`) — *belum ada UI*
* Menggantikan GPS konvensional yang kerap tidak presisi di area dalam gedung (*indoor*) dan bertingkat.
* Mahasiswa memindai QR Code yang tertera pada pintu ruangan atau stiker aset (contoh: `QR-GDA-101` untuk Gedung A R.101) untuk memastikan akurasi lokasi fasilitas tanpa salah ketik. Nilai QR dicocokkan dengan `locations/{id}.kode_ruangan`.

### 3. Deteksi Anti-Duplikasi & Auto-Upvoting
* Setiap pasangan lokasi + kategori hanya boleh punya satu tiket aktif. Pengecekan dan pembuatan tiket terjadi dalam **satu transaksi Firestore** lewat dokumen kunci `active_tickets/{locationId}_{categoryId}`, sehingga dua pelapor yang bersamaan tidak bisa membuat dua tiket aktif yang sama.
* Jika keluhan sudah pernah dilaporkan dan masih berstatus aktif (*Reported*, *Verified*, *Assigned*, atau *In Progress*), laporan baru otomatis digabungkan (*merged*) dan akun pelapor didaftarkan sebagai pendukung tiket tersebut (+1 Upvote). Pelapor yang sudah tercatat sebagai pendukung tidak dihitung dua kali (`already_supported`).
* Dokumen kunci dihapus dalam transaksi yang sama saat tiket menjadi *Resolved* atau *Rejected*; kunci basi (tiket hilang atau sudah selesai) otomatis ditimpa tiket baru.

### 4. SLA (Service Level Agreement) Tracking
Setiap kategori fasilitas memiliki target batas waktu penanganan (`sla_deadline` = jam perangkat saat laporan dibuat + `target_sla_jam`):
* ⚡ **Lampu & Kelistrikan:** Darurat (Target SLA: 2 Jam)
* ❄️ **AC & Pendingin Ruangan:** Tinggi (Target SLA: 6 Jam)
* 📽️ **Proyektor & Presentasi:** Tinggi (Target SLA: 4 Jam)
* 📶 **Jaringan Wi-Fi & LAN:** Tinggi (Target SLA: 4 Jam)
* 🚰 **Toilet & Sanitasi:** Sedang (Target SLA: 8 Jam)
* 🪑 **Ruang Kelas (Inventaris):** Rendah (Target SLA: 24 Jam)

### 5. Atomic Audit Trail Logging
Setiap mutasi status laporan dicatat ke sub-koleksi `reports/{reportId}/logs` dalam transaksi yang sama dengan perubahan status. Log mendokumentasikan:
* ID & nama aktor pengubah status
* Peran aktor (*Admin*, *Teknisi*, atau *Pelapor* untuk log awal pembuatan tiket)
* Status sebelum dan status sesudah
* Catatan pengerjaan atau verifikasi
* *Timestamp* server: `created_at` dipaksa sama dengan `request.time` oleh `firestore.rules`, sehingga tidak bisa diisi dengan jam perangkat

Rules juga memastikan log hanya bisa dibuat oleh aktor yang berwenang atas perubahan status tersebut (atau pelapor yang membuat tiket, untuk log awal), dan tidak bisa diubah atau dihapus setelah dibuat.

---

## 🗄️ Skema Basis Data (Cloud Firestore)

```text
Firestore Root
├── categories/ {categoryId}
│   ├── id: string (e.g. "cat_ac")
│   ├── nama_objek: string
│   ├── prioritas_default: string ("rendah" | "sedang" | "tinggi" | "darurat")
│   └── target_sla_jam: number
│
├── locations/ {locationId}
│   ├── id: string (e.g. "loc_r101")
│   ├── kode_ruangan: string (e.g. "QR-GDA-101")
│   ├── nama_gedung: string
│   ├── nama_ruangan: string
│   └── lantai: number
│
├── users/ {uid}                          # uid = Firebase Auth UID
│   ├── nama: string
│   ├── identity_number: string           # NIM (9 digit) / NIP (18 digit)
│   ├── email: string
│   ├── sub_role: string ("mahasiswa" | "dosen" | "staf" | "admin" | "teknisi")
│   ├── role: string ("pelapor" | "admin" | "teknisi")
│   ├── fcm_tokens: string[]              # diisi kosong saat daftar; belum dipakai
│   └── created_at: Timestamp (server)
│
├── active_tickets/ {locationId}_{categoryId}   # kunci anti-duplikasi, 1 tiket aktif per lokasi+kategori
│   ├── report_id: string                 # ID dokumen di reports/
│   ├── location_id: string
│   ├── category_id: string
│   └── created_at: Timestamp (server)
│
├── report_photos/ {photoId}              # foto terkompresi (< 200 KB biner), direferensikan sbg "photo:{photoId}"
│   ├── data_base64: string               # base64 JPEG (<= 275.000 karakter)
│   ├── mime_type: string                 # "image/jpeg"
│   ├── owner_uid: string                 # UID pengunggah
│   └── created_at: Timestamp (server, == request.time)
│
└── reports/ {reportId}
    ├── ticket_number: string (format "TKT-YYYYMMDD-XXXXXX": tanggal jam perangkat + 6 karakter pertama {reportId}, e.g. "TKT-20261117-aB3xK9")
    ├── reporter_uid: string
    ├── reporter_name: string
    ├── reporter_sub_role: string ("mahasiswa" | "dosen" | "staf")
    ├── location_id: string
    ├── kode_ruangan: string
    ├── nama_gedung: string
    ├── nama_ruangan: string
    ├── category_id: string
    ├── nama_objek: string
    ├── prioritas: string
    ├── prioritas_rank: number (1="darurat" | 2="tinggi" | 3="sedang" | 4="rendah", untuk sorting antrean)
    ├── target_sla_jam: number
    ├── deskripsi: string
    ├── foto_sebelum_url: string          # "photo:{photoId}" atau URL http/https
    ├── foto_sesudah_url: string | null   # "photo:{photoId}" atau URL http/https
    ├── status: string ("reported" | "verified" | "assigned" | "in_progress" | "resolved" | "rejected")
    ├── assigned_teknisi_uid: string | null
    ├── assigned_teknisi_nama: string | null
    ├── upvotes_count: number
    ├── supporter_uids: string[]          # daftar UID pelapor & pendukung (untuk query riwayat & anti-duplikasi)
    ├── confirmed_by_reporter: boolean
    ├── created_at: Timestamp (server)
    ├── sla_deadline: Timestamp           # jam perangkat saat dibuat + target_sla_jam
    ├── updated_at: Timestamp (server)
    │
    ├── [subcollection] supporters/ {userUid}
    │   ├── user_uid: string
    │   ├── nama: string
    │   └── created_at: Timestamp (server)
    │
    └── [subcollection] logs/ {logId}
        ├── actor_uid: string
        ├── actor_nama: string
        ├── actor_role: string
        ├── status_lama: string | null
        ├── status_baru: string
        ├── catatan: string
        └── created_at: Timestamp (server, == request.time)
```

### Ringkasan Aturan Keamanan (`firestore.rules`)

Role pengguna selalu dibaca dari `users/{uid}.role`, bukan dari data kiriman klien.

| Koleksi | Baca | Tulis |
|---|---|---|
| `categories`, `locations` | Pengguna login | Admin |
| `users/{uid}` | Pemilik akun, atau admin | **Buat:** pemilik, hanya `role: pelapor` dengan `sub_role` `mahasiswa`/`dosen`/`staf`. **Ubah:** pemilik (tanpa mengubah `role` dan `sub_role`), atau admin untuk akun lain. **Hapus:** tidak ada. |
| `report_photos/{photoId}` | Pengguna login | **Buat:** pengguna login dengan `owner_uid == request.auth.uid`, `data_base64 <= 275.000` karakter, `created_at == request.time`. **Ubah/Hapus:** tidak ada. |
| `active_tickets` | Pengguna login | Hanya bersamaan dengan tiket yang dibuat, dibuka ulang oleh pelapor (`confirmResolution`), atau diselesaikan/ditolak (lewat `ReportService`) |
| `reports` | Pengguna login | **Buat:** pelapor, kondisi awal baku (`supporter_uids == [uid]`, `prioritas_rank in [1..4]`). **Ubah:** admin/teknisi sesuai tabel peran, upvote +1 (`supporter_uids`), konfirmasi/tolak hasil oleh pelapor asli. **Hapus:** tidak ada. |
| `reports/*/supporters` | Pengguna login | Pemilik, dibuat sekali |
| `reports/*/logs` | Pengguna login | Aktor berwenang (termasuk pelapor asli untuk log awal dan konfirmasi/tolak hasil), `created_at == request.time`, tidak bisa diubah atau dihapus |

---

## 🧩 Kontrak Service, Repository & PhotoStore (untuk tim UI)

Seluruh layanan inti sudah didaftarkan di `MultiProvider` pada `lib/main.dart` (`AuthService`, `ReportService`, `ReportRepository`, `PhotoStore`, `AiClassifierService`), sehingga UI dapat langsung mengambilnya via `context.read<...>()` setelah `Firebase.initializeApp`.

### 1. Mutasi & State Machine (`ReportService`)

```dart
final service = context.read<ReportService>();

// Buat laporan, atau gabung ke tiket aktif yang sama (+1 upvote).
final hasil = await service.submitReport(
  reporter: appUser,              // AppUser dari AuthService.watchAppUser
  location: lokasi,               // CampusLocation
  category: kategori,             // FacilityCategory
  deskripsi: 'AC tidak dingin',
  fotoSebelumUrl: photoRef,       // "photo:{photoId}" dari PhotoStore atau URL
  aiSuggestedPriority: 'tinggi',  // opsional; default = prioritas_default kategori
);
// hasil['merged'] (bool), hasil['ticket_number'], hasil['message'],
// hasil['already_supported'] (hanya ada bila merged == true)

// Ubah status tiket (Admin / Teknisi).
await service.updateReportStatus(
  reportId: reportId,
  actorUid: auth.currentUser!.uid,  // hanya UID; role & nama dibaca dari users/{uid}
  newStatus: ReportStatus.assigned,
  catatan: 'Ditugaskan ke teknisi gedung A',
  assignedTeknisiUid: teknisiUid,   // wajib & hanya untuk assigned
  fotoSesudahUrl: null,             // wajib untuk resolved
);

// Konfirmasi atau tolak hasil perbaikan oleh pelapor asli pada tiket `resolved`.
await service.confirmResolution(
  reportId,
  auth.currentUser!.uid,
  diterima: true,                   // false -> status kembali ke in_progress & catatan wajib diisi
  catatan: 'AC sudah dingin kembali',
);
```

| Anggota `ReportService` | Keterangan |
|---|---|
| `Future<Map<String, dynamic>> submitReport({reporter, location, category, deskripsi, fotoSebelumUrl, aiSuggestedPriority})` | Satu transaksi: cek kunci `active_tickets`, lalu merge-upvote (`supporter_uids`, `upvotes_count`) atau buat tiket (`prioritas_rank`, `supporter_uids`) + supporter + log awal + kunci. |
| `Future<void> updateReportStatus({reportId, actorUid, newStatus, catatan, assignedTeknisiUid, fotoSesudahUrl})` | Satu transaksi: otorisasi peran, validasi transisi dan parameter, update tiket, hapus kunci (bila `resolved`/`rejected`), tulis log. |
| `Future<void> confirmResolution(String reportId, String actorUid, {required bool diterima, String? catatan})` | Satu transaksi khusus pelapor asli pada tiket `resolved`: menerima (`confirmed_by_reporter = true`) atau menolak (`status = in_progress`, pulihkan kunci `active_tickets` bila kosong, `catatan` wajib), plus tulis log audit. |
| `static bool isValidTransition(ReportStatus current, ReportStatus next)` | Transisi sah menurut state machine. |
| `static bool canChangeStatus({role, actorUid, newStatus, currentAssignedUid})` | Tabel peran untuk `updateReportStatus` (untuk menampilkan/menyembunyikan tombol di UI). |
| `static String activeTicketKey(String locationId, String categoryId)` | ID dokumen `active_tickets`. |
| `static String ticketNumberFor(DateTime date, String reportId)` | Nomor tiket `TKT-YYYYMMDD-XXXXXX`. |

### 2. Query & Stream Data (`ReportRepository`)

Semua query UI menggunakan `ReportRepository` (`lib/services/report_repository.dart`) tanpa menulis query Firestore langsung di layar. Indeks kompositnya didefinisikan di `firestore.indexes.json`.

| Anggota `ReportRepository` | Keterangan |
|---|---|
| `Future<CampusLocation?> getLocationByQr(String kodeRuangan)` | Mencari lokasi berdasarkan isi QR Code (`locations.kode_ruangan`). |
| `Stream<List<FacilityCategory>> watchCategories()` | Stream 6 master kategori diurutkan menurut `target_sla_jam`. |
| `Stream<List<CampusLocation>> watchLocations()` | Stream master lokasi diurutkan menurut gedung lalu nama ruangan. |
| `Stream<List<Report>> watchReportsForReporter(String uid)` | Stream laporan yang dibuat (`reporter_uid == uid`) atau didukung (`supporter_uids array-contains uid`), diurutkan `prioritas_rank` lalu `created_at`. |
| `Stream<List<Report>> watchReportsForAdmin({ReportStatus? status, String? prioritas})` | Stream antrean laporan admin dengan filter opsional `status` dan `prioritas`, diurutkan `prioritas_rank` lalu `created_at`. *(Filter kategori dapat dilakukan di sisi klien pada `report.categoryId`.)* |
| `Stream<List<Report>> watchReportsForTeknisi(String uid)` | Stream tugas laporan yang ditugaskan kepada teknisi `uid`, diurutkan `prioritas_rank` lalu `created_at`. |
| `Stream<Report?> watchReport(String id)` | Stream detail satu laporan secara real-time (`null` bila tidak ada). |
| `Stream<List<ReportLog>> watchLogs(String reportId)` | Stream audit trail `reports/{reportId}/logs` secara kronologis (`created_at` ASC). |
| `Future<List<AppUser>> listTeknisi()` | Daftar akun berperan `teknisi` untuk dialog penugasan admin (aturan Firestore hanya mengizinkan `admin`). |

### 3. Penyimpanan & Penampil Foto (`PhotoStore` & `ReportPhoto`)

* **Unggah (`PhotoStore` / `FirestorePhotoStore`):** panggil `await context.read<PhotoStore>().uploadPhoto(file)` (atau `FirestorePhotoStore.shared.uploadPhoto(file)`). Foto otomatis dikompres bertahap (`1024px`, kualitas `60 -> 45 -> 35 -> 25`) hingga `< 200 KB`, disimpan sebagai base64 di `report_photos/{photoId}`, dan mengembalikan string referensi `"photo:{photoId}"` untuk dikirim ke `fotoSebelumUrl` / `fotoSesudahUrl`.
* **Tampil (`ReportPhoto`):** gunakan `ReportPhoto(ref: report.fotoSebelumUrl)` (`lib/widgets/report_photo.dart`) yang mendukung baik referensi `"photo:{photoId}"` (dengan cache memori) maupun URL `http`/`https`.

### 4. Panduan Singkat per Anggota UI & AI

Lihat pembagian kepemilikan file lengkap dan aturan PR di [docs/PEMBAGIAN_FILE.md](docs/PEMBAGIAN_FILE.md):
* **Aldrik (`lib/screens/report/`):** Scan QR ➔ `getLocationByQr` / pilih dari `watchLocations()` ➔ isi deskripsi ➔ `AiClassifierService.classifyComplaint` ➔ ambil foto ➔ `PhotoStore.uploadPhoto` ➔ `ReportService.submitReport`.
* **Rafi (`lib/screens/tracking/`):** Daftar riwayat via `watchReportsForReporter(uid)` ➔ detail via `watchReport(id)` & `watchLogs(id)` ➔ foto via `ReportPhoto` ➔ konfirmasi hasil via `ReportService.confirmResolution`.
* **Vincent (`lib/screens/home/admin_dashboard.dart`, `teknisi_dashboard.dart`):** Antrean admin via `watchReportsForAdmin`, daftar teknisi via `listTeknisi()`, tugas teknisi via `watchReportsForTeknisi(uid)`, mutasi status via `canChangeStatus` + `updateReportStatus`, foto sesudah via `PhotoStore.uploadPhoto`. *Pertahankan `SeedMasterDataButton()` di `AdminDashboard`.*
* **Yosia (`lib/services/ai_classifier_service.dart`):** Kembangkan `AiClassifierService.classifyComplaint` (termasuk validasi output JSON Gemini terhadap 6 ID kategori & 4 level prioritas) dan unit test-nya.

Catatan:
* **Perubahan dari versi lama:** `updateReportStatus` kini menerima `actorUid` (String), bukan `actor: AppUser`, dan parameter `assignedTeknisiNama` dihapus (nama teknisi diambil dari `users/{assignedTeknisiUid}`). Kode yang masih memakai signature lama tidak akan lolos kompilasi.
* Pelanggaran aturan dilaporkan sebagai `Exception` dengan pesan berawalan `403 Forbidden:` (tidak berwenang) atau `422 ...` (transisi/validasi gagal); tiket yang tidak ada: `Laporan tidak ditemukan.`
* Transaksi Firestore membutuhkan koneksi; saat offline akan gagal.

---

## 🛠️ Tech Stack & Dependensi

* **Platform & SDK:** Flutter **≥ 3.35** (Dart `^3.9.2`, lihat `pubspec.yaml`). Diuji dengan Flutter 3.35.3 / Dart 3.9.2.
* **Backend as a Service (BaaS):**
  * `firebase_core: ^5.1.0` - Inisialisasi Firebase App
  * `firebase_auth: ^7.0.1` - Autentikasi Pengguna
  * `cloud_firestore: ^7.1.0` - Database Real-Time NoSQL
* **State Management:**
  * `provider: ^6.1.5+1` - Pengelolaan State Aplikasi (`AuthService`, `ReportService`, `ReportRepository`, `PhotoStore`, `AiClassifierService`)
* **Network & Intelligence:**
  * `http: ^1.6.0` - Komunikasi REST API ke Google Gemini 2.5 Flash
* **Kompresi Foto:**
  * `flutter_image_compress: ^2.5.1` - Dipakai oleh `FirestorePhotoStore` sebelum menyimpan foto sebagai base64 di Firestore
* **Terpasang, belum dipakai di layar UI:**
  * `mobile_scanner: ^7.4.2` - Pemindai Barcode/QR Code Ruangan & Aset
  * `image_picker: ^1.2.2` - Pengambilan Gambar dari Kamera & Galeri
  * `intl: ^0.20.3` - Format tanggal/waktu di UI

---

## 📁 Struktur Direktori

```
.
├── docs/
│   └── PEMBAGIAN_FILE.md              # Kepemilikan file & aturan Git/PR per anggota
├── firebase.json                      # Konfigurasi Firebase CLI (rules & indexes Firestore) & FlutterFire
├── firestore.indexes.json             # Indeks komposit Cloud Firestore untuk query ReportRepository
├── firestore.rules                    # Aturan keamanan Cloud Firestore
├── pubspec.yaml
├── android/ ios/ linux/ macos/ web/   # Proyek platform (android/app/google-services.json sudah ter-commit)
├── lib/
│   ├── firebase_options.dart          # Konfigurasi platform Firebase (FlutterFire CLI)
│   ├── main.dart                      # Entry point: init Firebase, MultiProvider, AuthGate
│   ├── models/
│   │   └── report_models.dart         # AppUser, CampusLocation, FacilityCategory, Report, ReportLog, Supporter, enum
│   ├── screens/
│   │   ├── auth_gate.dart             # Navigasi berbasis peran (login / verifikasi email / beranda per role)
│   │   ├── auth/                      # login, register, lupa password, verifikasi email
│   │   ├── home/                      # pelapor_home, admin_dashboard, teknisi_dashboard, role_home_scaffold (masih placeholder)
│   │   └── profile/
│   │       └── profile_screen.dart    # Lihat profil, ubah nama, keluar
│   ├── services/
│   │   ├── ai_classifier_service.dart # Klasifikasi AI (Gemini 2.5 Flash) + heuristik lokal
│   │   ├── auth_service.dart          # Firebase Auth + profil users/{uid}
│   │   ├── firebase_seeder.dart       # Seeder master data (6 kategori & 10 lokasi), dipicu manual admin
│   │   ├── photo_store.dart           # Kompresi & penyimpanan foto terkompresi di report_photos/{photoId}
│   │   ├── report_repository.dart     # Query real-time & lookup Firestore untuk seluruh modul UI
│   │   └── report_service.dart        # State machine, anti-duplikasi, konfirmasi pelapor, audit log
│   ├── utils/
│   │   └── validators.dart            # Validator form (email kampus, NIM/NIP, password)
│   └── widgets/
│       ├── loading_button.dart
│       ├── report_photo.dart          # Penampil foto laporan ("photo:{photoId}" atau URL http/https)
│       └── seed_master_data_button.dart  # Tombol "Isi Data Master" di dashboard admin
└── test/
    ├── firebase_seeder_test.dart
    ├── report_models_test.dart
    ├── report_service_test.dart
    ├── seed_master_data_button_test.dart
    ├── validators_test.dart
    └── widget_test.dart
```

---

## 🚀 Panduan Memulai (Getting Started)

### 1. Prasyarat
* [Flutter SDK](https://docs.flutter.dev/get-started/install) **versi minimal 3.35** (membawa Dart 3.9.2; versi lebih lama gagal pada `flutter pub get`)
* Android Studio / Xcode dengan emulator atau perangkat fisik (diperlukan kamera untuk QR Scanner)
* [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`) dan akses ke proyek Firebase `sifasilitas-kampus`, untuk men-deploy `firestore.rules`
* Konfigurasi Firebase sudah ada di repo: `lib/firebase_options.dart` dan `android/app/google-services.json`. `GoogleService-Info.plist` tidak diperlukan (inisialisasi lewat `firebase_options.dart`; berkas itu masuk `.gitignore`).

### 2. Instalasi Dependensi
Jalankan perintah berikut di terminal root proyek:
```bash
flutter pub get
```

### 3. Membuat Akun Admin & Teknisi
Pendaftaran di aplikasi hanya menghasilkan akun **pelapor** dengan email kampus (`@students.usu.ac.id` atau `@usu.ac.id`) dan `sub_role` `mahasiswa`/`dosen`/`staf`. `firestore.rules` menolak pendaftaran atau perubahan role/sub_role mandiri selain itu, jadi akun admin dan teknisi **harus** disiapkan lewat Firebase Console. Admin pertama pun harus dibuat dengan cara ini.

**Cara A, dari akun yang sudah mendaftar:**
1. Daftar lewat aplikasi seperti pelapor biasa.
2. Buka Firebase Console → Firestore Database → `users/{uid}` milik akun itu.
3. Ubah `role` menjadi `admin` atau `teknisi`, dan `sub_role` dengan nilai yang sama (`admin` / `teknisi`).
4. `AuthGate` mengikuti perubahan secara real-time; akun langsung diarahkan ke dashboard sesuai role. Verifikasi email hanya diwajibkan untuk pelapor.

**Cara B, tanpa mendaftar di aplikasi (email bebas):**
1. Firebase Console → Authentication → Add user (email + password).
2. Firestore → buat dokumen `users/{uid}` dengan ID = UID akun tersebut dan field: `nama` (string), `identity_number` (string), `email` (string), `role` (`admin`/`teknisi`), `sub_role` (`admin`/`teknisi`), `created_at` (timestamp).
3. Tanpa dokumen `users/{uid}`, akun yang masuk akan melihat layar "Profil akun tidak ditemukan".

### 4. Pengisian Data Awal (Master Data Seeder)
Master data (6 kategori fasilitas dan 10 lokasi/QR code ruangan) diisi **manual, sekali jalan, oleh admin**. Seeder tidak dipanggil otomatis dari `main()`, karena `firestore.rules` hanya mengizinkan admin menulis koleksi `categories` dan `locations`.

1. Deploy rules & indeks ([langkah 5](#5-deploy-firestore-rules--indexes)).
2. Siapkan akun admin ([langkah 3](#3-membuat-akun-admin--teknisi)).
3. Masuk sebagai admin, buka **Dashboard Admin**, tekan **Isi Data Master** lalu konfirmasi.

`FirebaseSeeder.seedMasterDataIfNeeded()` memeriksa `categories` dan `locations` secara terpisah: koleksi yang sudah berisi dilewati, sehingga aman dijalankan ulang.

### 5. Deploy Firestore Rules & Indexes
Repo belum memiliki `.firebaserc`, jadi proyek harus disebut eksplisit. Perintah berikut men-deploy `firestore.rules` sekaligus `firestore.indexes.json`:
```bash
firebase login
firebase deploy --only firestore --project sifasilitas-kampus
```
Untuk hanya memeriksa sintaks tanpa merilis apa pun, tambahkan `--dry-run`. Rules dan indeks harus di-deploy ulang setiap kali `firestore.rules` atau `firestore.indexes.json` berubah; aplikasi tidak akan bisa menulis `categories`, `locations`, `report_photos`, log tiket, atau menjalankan query `ReportRepository` sebelum konfigurasi terbaru aktif.

### 6. Menjalankan Aplikasi
```bash
flutter run --dart-define=GEMINI_API_KEY=<kunci-gemini-anda>
```
`GEMINI_API_KEY` dibaca saat build lewat `String.fromEnvironment` (`AiClassifierService`). Tanpa kunci ini aplikasi tetap berjalan dan memakai heuristik kata kunci lokal.

Agar kunci tidak tertinggal di riwayat shell, simpan di `env.json` (sudah di-`.gitignore`) lalu jalankan dengan `--dart-define-from-file`:
```json
{ "GEMINI_API_KEY": "<kunci-gemini-anda>" }
```
```bash
flutter run --dart-define-from-file=env.json
```
Kunci yang diberikan lewat `--dart-define` ikut tertanam di berkas aplikasi hasil build, jadi jangan membagikan build yang memuat kunci pribadi dan jangan pernah meng-commit kunci tersebut.

### 7. Menjalankan Test
```bash
flutter analyze
flutter test
```
