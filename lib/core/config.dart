import 'package:flutter/foundation.dart';

/// Konfigurasi build. Alamat API diberikan saat run/build, bukan ditulis di kode:
///
///   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
class AppConfig {
  const AppConfig._();

  // String.fromEnvironment harus `const` supaya nilainya ikut tertanam saat compile.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get hasExplicitBaseUrl => _envBaseUrl.isNotEmpty;

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;

    // Emulator Android menjangkau laptop lewat 10.0.2.2 (localhost di emulator = emulator itu sendiri).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Nama perangkat untuk token di server ("web", "android", ...). Tanpa plugin tambahan.
  static String get deviceName => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Build rilis tanpa API_BASE_URL pasti salah (aplikasi akan menembak localhost milik HP).
  /// Lebih baik gagal keras saat start daripada terkirim ke Anjal dalam keadaan "tidak bisa login".
  static void assertConfigured() {
    if (kReleaseMode && !hasExplicitBaseUrl) {
      throw StateError(
        'API_BASE_URL belum diisi. Build rilis wajib memakai --dart-define=API_BASE_URL=https://...',
      );
    }
  }
}
