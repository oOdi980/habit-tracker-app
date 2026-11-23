import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan kunci-nilai minimal. Dipisah dari implementasinya supaya tes tidak butuh plugin.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Android: EncryptedSharedPreferences (kunci di Keystore). Web: WebCrypto + localStorage
/// (hanya berfungsi di HTTPS atau localhost, dan tetap bukan brankas sungguhan di browser).
class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Token login dan sesi terakhir yang dipilih. Nilainya di-cache di memori: ApiClient membaca
/// token di SETIAP request, dan membaca storage terenkripsi sebanyak itu akan boros dan lambat.
///
/// Prinsipnya: kegagalan storage tidak boleh membuat aplikasi macet. Kalau menulis gagal, pengguna
/// tetap login selama aplikasi terbuka (hanya tidak diingat di pembukaan berikutnya).
class SessionStore {
  SessionStore(this._store);

  static const String _tokenKey = 'auth_token';
  static const String _circleKey = 'selected_circle_id';

  final KeyValueStore _store;

  String? _token;
  int? _selectedCircleId;

  String? get token => _token;
  int? get selectedCircleId => _selectedCircleId;

  /// Dipanggil sekali saat aplikasi mulai.
  Future<void> load() async {
    try {
      _token = await _store.read(_tokenKey);
      _selectedCircleId = int.tryParse(await _store.read(_circleKey) ?? '');
    } catch (_) {
      // Isi storage tidak bisa dibaca (mis. hasil restore backup Android yang kuncinya sudah
      // berbeda). Perlakukan sebagai belum login dan bersihkan, jangan crash di layar putih.
      _token = null;
      _selectedCircleId = null;
      try {
        await _store.deleteAll();
      } catch (_) {
        // Sudah tidak ada yang bisa dilakukan.
      }
    }
  }

  Future<void> saveToken(String token) async {
    _token = token; // memori dulu: sesi ini langsung bisa dipakai walau storage gagal
    try {
      await _store.write(_tokenKey, token);
    } catch (_) {
      // Tidak diingat di pembukaan berikutnya; tetap login untuk sesi ini.
    }
  }

  Future<void> setSelectedCircle(int? id) async {
    _selectedCircleId = id;
    try {
      if (id == null) {
        await _store.delete(_circleKey);
      } else {
        await _store.write(_circleKey, '$id');
      }
    } catch (_) {
      // Hanya kenyamanan: pilihan sesi tidak diingat.
    }
  }

  /// Keluar: buang semuanya (akun lain yang masuk berikutnya tidak boleh mewarisi pilihan sesi).
  Future<void> clear() async {
    _token = null;
    _selectedCircleId = null;
    try {
      await _store.delete(_tokenKey);
      await _store.delete(_circleKey);
    } catch (_) {
      // Memori sudah bersih; sisa di storage akan dibersihkan saat load() berikutnya gagal/ditimpa.
    }
  }
}
