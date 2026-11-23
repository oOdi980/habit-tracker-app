import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/auth/auth_models.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/today/today_models.dart';

// Contoh JSON ini disalin dari bentuk keluaran Laravel yang sebenarnya (CircleResource,
// HabitResource, TodayService, CheckInService). Kalau server berubah bentuk, tes di sini yang
// pertama gagal.

const AppUser odi = AppUser(id: 1, name: 'Odi', email: 'odi@example.com');

Json circleJson({int id = 1, bool full = true}) => {
      'id': id,
      'name': 'Odi & Anjal',
      'timezone': 'Asia/Jakarta',
      'reward_min_ratio': '0.80',
      'punishment_below_ratio': '0.50',
      'members': [
        {'id': 1, 'name': 'Odi'},
        if (full) {'id': 2, 'name': 'Anjal'},
      ],
      'is_full': full,
    };

Circle circle({int id = 1, bool full = true}) => Circle.fromJson(circleJson(id: id, full: full));

Json todayHabitJson({
  int id = 10,
  String scope = 'personal',
  int? ownerId = 1,
  int done = 2,
  int target = 5,
  List<int> doneToday = const <int>[],
  bool canCheckIn = true,
  String? leave,
}) =>
    {
      'id': id,
      'title': 'Lari pagi',
      'scope': scope,
      'completion_rule': scope == 'shared' ? 'together' : 'individual',
      'owner_id': ownerId,
      'status': 'active',
      'ends_on': null,
      'target_per_week': target,
      'week_done': done,
      'week_achieved': done >= target,
      'done_today_by': doneToday,
      'leave_status': leave,
      'can_check_in': canCheckIn,
    };

Json todayJson({
  String date = '2026-11-08',
  List<Json>? habits,
  int pendingApprovals = 0,
}) =>
    {
      'date': date,
      'week_start': '2026-11-02',
      'week_end': '2026-11-08',
      'timezone': 'Asia/Jakarta',
      'members': [
        {'id': 1, 'name': 'Odi'},
        {'id': 2, 'name': 'Anjal'},
      ],
      'pending_approvals_count': pendingApprovals,
      'pending_leave_approvals_count': 0,
      'pending_consequence_approvals_count': 0,
      'punishments_to_confirm_count': 0,
      'my_open_punishments_count': 0,
      'habits': habits ?? [todayHabitJson()],
    };

TodayBoard board({String date = '2026-11-08', List<Json>? habits}) =>
    TodayBoard.fromJson(todayJson(date: date, habits: habits));

Json checkInJson({
  int habitId = 10,
  String logDate = '2026-11-08',
  String weekStart = '2026-11-02',
  int done = 3,
  int target = 5,
}) =>
    {
      'habit_id': habitId,
      'log_date': logDate,
      'progress': {
        'week_start': weekStart,
        'done': done,
        'target': target,
        'achieved': done >= target,
      },
    };

CheckInResult checkInResult({
  int habitId = 10,
  String logDate = '2026-11-08',
  String weekStart = '2026-11-02',
  int done = 3,
  int target = 5,
}) =>
    CheckInResult.fromJson(
      checkInJson(habitId: habitId, logDate: logDate, weekStart: weekStart, done: done, target: target),
    );
