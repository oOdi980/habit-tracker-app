import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/core/storage/session_store.dart';
import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/auth/auth_repository.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/circles/circle_repository.dart';
import '../support/fakes.dart';
import '../support/fixtures.dart';

class _Setup {
  _Setup() {
    store = SessionStore(kv);
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(auth),
        circleRepositoryProvider.overrideWithValue(circles),
      ],
    );
    addTearDown(container.dispose);
  }

  final MemoryKeyValueStore kv = MemoryKeyValueStore();
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeCircleRepository circles = FakeCircleRepository();
  late final SessionStore store;
  late final ProviderContainer container;

  SessionController get controller => container.read(sessionProvider.notifier);
  SessionState get state => container.read(sessionProvider);
}

MeResult _me({List<Circle>? circles}) => MeResult(user: odi, circles: circles ?? [circle()]);

void main() {
  group('bootstrap', () {
    test('tanpa token langsung ke layar login', () async {
      final s = _Setup();

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.auth.meCalls, 0); // tanpa token, tidak ada gunanya bertanya ke server
    });

    test('token valid memuat akun dan sesi, memakai sesi terakhir yang dipilih', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.kv.data['selected_circle_id'] = '2';
      s.auth.onMe = () async => _me(circles: [circle(id: 1), circle(id: 2)]);

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.authenticated);
      expect(s.state.user!.name, 'Odi');
      expect(s.state.selectedCircleId, 2);
    });

    test('sesi terakhir yang sudah tidak ada diganti sesi pertama', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.kv.data['selected_circle_id'] = '99';
      s.auth.onMe = () async => _me(circles: [circle(id: 5)]);

      await s.controller.bootstrap();

      expect(s.state.selectedCircleId, 5);
    });

    test('bootstrap dipanggil berulang hanya bertanya ke server sekali', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me();

      await Future.wait([s.controller.bootstrap(), s.controller.bootstrap()]);

      expect(s.auth.meCalls, 1);
    });

    test('server tidak terjangkau: bootFailed dan token TIDAK dibuang, lalu bisa dicoba lagi', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => throw const ApiException.network();

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.bootFailed);
      expect(s.state.message, contains('terhubung'));
      expect(s.store.token, 'tok');

      s.auth.onMe = () async => _me();
      await s.controller.retryBoot();

      expect(s.state.status, SessionStatus.authenticated);
    });

    test('token ditolak server: kembali ke login dan token dibuang', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => throw const ApiException(
            type: ApiErrorType.unauthorized,
            message: 'Sesi kamu berakhir. Silakan masuk lagi.',
            statusCode: 401,
          );

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.state.message, contains('berakhir'));
      expect(s.store.token, isNull);
    });

    test('respons aneh dari server menjadi bootFailed, bukan crash', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => throw const FormatException('bentuk salah');

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.bootFailed);
    });

    test('storage rusak dianggap belum login dan dibersihkan', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.kv.failReads = true;

      await s.controller.bootstrap();

      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.kv.data, isEmpty);
    });
  });

  group('login dan logout', () {
    test('login berhasil menyimpan token lalu memuat sesi', () async {
      final s = _Setup();
      s.auth.onLogin = () async => const AuthResult(token: 'baru', user: odi);
      s.auth.onMe = () async => _me();
      await s.controller.bootstrap();

      await s.controller.login(email: 'odi@example.com', password: 'rahasia123');

      expect(s.state.status, SessionStatus.authenticated);
      expect(s.kv.data['auth_token'], 'baru');
      expect(s.store.token, 'baru');
    });

    test('login gagal melempar ApiException dan tetap di layar login', () async {
      final s = _Setup();
      s.auth.onLogin = () async => throw const ApiException(
            type: ApiErrorType.unauthorized,
            message: 'Email atau password salah.',
            statusCode: 401,
          );
      await s.controller.bootstrap();

      await expectLater(
        s.controller.login(email: 'x', password: 'y'),
        throwsA(isA<ApiException>()),
      );

      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.store.token, isNull);
    });

    test('login berhasil tapi server mati saat memuat sesi: bootFailed dengan token tersimpan', () async {
      final s = _Setup();
      s.auth.onLogin = () async => const AuthResult(token: 'baru', user: odi);
      s.auth.onMe = () async => throw const ApiException.timeout();
      await s.controller.bootstrap();

      await s.controller.login(email: 'a', password: 'b');

      // Penting: BUKAN authenticated dengan daftar sesi kosong (itu akan memaksa pengguna membuat sesi baru).
      expect(s.state.status, SessionStatus.bootFailed);
      expect(s.store.token, 'baru');
    });

    test('logout tetap membersihkan perangkat walau server tidak terjangkau', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me();
      s.auth.onLogout = () async => throw const ApiException.network();
      await s.controller.bootstrap();

      await s.controller.logout();

      expect(s.auth.logoutCalls, 1);
      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.store.token, isNull);
      expect(s.kv.data, isEmpty);
    });
  });

  group('sesi', () {
    test('membuat sesi langsung memilihnya', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me(circles: [circle(id: 1)]);
      await s.controller.bootstrap();

      s.circles.next = circle(id: 7, full: false);
      await s.controller.createCircle(name: 'Baru', timezone: 'Asia/Jakarta');

      expect(s.state.circles.map((c) => c.id), [1, 7]);
      expect(s.state.selectedCircleId, 7);
      expect(s.kv.data['selected_circle_id'], '7');
    });

    test('bergabung ke sesi yang sudah ada tidak menggandakan', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me(circles: [circle(id: 1, full: false)]);
      await s.controller.bootstrap();

      s.circles.next = circle(id: 1, full: true);
      await s.controller.joinCircle('ABCD-EFGH');

      expect(s.state.circles, hasLength(1));
      expect(s.state.selectedCircle!.isFull, isTrue);
    });

    test('selectCircle menolak id yang bukan milik pengguna', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me(circles: [circle(id: 1), circle(id: 2)]);
      await s.controller.bootstrap();

      await s.controller.selectCircle(2);
      expect(s.state.selectedCircleId, 2);

      await s.controller.selectCircle(404);
      expect(s.state.selectedCircleId, 2);
    });

    test('syncMembers memperbarui sesi dari papan, dan tidak mengubah state bila sama', () async {
      final s = _Setup();
      s.kv.data['auth_token'] = 'tok';
      s.auth.onMe = () async => _me(circles: [circle(id: 1, full: false)]);
      await s.controller.bootstrap();
      expect(s.state.selectedCircle!.isFull, isFalse);

      const members = [CircleMember(id: 1, name: 'Odi'), CircleMember(id: 2, name: 'Anjal')];
      s.controller.syncMembers(1, members);

      expect(s.state.selectedCircle!.members, hasLength(2));
      expect(s.state.selectedCircle!.isFull, isTrue);

      final before = s.state;
      s.controller.syncMembers(1, members);
      expect(identical(s.state, before), isTrue);
    });
  });
}
