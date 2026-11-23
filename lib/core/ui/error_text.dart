import 'package:flutter/foundation.dart';

import 'package:habit_tracker/core/api/api_exception.dart';

/// Pesan yang aman ditampilkan ke pengguna untuk error apa pun.
String errorMessageOf(Object error) {
  if (error is ApiException) return error.message;

  // Bukan ApiException = bug (mis. parsing JSON). Detail teknis hanya untuk developer.
  if (kDebugMode) debugPrint('Error tak terduga: $error');
  return 'Terjadi kesalahan tak terduga. Coba lagi.';
}
