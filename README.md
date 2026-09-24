# SiFasilitas (Campus Facility Care)

> Aplikasi mobile pelaporan dan penanganan kerusakan fasilitas kampus berbasis multi-peran (*Mahasiswa* & *Admin/Teknisi*).

---

## 📱 Deskripsi Singkat
**SiFasilitas** adalah aplikasi mobile berbasis Flutter yang menjembatani komunikasi antara mahasiswa dengan biro pemeliharaan sarana prasarana kampus. Aplikasi ini menyelesaikan masalah lambatnya penanganan keluhan dan ketiadaan transparansi status perbaikan fasilitas.

Sistem menerapkan autentikasi berbasis peran (*Role-Based Access Control* / RBAC):
* **Mahasiswa:** Melaporkan keluhan fasilitas lengkap dengan foto fisik, penandaan lokasi/ruangan, serta memantau progres perbaikan secara *real-time*.
* **Admin / Teknisi:** Menerima tiket aduan, memperbarui status pengerjaan (*Pending* ➔ *In Progress* ➔ *Resolved*), dan mengunggah foto bukti penyelesaian.

---

## 👥 Anggota Tim

| No | Nama Lengkap | NIM | Peran Utama | Fokus Tanggung Jawab |
|---|---|---|---|---|
| 1 | Wira Hari Pratama | 241402111 | **Project Lead & Core Architecture** | Setup project Flutter, arsitektur folder, state management global, routing navigasi, dan standardisasi UI/Theme. |
| 2 | Leondo Admiral Purba | 241402153 | **Frontend Dev (Auth & Profile)** | Implementasi UI & logika Autentikasi (Login/Register/Logout), validasi form email kampus, dan manajemen profil pengguna. |
| 3 | Aldrik Noel Sianipar | 241402 | **Frontend Dev (Form Laporan & Hardware)** | Fitur pembuatan tiket aduan mahasiswa, integrasi kamera/galeri (`image_picker`), serta penandaan koordinat GPS (`geolocator`). |
| 4 | Rafi Andara Nasution | 241402 | **Frontend Dev (Tracking & Feedback)** | Halaman riwayat aduan mahasiswa, visualisasi timeline status pengerjaan tiket, dan sistem konfirmasi/rating kepuasan. |
| 5 | Vincent Christian Simbolon | 241402 | **Frontend Dev (Dashboard Teknisi/Admin)** | Antarmuka khusus staf: antrean tiket masuk, filter keluhan (kategori/urgensi), aksi update status, dan unggah foto bukti pengerjaan. |
| 6 | Yosia Marcel Simanjuntak | 241402 | **BaaS / Database & Security Engineer** | Konfigurasi Supabase/Firebase, perancangan skema tabel/koleksi, pengaturan *Row Level Security* (RLS) hak akses role, dan manajemen Storage bucket. |

---

## 🚀 Rencana Fitur

### 1. Autentikasi & Manajemen Sesi (Multi-Role)
* **Login & Role-Based Routing:** Pintu masuk login tunggal yang secara otomatis mengarahkan antarmuka pengguna berdasarkan data profil (`role: mahasiswa` atau `role: teknisi/admin`).
* **Registrasi Akun Mahasiswa:** Pembuatan akun dengan validasi email kampus.

### 2. Antarmuka Mahasiswa (Pelapor)
* **Form Buat Laporan (Create Ticket):** Input laporan kerusakan berdasarkan kategori (Kelistrikan, Sanitasi, AC/Pendingin, Audio/Proyektor, Fasilitas Kelas).
* **Integrasi Kamera & Media:** Pengambilan foto bukti kerusakan langsung melalui kamera perangkat atau galeri.
* **Geotagging / Penandaan Lokasi:** Perekaman koordinat lokasi pelapor (GPS) serta pemilihan nama gedung dan nomor ruangan.
* **Pelacakan Tiket (Timeline Tracker):** Visualisasi linimasa status aduan (*Pending*, *Diverifikasi*, *Dikerjakan*, *Selesai*).
* **Konfirmasi & Ulasan:** Memberi feedback atau rating kepuasan setelah fasilitas dinyatakan selesai diperbaiki.

### 3. Antarmuka Teknisi / Admin (Pengelola)
* **Daftar Tiket Masuk (Incoming Queue):** Dashboard tiket terpusat dengan filter kategori, lokasi, dan tingkat urgensi.
* **Perbaruan Status Pekerjaan:** Aksi untuk mengubah status tiket secara berkala.
* **Unggah Bukti Perbaikan:** Teknisi dapat melampirkan foto hasil perbaikan sebelum menutup tiket menjadi *Resolved*.

### 4. Fitur Native & Hardware Mobile
* **Kamera & File Access:** Menggunakan library `image_picker` untuk kompresi dan upload berkas bukti.
* **Location Service (GPS):** Menggunakan `geolocator` untuk memvalidasi posisi pelapor saat berada di radius area kampus.
* **Local Storage / Cache:** Penyimpanan data sementara untuk mempercepat rendering daftar riwayat tiket.

---

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **State Management:** Provider / Riverpod / Bloc
* **Backend as a Service (BaaS):** Supabase / Firebase
  * **Authentication:** BaaS Auth (Email & Password)
  * **Database:** PostgreSQL (Supabase) / Firestore (Firebase)
  * **Storage:** Bucket penyimpanan untuk foto kerusakan & perbaikan