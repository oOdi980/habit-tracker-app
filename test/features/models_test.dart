import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/today/today_models.dart';
import '../support/fixtures.dart';

void main() {
  group('Circle', () {
    test('membaca bentuk CircleResource', () {
      final c = Circle.fromJson(circleJson());

      expect(c.id, 1);
      expect(c.name, 'Odi & Anjal');
      expect(c.timezone, 'Asia/Jakarta');
      expect(c.members.map((m) => m.name), ['Odi', 'Anjal']);
      expect(c.isFull, isTrue);
    });

    test('partnerOf mengembalikan anggota lain, atau null bila sendirian', () {
      expect(circle().partnerOf(1)!.name, 'Anjal');
      expect(circle().partnerOf(2)!.name, 'Odi');
      expect(circle(full: false).partnerOf(1), isNull);
    });

    test('tanpa members di JSON: kosong dan tidak penuh', () {
      final json = circleJson()..remove('members')..remove('is_full');

      final c = Circle.fromJson(json);

      expect(c.members, isEmpty);
      expect(c.isFull, isFalse);
    });

    test('withMembers menghitung ulang status penuh', () {
      final solo = circle(full: false);
      expect(solo.isFull, isFalse);

      final both = solo.withMembers(const [
        CircleMember(id: 1, name: 'Odi'),
        CircleMember(id: 2, name: 'Anjal'),
      ]);

      expect(both.isFull, isTrue);
    });

    test('JSON rusak ditolak dengan FormatException berpesan jelas', () {
      expect(() => Circle.fromJson({'id': 'satu', 'name': 'x', 'timezone': 'y'}), throwsFormatException);
    });
  });

  group('CircleInvite', () {
    test('kode diformat ABCD-EFGH dan waktu kedaluwarsa dibaca dari ISO-8601', () {
      final invite = CircleInvite.fromJson({
        'circle_id': 1,
        'code': 'ABCDEFGH',
        'expires_at': '2026-11-10T07:00:00+00:00',
      });

      expect(invite.displayCode, 'ABCD-EFGH');
      expect(invite.expiresAt.toUtc(), DateTime.utc(2026, 11, 10, 7));
    });
  });

  group('Habit', () {
    Map<String, dynamic> habitJson({String status = 'upcoming', Object? next}) => {
          'id': 5,
          'circle_id': 1,
          'title': 'Baca buku',
          'scope': 'shared',
          'completion_rule': 'together',
          'owner_id': null,
          'created_by': 2,
          'status': status,
          'target_per_week': 4,
          'next_target': next,
          'starts_on': null,
          'ends_on': null,
          'accepted': false,
          'needs_my_approval': true,
        };

    test('membaca bentuk HabitResource (habit bersama menunggu persetujuan)', () {
      final h = Habit.fromJson(habitJson(status: 'pending_approval'));

      expect(h.scope, HabitScope.shared);
      expect(h.ownerId, isNull);
      expect(h.status, HabitStatus.pendingApproval);
      expect(h.needsMyApproval, isTrue);
      expect(h.startsOn, isNull);
      expect(h.nextTarget, isNull);
    });

    test('next_target dibaca bila ada', () {
      final h = Habit.fromJson(habitJson(next: {'target': 6, 'from': '2026-11-16'}));

      expect(h.nextTarget!.target, 6);
      expect(h.nextTarget!.from, '2026-11-16');
    });

    test('status yang belum dikenal tidak membuat crash', () {
      expect(Habit.fromJson(habitJson(status: 'status_baru')).status, HabitStatus.unknown);
    });

    test('scope tidak dikenal ditolak', () {
      final json = habitJson()..['scope'] = 'rahasia';

      expect(() => Habit.fromJson(json), throwsFormatException);
    });

    test('canBeRemovedBy: bersama oleh siapa saja, personal hanya pemilik', () {
      final shared = Habit.fromJson(habitJson());
      expect(shared.canBeRemovedBy(1), isTrue);
      expect(shared.canBeRemovedBy(2), isTrue);

      final personal = Habit.fromJson(habitJson()
        ..['scope'] = 'personal'
        ..['owner_id'] = 1);
      expect(personal.canBeRemovedBy(1), isTrue);
      expect(personal.canBeRemovedBy(2), isFalse);
    });

    test('HabitList membaca tanggal dan daftar', () {
      final list = HabitList.fromJson({
        'date': '2026-11-08',
        'habits': [habitJson(), habitJson()..['id'] = 6],
      });

      expect(list.date, '2026-11-08');
      expect(list.habits.map((h) => h.id), [5, 6]);
    });
  });

  group('TodayBoard', () {
    test('membaca bentuk TodayService', () {
      final b = TodayBoard.fromJson(todayJson(
        pendingApprovals: 2,
        habits: [
          todayHabitJson(id: 10, doneToday: [1], done: 5, target: 5),
          todayHabitJson(id: 11, scope: 'shared', ownerId: null, leave: 'pending'),
        ],
      ));

      expect(b.date, '2026-11-08');
      expect(b.weekStart, '2026-11-02');
      expect(b.weekEnd, '2026-11-08');
      expect(b.timezone, 'Asia/Jakarta');
      expect(b.members, hasLength(2));
      expect(b.pendingHabitApprovals, 2);
      expect(b.habits.first.weekAchieved, isTrue);
      expect(b.habits.first.isDoneTodayBy(1), isTrue);
      expect(b.habits.first.isDoneTodayBy(2), isFalse);
      expect(b.habits.last.scope, HabitScope.shared);
      expect(b.habits.last.ownerId, isNull);
      expect(b.habits.last.leaveStatus, 'pending');
    });

    test('empat lencana lain dijumlahkan', () {
      final json = todayJson()
        ..['pending_leave_approvals_count'] = 1
        ..['pending_consequence_approvals_count'] = 2
        ..['punishments_to_confirm_count'] = 3
        ..['my_open_punishments_count'] = 4;

      expect(TodayBoard.fromJson(json).otherPendingItems, 10);
    });

    test('field wajib hilang -> FormatException, bukan null diam-diam', () {
      final json = todayJson()..remove('week_start');

      expect(() => TodayBoard.fromJson(json), throwsFormatException);
    });

    test('withCheckIn hanya mengubah habit yang dituju', () {
      final b = board(habits: [
        todayHabitJson(id: 10, done: 2),
        todayHabitJson(id: 11, done: 1),
      ]);

      final updated = b.withCheckIn(
        habitId: 10,
        userId: 1,
        checkedIn: true,
        progress: const CheckInProgress(weekStart: '2026-11-02', done: 3, target: 5, achieved: false),
      );

      expect(updated.habits[0].weekDone, 3);
      expect(updated.habits[0].doneTodayBy, [1]);
      expect(updated.habits[1].weekDone, 1);
      expect(updated.habits[1].doneTodayBy, isEmpty);
      // Papan asli tidak berubah (immutable).
      expect(b.habits[0].weekDone, 2);
    });

    test('check-in yang membuat target tercapai menyalakan weekAchieved', () {
      final b = board(habits: [todayHabitJson(done: 4, target: 5)]);

      final updated = b.withCheckIn(
        habitId: 10,
        userId: 1,
        checkedIn: true,
        progress: const CheckInProgress(weekStart: '2026-11-02', done: 5, target: 5, achieved: true),
      );

      expect(updated.habits.single.weekAchieved, isTrue);
    });
  });

  group('CheckInResult', () {
    test('membaca bentuk respons check-in', () {
      final r = CheckInResult.fromJson(checkInJson(done: 5, target: 5));

      expect(r.habitId, 10);
      expect(r.logDate, '2026-11-08');
      expect(r.progress.weekStart, '2026-11-02');
      expect(r.progress.done, 5);
      expect(r.progress.achieved, isTrue);
    });
  });

  test('AppUser membaca id, nama, email', () {
    final u = AppUser.fromJson({'id': 3, 'name': 'Anjal', 'email': 'anjal@example.com'});

    expect(u.id, 3);
    expect(u.email, 'anjal@example.com');
  });
}
