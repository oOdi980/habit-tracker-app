import 'package:dio/dio.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/storage/session_store.dart';
import 'package:habit_tracker/core/util/json.dart';

/// Klien HTTP tunggal ke API Laravel. Semua kegagalan keluar sebagai [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required SessionStore store, Dio? dio})
      // ignore: prefer_initializing_formals
      : _store = store,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _stripTrailingSlashes(baseUrl),
                // Sengaja tanpa sendTimeout: di web, Dio menolak/mengabaikannya untuk request tanpa body.
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: <String, dynamic>{'Accept': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _store.token;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            // Dicatat supaya 401 bisa dibedakan: "token saya ditolak" vs "login gagal" (tanpa token).
            options.extra[_tokenUsedKey] = token;
          }
          handler.next(options);
        },
      ),
    );
  }

  static const String _tokenUsedKey = 'token_used';

  final Dio _dio;
  final SessionStore _store;

  /// Dipanggil bila server menolak token yang sedang dipakai (cabut/kedaluwarsa). Diisi oleh
  /// SessionController; hasilnya: layar kembali ke login.
  void Function()? onUnauthorized;

  Future<Json> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);

  Future<Json> post(String path, {Object? body}) => _send('POST', path, body: body);

  Future<Json> delete(String path) => _send('DELETE', path);

  Future<Json> _send(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return _decode(response.data);
    } on DioException catch (e) {
      final mapped = _mapDioError(e);

      if (mapped.type == ApiErrorType.unauthorized) {
        final used = e.requestOptions.extra[_tokenUsedKey];
        // Hanya bila token yang DITOLAK masih token aktif. Request lama yang baru kembali setelah
        // pengguna keluar lalu masuk sebagai akun lain tidak boleh menendang sesi yang baru.
        if (used != null && used == _store.token) {
          onUnauthorized?.call();
        }
      }
      throw mapped;
    }
  }

  /// 204 / body kosong menjadi objek kosong. Bukan objek JSON (mis. halaman HTML dari server yang
  /// salah alamat) ditolak, bukan dibiarkan jadi null di tengah parsing.
  Json _decode(Object? data) {
    if (data == null || (data is String && data.isEmpty)) return <String, dynamic>{};
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException.unexpected('Respons server tidak dikenali. Cek alamat API.');
  }

  ApiException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException.timeout();
      case DioExceptionType.badResponse:
        return ApiException.fromResponse(
          e.response?.statusCode,
          e.response?.data,
          retryAfter: e.response?.headers.value('retry-after'),
        );
      case DioExceptionType.connectionError:
        return const ApiException.network();
      case DioExceptionType.badCertificate:
        return const ApiException(
          type: ApiErrorType.network,
          message: 'Sertifikat keamanan server tidak valid.',
        );
      default:
        final inner = e.error;
        if (inner is ApiException) return inner;
        return const ApiException.unexpected();
    }
  }

  static String _stripTrailingSlashes(String url) => url.replaceFirst(RegExp(r'/+$'), '');
}
