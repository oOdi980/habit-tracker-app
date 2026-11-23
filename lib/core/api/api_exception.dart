/// Jenis kegagalan panggilan API. UI cukup memeriksa jenis ini, tidak perlu tahu kode HTTP.
enum ApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
  server,
  unknown,
}

/// Satu-satunya jenis error yang keluar dari lapisan API. Pesannya sudah berbahasa Indonesia
/// dan layak ditampilkan langsung ke pengguna.
class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors = const <String, List<String>>{},
    this.retryAfterSeconds,
  });

  const ApiException.network()
      : this(
          type: ApiErrorType.network,
          message: 'Tidak bisa terhubung ke server. Cek koneksi internet kamu.',
        );

  const ApiException.timeout()
      : this(
          type: ApiErrorType.timeout,
          message: 'Server terlalu lama merespons. Coba lagi.',
        );

  const ApiException.unexpected([String message = 'Terjadi kesalahan tak terduga. Coba lagi.'])
      : this(type: ApiErrorType.unknown, message: message);

  /// Menerjemahkan respons error server (status + body JSON yang sudah di-decode).
  /// Bentuk error Laravel: `{"message": "..."}` dan, untuk 422, `{"errors": {"field": ["..."]}}`.
  factory ApiException.fromResponse(int? statusCode, Object? body, {String? retryAfter}) {
    final map = body is Map ? body : const <String, dynamic>{};
    final rawMessage = map['message'];
    final serverMessage = rawMessage is String && rawMessage.trim().isNotEmpty ? rawMessage.trim() : null;
    final fieldErrors = _parseFieldErrors(map['errors']);

    if (statusCode == 401) {
      return ApiException(
        type: ApiErrorType.unauthorized,
        // Login yang salah membawa pesan Indonesia dari server; bawaan Laravel (Inggris) diganti.
        message: serverMessage != null && serverMessage != 'Unauthenticated.'
            ? serverMessage
            : 'Sesi kamu berakhir. Silakan masuk lagi.',
        statusCode: statusCode,
      );
    }

    if (statusCode == 403) {
      return ApiException(
        type: ApiErrorType.forbidden,
        message: serverMessage != null && serverMessage != 'This action is unauthorized.'
            ? serverMessage
            : 'Kamu tidak punya akses untuk ini.',
        statusCode: statusCode,
      );
    }

    // Pesan 404 bawaan Laravel membocorkan nama model; selalu pakai teks sendiri.
    if (statusCode == 404) {
      return ApiException(
        type: ApiErrorType.notFound,
        message: 'Data tidak ditemukan.',
        statusCode: statusCode,
      );
    }

    if (statusCode == 422) {
      // Pesan field pertama lebih berguna daripada "The given data was invalid."
      String? first;
      for (final messages in fieldErrors.values) {
        if (messages.isNotEmpty) {
          first = messages.first;
          break;
        }
      }
      return ApiException(
        type: ApiErrorType.validation,
        message: first ?? serverMessage ?? 'Data yang dikirim belum benar.',
        statusCode: statusCode,
        fieldErrors: fieldErrors,
      );
    }

    if (statusCode == 429) {
      final seconds = int.tryParse(retryAfter ?? '');
      return ApiException(
        type: ApiErrorType.rateLimited,
        message: seconds != null
            ? 'Terlalu banyak percobaan. Coba lagi dalam $seconds detik.'
            : 'Terlalu banyak percobaan. Coba lagi sebentar lagi.',
        statusCode: statusCode,
        retryAfterSeconds: seconds,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return ApiException(
        type: ApiErrorType.server,
        message: 'Server sedang bermasalah. Coba lagi nanti.',
        statusCode: statusCode,
      );
    }

    return ApiException(
      type: ApiErrorType.unknown,
      message: serverMessage ?? 'Terjadi kesalahan (kode ${statusCode ?? '?'}).',
      statusCode: statusCode,
    );
  }

  final ApiErrorType type;
  final String message;
  final int? statusCode;

  /// Hanya terisi untuk 422: pesan per nama field di body request (mis. "email", "invite_code").
  final Map<String, List<String>> fieldErrors;

  final int? retryAfterSeconds;

  /// Pesan pertama untuk sebuah field, atau null.
  String? errorFor(String field) {
    final messages = fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  static Map<String, List<String>> _parseFieldErrors(Object? raw) {
    if (raw is! Map) return const <String, List<String>>{};

    final result = <String, List<String>>{};
    raw.forEach((key, value) {
      if (value is List) {
        result['$key'] = value.map((item) => '$item').toList();
      } else if (value is String) {
        result['$key'] = [value];
      }
    });
    return result;
  }

  @override
  String toString() => 'ApiException(${type.name}, status: $statusCode): $message';
}
