import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/auth/auth_repository.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/circles/circle_repository.dart';

enum SessionStatus {
  /// Membaca token tersimpan dan memeriksanya ke server.
  booting,

  /// Belum login (atau sesi dicabut server).
  unauthenticated,

  /// Login; [SessionState.circles] sudah dimuat.
  authenticated,

  /// Punya token tetapi server tidak terjangkau. Token TIDAK dibuang: gagal jaringan bukan alasan logout.
  bootFailed,
}

@immutable
class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.circles = const <Circle>[],
    this.selectedCircleId,
    this.message,
  });

  final SessionStatus status;
  final AppUser? user;
  final List<Circle> circles;
  final int? selectedCircleId;

  /// Pesan untuk layar login/ulangi (mis. "Sesi kamu berakhir").
  final String? message;

  Circle? get selectedCircle {
    for (final circle in circles) {
      if (circle.id == selectedCircleId) return circle;
    }
    return null;
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Pemegang status login + daftar sesi. Satu-satunya tempat yang mengubah token.
class SessionController extends Notifier<SessionState> {
  Future<void>? _boot;

  @override
  SessionState build() {
    // Server menolak token (dicabut / ganti password di perangkat lain) -> kembali ke login.
    ref.read(apiClientProvider).onUnauthorized = _handleUnauthorized;

    // Mulai setelah build() selesai: state tidak boleh diubah di dalam build().
    Future<void>.microtask(bootstrap);
    return const SessionState(status: SessionStatus.booting);
  }

  /// Idempoten: pemanggilan berulang memakai proses yang sama.
  Future<void> bootstrap() => _boot ??= _runBootstrap();

  /// Dari layar "tidak bisa terhubung": coba lagi tanpa membuang token.
  Future<void> retryBoot() {
    _boot = null;
    state = const SessionState(status: SessionStatus.booting);
    return bootstrap();
  }

  Future<void> _runBootstrap() async {
    final store = ref.read(sessionStoreProvider);
    await store.load();

    if (store.token == null) {
      state = const SessionState(status: SessionStatus.unauthenticated);
      return;
    }

    await _loadMeOrFail(preferredCircleId: store.selectedCircleId);
  }

  /// Memuat akun + sesi. Gagal jaringan -> bootFailed (token tetap); token ditolak -> login.
  Future<void> _loadMeOrFail({int? preferredCircleId}) async {
    try {
      final me = await ref.read(authRepositoryProvider).me();
      state = _authenticated(me.user, me.circles, preferredCircleId);
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.unauthorized) {
        _handleUnauthorized();
      } else {
        state = SessionState(status: SessionStatus.bootFailed, message: e.message);
      }
    } catch (e) {
      // Bentuk respons tak terduga (bug/versi server tak cocok), bukan masalah jaringan.
      if (kDebugMode) debugPrint('bootstrap gagal: $e');
      state = const SessionState(
        status: SessionStatus.bootFailed,
        message: 'Respons server tidak sesuai. Pastikan aplikasi dan server versi yang cocok.',
      );
    }
  }

  /// Melempar [ApiException] ke pemanggil (layar login menampilkannya di bawah field/banner).
  Future<void> login({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).login(email: email, password: password);
    await _finishAuth(result);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) async {
    final result = await ref.read(authRepositoryProvider).register(
          name: name,
          email: email,
          password: password,
          inviteCode: inviteCode,
        );
    await _finishAuth(result);
  }

  Future<void> _finishAuth(AuthResult result) async {
    await ref.read(sessionStoreProvider).saveToken(result.token);
    // Daftar sesi diambil lewat /me supaya satu jalur untuk semua (login, daftar, daftar+undangan).
    await _loadMeOrFail();
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {
      // Tanpa jaringan pun pengguna harus bisa keluar dari perangkat ini. Token di server yang
      // gagal dicabut hanya jadi tanggungan token per-user yang dibatasi jumlahnya.
    }
    await ref.read(sessionStoreProvider).clear();
    state = const SessionState(status: SessionStatus.unauthenticated);
  }

  /// Membuat sesi baru lalu langsung memilihnya.
  Future<void> createCircle({required String name, required String timezone}) async {
    final circle = await ref.read(circleRepositoryProvider).create(name: name, timezone: timezone);
    await _addCircleAndSelect(circle);
  }

  /// Bergabung ke sesi lewat kode undangan lalu langsung memilihnya.
  Future<void> joinCircle(String code) async {
    final circle = await ref.read(circleRepositoryProvider).join(code);
    await _addCircleAndSelect(circle);
  }

  Future<void> _addCircleAndSelect(Circle circle) async {
    final current = state;
    final user = current.user;
    if (user == null) return;

    final others = current.circles.where((c) => c.id != circle.id);
    state = _authenticated(user, [...others, circle], circle.id);
    await ref.read(sessionStoreProvider).setSelectedCircle(circle.id);
  }

  Future<void> selectCircle(int circleId) async {
    final current = state;
    if (current.selectedCircleId == circleId) return;
    if (!current.circles.any((c) => c.id == circleId)) return;

    state = SessionState(
      status: current.status,
      user: current.user,
      circles: current.circles,
      selectedCircleId: circleId,
    );
    await ref.read(sessionStoreProvider).setSelectedCircle(circleId);
  }

  /// Anggota sesi bisa berubah tanpa aplikasi bertanya (partner baru bergabung). Papan hari ini
  /// sudah membawa daftar anggota terbaru, jadi sesi disegarkan dari situ: nol request tambahan.
  void syncMembers(int circleId, List<CircleMember> members) {
    final current = state;
    if (current.status != SessionStatus.authenticated) return;

    var changed = false;
    final updated = <Circle>[];

    for (final circle in current.circles) {
      if (circle.id == circleId && !_sameMembers(circle.members, members)) {
        updated.add(circle.withMembers(members));
        changed = true;
      } else {
        updated.add(circle);
      }
    }

    if (!changed) return;
    state = SessionState(
      status: current.status,
      user: current.user,
      circles: updated,
      selectedCircleId: current.selectedCircleId,
    );
  }

  bool _sameMembers(List<CircleMember> a, List<CircleMember> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) return false;
    }
    return true;
  }

  void _handleUnauthorized() {
    // Beberapa request bersamaan bisa sama-sama menerima 401; cukup tangani sekali.
    if (state.status == SessionStatus.unauthenticated) return;

    unawaited(ref.read(sessionStoreProvider).clear());
    state = const SessionState(
      status: SessionStatus.unauthenticated,
      message: 'Sesi kamu berakhir. Silakan masuk lagi.',
    );
  }

  /// Sesi yang dipilih: yang terakhir dipakai bila masih ada, kalau tidak yang pertama.
  SessionState _authenticated(AppUser user, List<Circle> circles, int? preferredId) {
    int? selected;
    for (final circle in circles) {
      if (circle.id == preferredId) selected = circle.id;
    }
    selected ??= circles.isEmpty ? null : circles.first.id;

    return SessionState(
      status: SessionStatus.authenticated,
      user: user,
      circles: circles,
      selectedCircleId: selected,
    );
  }
}
