import 'package:habit_tracker/core/storage/session_store.dart';
import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/auth/auth_repository.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/circles/circle_repository.dart';
import 'package:habit_tracker/features/today/today_models.dart';
import 'package:habit_tracker/features/today/today_repository.dart';

/// Penyimpanan di memori (tanpa plugin).
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = <String, String>{};

  /// Meniru storage rusak (mis. hasil restore backup Android).
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('storage rusak');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('storage penuh');
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    data.clear();
  }
}

/// AuthRepository palsu: perilaku diatur lewat closure.
class FakeAuthRepository implements AuthRepository {
  Future<MeResult> Function() onMe = () async => throw StateError('onMe belum diatur');
  Future<AuthResult> Function() onLogin = () async => throw StateError('onLogin belum diatur');
  Future<void> Function() onLogout = () async {};

  int meCalls = 0;
  int logoutCalls = 0;

  @override
  Future<MeResult> me() {
    meCalls++;
    return onMe();
  }

  @override
  Future<AuthResult> login({required String email, required String password}) => onLogin();

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    String? inviteCode,
  }) =>
      onLogin();

  @override
  Future<void> logout() {
    logoutCalls++;
    return onLogout();
  }
}

class FakeCircleRepository implements CircleRepository {
  Circle? next;

  @override
  Future<Circle> create({required String name, required String timezone}) async => next!;

  @override
  Future<Circle> join(String code) async => next!;

  @override
  Future<CircleInvite> createInvite(int circleId) async => throw UnimplementedError();
}

class FakeTodayRepository implements TodayRepository {
  /// Dipanggil tiap board() dengan nomor panggilan (mulai 1); mengembalikan papan atau melempar.
  Future<TodayBoard> Function(int call) onBoard = (call) async => throw StateError('onBoard belum diatur');
  Future<CheckInResult> Function() onCheckIn = () async => throw StateError('onCheckIn belum diatur');
  Future<CheckInResult> Function() onUndo = () async => throw StateError('onUndo belum diatur');

  int boardCalls = 0;
  int checkInCalls = 0;
  int undoCalls = 0;

  @override
  Future<TodayBoard> board(int circleId) {
    boardCalls++;
    return onBoard(boardCalls);
  }

  @override
  Future<CheckInResult> checkIn(int habitId, {required DateTime tappedAt}) {
    checkInCalls++;
    return onCheckIn();
  }

  @override
  Future<CheckInResult> undoCheckIn(int habitId) {
    undoCalls++;
    return onUndo();
  }
}
