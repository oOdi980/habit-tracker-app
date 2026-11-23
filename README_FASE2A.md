# Habit Tracker, Fase 2a (Flutter: Android + Web/PWA)

Isi zip: `lib/`, `test/`, dan file ini. Project Flutter-nya belum ada, jadi dibuat dulu (langkah 1).

## 1. Buat project (sekali saja)

Di terminal Laragon, di folder tempat kamu menyimpan project (mis. sejajar dengan `habit-tracker-api`):

```
flutter create --org com.odianjal --project-name habit_tracker --platforms=android,web habit_tracker_app
cd habit_tracker_app
```

`--project-name habit_tracker` WAJIB persis begitu: semua import di kode memakai `package:habit_tracker/...`.

## 2. Pasang kode

1. Hapus file bawaan yang akan bentrok: `test\widget_test.dart` (merujuk `MyApp` yang tidak ada lagi).
2. Extract zip ke root project, pilih overwrite (`lib\main.dart` akan tertimpa).
3. Pasang dependency (versinya dikunci sengaja, lihat catatan di bawah):

```
flutter pub add flutter_riverpod:^2.6.1 dio flutter_secure_storage:^9.2.4
```

4. Cek:

```
flutter analyze
flutter test
```

Kirim outputnya kalau ada yang merah. Kode ini belum pernah dikompilasi (sandbox tidak punya Dart SDK).

## 3. Jalankan (web, jalur tercepat)

Terminal 1 (folder API):

```
php artisan serve
```

Terminal 2 (folder app):

```
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Alamat API selalu diberikan lewat `--dart-define`, tidak ditulis di kode. Build rilis tanpa
`API_BASE_URL` sengaja gagal saat start.

Kalau layar bilang "Tidak bisa terhubung ke server" padahal `php artisan serve` hidup: buka DevTools Chrome (F12) > Console.
Pesan "blocked by CORS policy" berarti CORS Laravel perlu disetel; kabari saja.

## 4. Alur uji

1. Daftar akun pertama (kode undangan kosong), buat sesi.
2. Menu kanan atas > "Undang partner" > "Buat kode".
3. Buka alamat yang sama (`http://localhost:<port>`, tertulis di terminal) di jendela incognito dan daftar akun kedua dengan kode itu.
   Token disimpan per profil browser, jadi dua akun tidak bisa login bersamaan di jendela biasa yang sama.
4. Tab "Habit" > "Habit baru". Coba satu pribadi dan satu bersama; habit bersama harus disetujui akun lain.
5. Habit baru mulai dihitung SENIN DEPAN (aturan server), jadi papan "Hari ini" kosong. Untuk mencoba check-in sekarang
   (hanya di database dev), mundurkan tanggal mulainya ke Senin minggu ini lewat DBeaver:

```sql
UPDATE habits SET starts_on = '2026-11-09' WHERE id = <id habit>;
```

   (Senin minggu ini harus benar-benar hari Senin; ada CHECK di database.) Lalu tarik layar "Hari ini" ke bawah untuk memuat ulang.
   Hapus/abaikan habit uji itu sebelum mulai dipakai sungguhan: jadwal evaluasi Senin akan ikut menilainya.

## 5. Android (opsional untuk sekarang)

Dua perubahan manual di project hasil `flutter create`:

1. `android/app/src/main/AndroidManifest.xml`: tambahkan tepat di atas `<application`:
   `<uses-permission android:name="android.permission.INTERNET"/>`
   Tanpa ini APK rilis tidak punya akses internet sama sekali (template Flutter hanya menaruhnya di build debug).
2. `android/app/src/debug/AndroidManifest.xml`: di dalam `<manifest>`, tambahkan
   `<application android:usesCleartextTraffic="true"/>`
   supaya build debug boleh memakai `http://` ke laptop. Jangan taruh ini di manifest utama.

Emulator Android menjangkau laptop lewat `http://10.0.2.2:8000` (sudah jadi default di kode). HP asli butuh
`php artisan serve --host=0.0.0.0`, IP LAN laptop di `--dart-define=API_BASE_URL=http://<ip>:8000`, dan firewall Windows yang mengizinkan port 8000.

## Catatan versi

- `flutter_riverpod` dikunci di 2.x. Versi 3 mengubah API notifier; jangan `pub upgrade --major-versions` sebelum kita sengaja migrasi.
- `flutter_secure_storage` dikunci di 9.x (v10 mengubah opsi Android).
- Dependency lain (`dio`) dibiarkan mengikuti versi stabil terbaru.
