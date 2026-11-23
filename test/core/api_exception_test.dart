import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/core/api/api_exception.dart';

void main() {
  group('ApiException.fromResponse', () {
    test('401 login salah memakai pesan server', () {
      final e = ApiException.fromResponse(401, {'message': 'Email atau password salah.'});

      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'Email atau password salah.');
    });

    test('401 bawaan Laravel (Inggris) diganti pesan Indonesia', () {
      final e = ApiException.fromResponse(401, {'message': 'Unauthenticated.'});

      expect(e.type, ApiErrorType.unauthorized);
      expect(e.message, 'Sesi kamu berakhir. Silakan masuk lagi.');
    });

    test('403 membawa pesan server, tapi pesan bawaan Inggris diganti', () {
      final custom = ApiException.fromResponse(403, {'message': 'Check-in hanya bisa dilakukan oleh pemilik habit.'});
      expect(custom.type, ApiErrorType.forbidden);
      expect(custom.message, 'Check-in hanya bisa dilakukan oleh pemilik habit.');

      final generic = ApiException.fromResponse(403, {'message': 'This action is unauthorized.'});
      expect(generic.message, 'Kamu tidak punya akses untuk ini.');
    });

    test('404 tidak pernah membocorkan pesan server', () {
      final e = ApiException.fromResponse(404, {'message': 'No query results for model [App\\Models\\Habit] 5'});

      expect(e.type, ApiErrorType.notFound);
      expect(e.message, 'Data tidak ditemukan.');
    });

    test('422 mengambil pesan field pertama dan menyimpan semua error per field', () {
      final e = ApiException.fromResponse(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'email': ['Email sudah terdaftar.'],
          'invite_code': ['Pendaftaran butuh kode undangan dari anggota sesi.', 'Kedua'],
        },
      });

      expect(e.type, ApiErrorType.validation);
      expect(e.message, 'Email sudah terdaftar.');
      expect(e.errorFor('invite_code'), 'Pendaftaran butuh kode undangan dari anggota sesi.');
      expect(e.errorFor('name'), isNull);
      expect(e.fieldErrors['invite_code'], hasLength(2));
    });

    test('422 tanpa errors memakai pesan server atau teks bawaan', () {
      expect(ApiException.fromResponse(422, {'message': 'Bermasalah.'}).message, 'Bermasalah.');
      expect(ApiException.fromResponse(422, null).message, 'Data yang dikirim belum benar.');
    });

    test('429 membaca Retry-After', () {
      final e = ApiException.fromResponse(429, {'message': 'Too Many Attempts.'}, retryAfter: '30');

      expect(e.type, ApiErrorType.rateLimited);
      expect(e.retryAfterSeconds, 30);
      expect(e.message, contains('30 detik'));
    });

    test('429 tanpa Retry-After tetap berpesan sopan', () {
      final e = ApiException.fromResponse(429, null);

      expect(e.retryAfterSeconds, isNull);
      expect(e.message, 'Terlalu banyak percobaan. Coba lagi sebentar lagi.');
    });

    test('5xx menyembunyikan detail server', () {
      final e = ApiException.fromResponse(500, {'message': 'SQLSTATE[42P01]: Undefined table'});

      expect(e.type, ApiErrorType.server);
      expect(e.message, 'Server sedang bermasalah. Coba lagi nanti.');
    });

    test('kode lain dan body bukan objek', () {
      final e = ApiException.fromResponse(418, '<html>teapot</html>');
      expect(e.type, ApiErrorType.unknown);
      expect(e.message, 'Terjadi kesalahan (kode 418).');

      expect(ApiException.fromResponse(null, null).message, 'Terjadi kesalahan (kode ?).');
    });

    test('errors yang berupa teks tunggal tetap terbaca', () {
      final e = ApiException.fromResponse(422, {
        'errors': {'code': 'Kode tidak valid.'},
      });

      expect(e.errorFor('code'), 'Kode tidak valid.');
    });
  });

  group('konstruktor bernama', () {
    test('network dan timeout', () {
      expect(const ApiException.network().type, ApiErrorType.network);
      expect(const ApiException.timeout().type, ApiErrorType.timeout);
      expect(const ApiException.unexpected().type, ApiErrorType.unknown);
    });
  });
}
