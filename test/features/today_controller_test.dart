import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/today/today_controller.dart';
import 'package:habit_tracker/features/today/today_repository.dart';
import '../support/fakes.dart';
import '../support/fixtures.dart';

/// Sesi palsu yang sudah login sebagai Odi (id 1), tanpa menyentuh jaringan/penyimpanan.
class _LoggedInSession extends SessionController {
  @override
  SessionState build() => SessionState(
        status: SessionStatus.authenticated,
        user: odi,
        circles: [circle()],
        selectedCircleId: 1,
      );
}

class _Setup {
  _Setup() {
    container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_LoggedInSession.new),
        todayRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    repo.onBoard = (call) async => board();
  }

  final FakeTodayRepository repo = FakeTodayRepository();
  late final ProviderContainer container;

  TodayController get controller => container.read(todayProvider(1).notifier);
  Future<TodayState> load() => container.read(todayProvider(1).future);
  TodayState get current => container.read(todayProvider(1)).requireValue;
}

void main() {
  test('memuat papan hari ini', () async {
    final s = _Setup();

    final state = await s.load();

    expect(state.board.date, '2026-11-08');
    expect(state.board.habits, hasLength(1));
    expect(s.repo.boardCalls, 1);
  });

  test('check-in menempel hasil server ke papan tanpa memuat ulang', () async {
    final s = _Setup();
    await s.load();
    s.repo.onCheckIn = () async => checkInResult(done: 3);

    final error = await s.controller.setCheckedIn(10, undo: false);

    expect(error, isNull);
    final habit = s.current.board.habits.single;
    expect(habit.doneTodayBy, [1]);
    expect(habit.weekDone, 3);
    expect(s.repo.checkInCalls, 1);
    expect(s.repo.boardCalls, 1); // tidak ada request papan tambahan
  });

  test('undo menghapus penanda hari ini dan memakai progres dari server', () async {
    final s = _Setup();
    s.repo.onBoard = (call) async => board(habits: [
          todayHabitJson(doneToday: [1, 2], done: 3),
        ]);
    await s.load();
    s.repo.onUndo = () async => checkInResult(done: 2);

    final error = await s.controller.setCheckedIn(10, undo: true);

    expect(error, isNull);
    final habit = s.current.board.habits.single;
    expect(habit.doneTodayBy, [2]); // check-in partner tidak tersentuh
    expect(habit.weekDone, 2);
    expect(s.repo.undoCalls, 1);
  });

  test('check-in menjaga urutan id pada doneTodayBy', () async {
    final s = _Setup();
    s.repo.onBoard = (call) async => board(habits: [
          todayHabitJson(scope: 'shared', ownerId: null, doneToday: [2], done: 0),
        ]);
    await s.load();
    s.repo.onCheckIn = () async => checkInResult(done: 1);

    await s.controller.setCheckedIn(10, undo: false);

    expect(s.current.board.habits.single.doneTodayBy, [1, 2]);
  });

  test('hari sudah berganti di server: papan dimuat ulang, hasil lama tidak ditempel', () async {
    final s = _Setup();
    s.repo.onBoard = (call) async => call == 1 ? board(date: '2026-11-08') : board(date: '2026-11-09');
    await s.load();
    // Server mencatat check-in ke tanggal baru (lewat tengah malam zona sesi).
    s.repo.onCheckIn = () async => checkInResult(logDate: '2026-11-09', weekStart: '2026-11-09', done: 1);

    final error = await s.controller.setCheckedIn(10, undo: false);

    expect(error, isNull);
    expect(s.repo.boardCalls, 2);
    expect(s.current.board.date, '2026-11-09');
  });

  test('error validasi (habit berakhir/minggu terkunci) mengembalikan pesan dan menyegarkan papan', () async {
    final s = _Setup();
    await s.load();
    s.repo.onCheckIn = () async => throw const ApiException(
          type: ApiErrorType.validation,
          message: 'Habit ini sudah berakhir.',
          statusCode: 422,
        );

    final error = await s.controller.setCheckedIn(10, undo: false);

    expect(error, 'Habit ini sudah berakhir.');
    expect(s.repo.boardCalls, 2);
  });

  test('gagal jaringan mengembalikan pesan tanpa memuat ulang dan tanpa mengubah papan', () async {
    final s = _Setup();
    await s.load();
    s.repo.onCheckIn = () async => throw const ApiException.network();

    final error = await s.controller.setCheckedIn(10, undo: false);

    expect(error, contains('terhubung'));
    expect(s.repo.boardCalls, 1);
    expect(s.current.board.habits.single.doneTodayBy, isEmpty);
  });

  test('refresh yang gagal tidak membuang papan yang sudah tampil', () async {
    final s = _Setup();
    await s.load();
    s.repo.onBoard = (call) async => throw const ApiException.timeout();

    final error = await s.controller.refresh();

    expect(error, isNotNull);
    expect(s.current.board.habits, hasLength(1)); // data lama tetap
  });

  test('refresh sukses mengganti papan', () async {
    final s = _Setup();
    await s.load();
    s.repo.onBoard = (call) async => board(habits: [
          todayHabitJson(id: 11),
          todayHabitJson(id: 12),
        ]);

    final error = await s.controller.refresh();

    expect(error, isNull);
    expect(s.current.board.habits.map((h) => h.id), [11, 12]);
  });

  test('refreshIfStale tidak memanggil server bila data masih segar', () async {
    final s = _Setup();
    await s.load();

    await s.controller.refreshIfStale();

    expect(s.repo.boardCalls, 1);
  });

  test('refreshIfStale memuat ulang bila data sudah lewat batas umur', () async {
    final s = _Setup();
    await s.load();

    await s.controller.refreshIfStale(maxAge: Duration.zero);

    expect(s.repo.boardCalls, 2);
  });
}
