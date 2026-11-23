# Dropwatch

Aplikasi Android berbahasa Indonesia untuk menyimpan dan melihat rotasi toko VALORANT dari HP. Antarmuka, katalog, pencarian, wishlist, riwayat dan timer ditulis dengan Dart dan Flutter. Integrasi pemilih gambar Android dan OCR memakai Kotlin.

## Toko pribadi melalui Valoranthub

Versi 1.1.0 dipasang sebagai **Dropwatch Hub** dan bisa berdampingan dengan Dropwatch 1.0. Data lokal masing-masing aplikasi terpisah.

1. Buka **Toko → Lihat toko akun saya**. Gunakan **Kelola API key di Valoranthub** untuk mengakses halaman key pribadi penyedia.
2. Pilih **Penautan akun di Valoranthub** untuk membuka halaman akun penyedia di browser. Jika akun belum muncul untuk key milikmu, buka **Panduan penautan dengan API key** dan gunakan bagian **Riot account linking** dengan key yang sama. Selesaikan penautan dan konfirmasi yang diminta langsung di Valoranthub. Untuk metode login, penyedia menyatakan bahwa informasi login dikirim ke servernya dan disimpan. Baca [panduan penautan Valoranthub](https://valoranttracker.com/premium/mfa/guide) sebelum melanjutkan.
3. Kembali ke aplikasi. Masukkan API key pribadi dan pilih **Hubungkan dan lihat toko**. Jika ada beberapa akun, pilih Riot ID dari daftar tertaut. Layar mengambil data baru setiap dibuka. **Perbarui toko** memuat ulang daftar akun dan penawaran.
4. **Hapus key dari HP** menghapus salinan lokal. Pencabutan key atau penautan akun dikelola melalui Valoranthub.

Dropwatch mengirim key melalui HTTPS hanya ke api.valoranttracker.com. Di perangkat, key dienkripsi dengan kunci Android Keystore. Penawaran dari penyedia tidak ditambahkan ke riwayat manual. Harga dan waktu reset ditampilkan jika tersedia dan dikenali. Jika struktur respons berubah, layar menyediakan tampilan data toko dari penyedia.

API yang digunakan adalah GET /public/v1/me/accounts dan GET /public/v1/me/store?puuid=... dengan header X-API-Key. [Dokumentasi Valoranthub](https://valoranttracker.com/developers/docs)

## Mencatat toko secara manual

1. Ambil screenshot saat halaman toko harian terbuka di game. Pastikan nama skin terbaca, lalu simpan gambar ke HP.
2. Di tab **Toko**, pilih **Impor screenshot**. Pemeriksa teks di perangkat membaca nama skin dan mencocokkannya dengan katalog. Periksa hasilnya. Hapus kecocokan yang salah atau pilih skin yang terlewat. Kamu juga bisa menyimpan screenshot saja atau memasukkan hingga empat skin secara manual.
3. Ketuk skin untuk mengisi harga VP yang tertera di game. Isi sisa jam dan menit rotasi saat ini, lalu ketuk **Simpan rotasi**. Jika screenshot diambil sebelumnya, gunakan sisa waktu terkini.
4. Tab **Toko** menampilkan hitung mundur dan menandai skin yang ada di wishlist. Ketuk screenshot untuk memperbesar. Setelah waktu habis, catatan masih bisa dibuka di **Riwayat rotasi**.

Katalog bawaan memuat 1.396 skin dan 24 ilustrasi lokal. Pencarian dapat menggunakan nama skin, nama senjata, atau keduanya. Simpan skin dari tab **Katalog** dengan ikon bookmark. Aplikasi menyimpan wishlist, rotasi, gambar yang diimpor, dan cache katalog di penyimpanan privat aplikasi. Menghapus data aplikasi akan menghapus catatan tersebut. Sebagian besar ilustrasi di luar 24 aset lokal memerlukan internet.

## Sumber data

| Kebutuhan | Sumber |
| --- | --- |
| Penawaran akun dan harga VP | Screenshot pilihan pengguna atau isian dari toko di game |
| Nama, UUID, jenis senjata, dan ilustrasi | `GET https://valorant-api.com/v1/weapons?language=en-US` |
| Batas waktu penawaran | Sisa waktu yang dikonfirmasi pengguna ketika mencatat rotasi |
| Pengenalan nama | Google ML Kit Text Recognition untuk aksara Latin, dengan model di dalam APK |

Riot menyatakan API developer VALORANT belum menyediakan pelacakan toko pribadi. Untuk mode manual, rotasi baru memerlukan screenshot atau catatan baru. Mode manual dapat digunakan tanpa login Riot, API key, atau server pribadi. Katalog komunitas mencakup berbagai skin game. Keberadaan sebuah skin di katalog tidak menyatakan bahwa skin itu sedang dijual.

Katalog diperbarui saat aplikasi dibuka jika cache lebih dari satu hari, atau melalui ikon perbarui pada tab Katalog. Jika permintaan gagal, aplikasi menggunakan data yang tersedia di perangkat. Foto pilihan pengguna diproses di perangkat. Nama skin yang terbaca bergantung pada bahasa, kejelasan teks, dan kecocokan katalog.

- [Riot Developer Portal untuk VALORANT](https://developer.riotgames.com/docs/valorant)
- [Panduan toko VALORANT dari Riot](https://support.riotgames.com/en-us/valorant/store/guide-to-the-valorant-store)
- [Dokumentasi Valorant-API](https://valorant-api.com/)
- [Dokumentasi OCR Android dari Google](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)

## Menjalankan proyek

Konfigurasi proyek menggunakan Flutter 3.32.8, Dart 3.8, JDK 17, Android SDK 35 dan NDK 27.0.12077973. Versi Android minimum adalah 6.0 (API 23). Buka direktori yang memuat `pubspec.yaml`, kemudian jalankan perintah berikut.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Untuk membuat APK dari source code, jalankan `flutter build apk --release`. Hasilnya berada di `build/app/outputs/flutter-apk/app-release.apk`. Build pertama memerlukan koneksi internet untuk Gradle, dependensi Android, dan komponen SDK. Gradle memakai konfigurasi tanda tangan debug untuk distribusi uji. Untuk menerbitkan versi milikmu, konfigurasikan kunci rilis sendiri di `android/app/build.gradle.kts`.

## Struktur proyek

| Lokasi | Isi |
| --- | --- |
| `lib/data.dart` | Model skin, cache API, pencocokan OCR, penyimpanan dan waktu kedaluwarsa |
| `lib/home.dart`, `lib/editor.dart` | Halaman toko, riwayat, impor screenshot dan editor rotasi |
| `lib/browse.dart`, `lib/design.dart` | Pencarian, wishlist, komponen tampilan dan detail skin |
| `android/app/src/main/kotlin/` | Pemilih gambar dan pemrosesan teks di perangkat |
| `test/widget_test.dart` | Pengujian data dan alur antarmuka |

Dropwatch adalah proyek penggemar independen. VALORANT dan aset game milik Riot Games. Data katalog dan ilustrasi berasal dari Valorant-API. Barlow Condensed menggunakan SIL Open Font License yang disertakan di `assets/fonts/OFL.txt`.

