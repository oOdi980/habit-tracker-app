import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/storage/session_store.dart';
import '../support/fakes.dart';

/// Adapter HTTP palsu: tidak ada jaringan, jawaban ditentukan tes.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status, {Map<String, List<String>>? extraHeaders}) {
  return ResponseBody.fromString(
    body,
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?extraHeaders,
    },
  );
}

({ApiClient client, SessionStore store, _FakeAdapter adapter, List<int> unauthorizedCalls}) _setup(
  ResponseBody Function(RequestOptions options) handler,
) {
  final store = SessionStore(MemoryKeyValueStore());
  final adapter = _FakeAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter;
  final unauthorizedCalls = <int>[];

  final client = ApiClient(baseUrl: 'http://api.test', store: store, dio: dio)
    ..onUnauthorized = () => unauthorizedCalls.add(1);

  return (client: client, store: store, adapter: adapter, unauthorizedCalls: unauthorizedCalls);
}

void main() {
  test('GET sukses mengembalikan JSON dan mengirim token sebagai Bearer', () async {
    final t = _setup((options) => _json('{"ok":true}', 200));
    await t.store.saveToken('abc123');

    final body = await t.client.get('/api/auth/me');

    expect(body['ok'], true);
    expect(t.adapter.lastRequest!.headers['Authorization'], 'Bearer abc123');
    expect(t.adapter.lastRequest!.uri.toString(), 'http://api.test/api/auth/me');
  });

  test('tanpa token tidak ada header Authorization', () async {
    final t = _setup((options) => _json('{}', 200));

    await t.client.get('/api/x');

    expect(t.adapter.lastRequest!.headers.containsKey('Authorization'), isFalse);
  });

  test('204 tanpa isi menjadi objek kosong', () async {
    final t = _setup((options) => ResponseBody.fromString('', 204));

    final body = await t.client.delete('/api/habits/1');

    expect(body, isEmpty);
  });

  test('401 dengan token aktif memanggil onUnauthorized dan melempar ApiException', () async {
    final t = _setup((options) => _json('{"message":"Unauthenticated."}', 401));
    await t.store.saveToken('abc123');

    await expectLater(
      t.client.get('/api/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.unauthorized)),
    );
    expect(t.unauthorizedCalls, hasLength(1));
  });

  test('401 saat login (tanpa token) tidak dianggap sesi berakhir', () async {
    final t = _setup((options) => _json('{"message":"Email atau password salah."}', 401));

    await expectLater(
      t.client.post('/api/auth/login', body: {'email': 'a', 'password': 'b'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email atau password salah.')),
    );
    expect(t.unauthorizedCalls, isEmpty);
  });

  test('401 untuk token lama tidak menendang sesi baru', () async {
    late SessionStore store;
    final t = _setup((options) {
      // Sementara request berjalan, pengguna sudah keluar lalu masuk dengan token lain.
      store.saveToken('token-baru');
      return _json('{"message":"Unauthenticated."}', 401);
    });
    store = t.store;
    await t.store.saveToken('token-lama');

    await expectLater(t.client.get('/api/auth/me'), throwsA(isA<ApiException>()));

    expect(t.unauthorizedCalls, isEmpty);
  });

  test('422 membawa error per field', () async {
    final t = _setup(
      (options) => _json('{"message":"x","errors":{"email":["Email sudah terdaftar."]}}', 422),
    );

    await expectLater(
      t.client.post('/api/auth/register', body: {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.type, 'type', ApiErrorType.validation)
            .having((e) => e.errorFor('email'), 'email', 'Email sudah terdaftar.'),
      ),
    );
  });

  test('429 membaca header Retry-After', () async {
    final t = _setup(
      (options) => _json('{"message":"Too Many Attempts."}', 429, extraHeaders: {'retry-after': ['42']}),
    );

    await expectLater(
      t.client.post('/api/auth/login', body: {}),
      throwsA(isA<ApiException>().having((e) => e.retryAfterSeconds, 'retryAfter', 42)),
    );
  });

  test('gagal terhubung menjadi ApiException.network', () async {
    final t = _setup((options) {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    });

    await expectLater(
      t.client.get('/api/x'),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.network)),
    );
  });

  test('timeout menjadi ApiException.timeout', () async {
    final t = _setup((options) {
      throw DioException(requestOptions: options, type: DioExceptionType.receiveTimeout);
    });

    await expectLater(
      t.client.get('/api/x'),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.timeout)),
    );
  });

  test('respons 200 yang bukan JSON (alamat API salah) ditolak dengan jelas', () async {
    final t = _setup(
      (options) => ResponseBody.fromString(
        '<html>Welcome</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );

    await expectLater(
      t.client.get('/api/x'),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.unknown)),
    );
  });
}
