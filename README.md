# Habit Tracker App

Klien **Flutter** untuk [Habit Tracker API](https://github.com/oOdi980/habit-tracker-api): aplikasi pemantau kebiasaan yang dipakai berdua dan saling memantau progres. Target platform: **Android dan web (PWA)** dari satu codebase.

> **Status:** dalam pengembangan aktif, belum dirilis.

## Fitur

- Login dan daftar (akun berikutnya memakai kode undangan)
- Buat atau gabung sesi, undang partner
- Papan "hari ini" dengan check-in dan undo
- Daftar habit: buat, setujui (untuk habit bersama), hapus

## Stack

Flutter (Dart) · Riverpod · Dio · penyimpanan token terenkripsi

## Struktur

```
lib/
  core/        klien API, penyimpanan sesi, konfigurasi
  features/    satu folder per fitur (auth, ...)
test/          tes unit untuk klien API dan session controller
```

## Catatan teknis

- Autentikasi memakai token Bearer. Token disimpan terenkripsi dan di-cache di memori supaya tiap request tidak membaca storage.
- Penanganan `401` dibedakan: token ditolak server membuat pengguna logout, sedangkan login gagal (tanpa token) bukan sesi berakhir. Respons `401` dari token lama tidak menendang sesi baru.
- Gagal jaringan tidak membuang token. Pengguna diberi layar "tidak bisa terhubung" dan bisa mencoba lagi.
- Alamat server tidak ditulis di kode. Build rilis wajib memakai `--dart-define=API_BASE_URL=https://...`.

## Menjalankan

Prasyarat: Flutter SDK dan API yang berjalan (lihat [habit-tracker-api](https://github.com/oOdi980/habit-tracker-api)).

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

- **Emulator Android** memakai `http://10.0.2.2:8000` secara default.
- **HP asli:** jalankan API dengan `php artisan serve --host=0.0.0.0`, lalu pakai `--dart-define=API_BASE_URL=http://<ip-laptop>:8000` dan izinkan port 8000 di firewall.

Detail langkah ada di [`README_FASE2A.md`](README_FASE2A.md).

## Testing

```bash
flutter test
```
