import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';

/// Satu habit di papan hari ini (hanya habit yang SEDANG dihitung).
class TodayHabit {
  const TodayHabit({
    required this.id,
    required this.title,
    required this.scope,
    required this.ownerId,
    required this.status,
    required this.endsOn,
    required this.targetPerWeek,
    required this.weekDone,
    required this.weekAchieved,
    required this.doneTodayBy,
    required this.leaveStatus,
    required this.canCheckIn,
  });

  factory TodayHabit.fromJson(Json json) {
    final done = json['done_today_by'];

    return TodayHabit(
      id: asInt(json['id'], 'habit.id'),
      title: asString(json['title'], 'habit.title'),
      scope: HabitScope.parse(json['scope'], 'habit.scope'),
      ownerId: asIntOrNull(json['owner_id'], 'habit.owner_id'),
      status: HabitStatus.parse(asString(json['status'], 'habit.status')),
      endsOn: asStringOrNull(json['ends_on'], 'habit.ends_on'),
      targetPerWeek: asInt(json['target_per_week'], 'habit.target_per_week'),
      weekDone: asInt(json['week_done'], 'habit.week_done'),
      weekAchieved: asBool(json['week_achieved'], 'habit.week_achieved'),
      doneTodayBy: done is List ? done.map((e) => asInt(e, 'done_today_by')).toList() : const <int>[],
      leaveStatus: asStringOrNull(json['leave_status'], 'habit.leave_status'),
      canCheckIn: asBool(json['can_check_in'], 'habit.can_check_in'),
    );
  }

  final int id;
  final String title;
  final HabitScope scope;
  final int? ownerId;
  final HabitStatus status;
  final String? endsOn;
  final int targetPerWeek;

  /// Hari yang sudah dihitung minggu ini. Habit bersama: hanya hari yang KEDUA anggota check-in.
  final int weekDone;
  final bool weekAchieved;

  /// Id anggota yang sudah check-in hari ini.
  final List<int> doneTodayBy;

  /// null, 'pending' (menunggu partner), atau 'approved'.
  final String? leaveStatus;
  final bool canCheckIn;

  bool isDoneTodayBy(int userId) => doneTodayBy.contains(userId);

  TodayHabit withCheckIn({
    required int userId,
    required bool checkedIn,
    required CheckInProgress progress,
  }) {
    final updated = <int>{...doneTodayBy};
    if (checkedIn) {
      updated.add(userId);
    } else {
      updated.remove(userId);
    }

    return TodayHabit(
      id: id,
      title: title,
      scope: scope,
      ownerId: ownerId,
      status: status,
      endsOn: endsOn,
      targetPerWeek: progress.target,
      weekDone: progress.done,
      weekAchieved: progress.achieved,
      doneTodayBy: updated.toList()..sort(),
      leaveStatus: leaveStatus,
      canCheckIn: canCheckIn,
    );
  }
}

/// Isi GET /api/circles/{id}/today.
class TodayBoard {
  const TodayBoard({
    required this.date,
    required this.weekStart,
    required this.weekEnd,
    required this.timezone,
    required this.members,
    required this.pendingHabitApprovals,
    required this.otherPendingItems,
    required this.habits,
  });

  factory TodayBoard.fromJson(Json json) {
    // Empat lencana lain (izin, usulan reward/punishment, dua jenis konfirmasi punishment) belum
    // punya layar di fase ini; cukup dijumlahkan menjadi satu penanda.
    final other = asInt(json['pending_leave_approvals_count'], 'pending_leave_approvals_count') +
        asInt(json['pending_consequence_approvals_count'], 'pending_consequence_approvals_count') +
        asInt(json['punishments_to_confirm_count'], 'punishments_to_confirm_count') +
        asInt(json['my_open_punishments_count'], 'my_open_punishments_count');

    return TodayBoard(
      date: asString(json['date'], 'date'),
      weekStart: asString(json['week_start'], 'week_start'),
      weekEnd: asString(json['week_end'], 'week_end'),
      timezone: asString(json['timezone'], 'timezone'),
      members: asJsonList(json['members'], 'members').map(CircleMember.fromJson).toList(),
      pendingHabitApprovals: asInt(json['pending_approvals_count'], 'pending_approvals_count'),
      otherPendingItems: other,
      habits: asJsonList(json['habits'], 'habits').map(TodayHabit.fromJson).toList(),
    );
  }

  /// Tanggal hari ini menurut zona SESI (bukan zona HP).
  final String date;
  final String weekStart;
  final String weekEnd;
  final String timezone;
  final List<CircleMember> members;
  final int pendingHabitApprovals;
  final int otherPendingItems;
  final List<TodayHabit> habits;

  TodayBoard withHabits(List<TodayHabit> newHabits) => TodayBoard(
        date: date,
        weekStart: weekStart,
        weekEnd: weekEnd,
        timezone: timezone,
        members: members,
        pendingHabitApprovals: pendingHabitApprovals,
        otherPendingItems: otherPendingItems,
        habits: newHabits,
      );

  /// Terapkan hasil check-in/undo ke satu habit tanpa memuat ulang seluruh papan.
  TodayBoard withCheckIn({
    required int habitId,
    required int userId,
    required bool checkedIn,
    required CheckInProgress progress,
  }) {
    return withHabits([
      for (final habit in habits)
        if (habit.id == habitId)
          habit.withCheckIn(userId: userId, checkedIn: checkedIn, progress: progress)
        else
          habit,
    ]);
  }
}

/// Progres minggu dari respons check-in/undo.
class CheckInProgress {
  const CheckInProgress({
    required this.weekStart,
    required this.done,
    required this.target,
    required this.achieved,
  });

  factory CheckInProgress.fromJson(Json json) => CheckInProgress(
        weekStart: asString(json['week_start'], 'progress.week_start'),
        done: asInt(json['done'], 'progress.done'),
        target: asInt(json['target'], 'progress.target'),
        achieved: asBool(json['achieved'], 'progress.achieved'),
      );

  final String weekStart;
  final int done;
  final int target;
  final bool achieved;
}

/// Respons POST/DELETE /api/habits/{id}/check-in (bagian "check_in").
class CheckInResult {
  const CheckInResult({
    required this.habitId,
    required this.logDate,
    required this.progress,
  });

  factory CheckInResult.fromJson(Json json) => CheckInResult(
        habitId: asInt(json['habit_id'], 'check_in.habit_id'),
        logDate: asString(json['log_date'], 'check_in.log_date'),
        progress: CheckInProgress.fromJson(asJson(json['progress'], 'check_in.progress')),
      );

  final int habitId;

  /// Tanggal yang dipakai server (zona sesi). Bisa beda dari tanggal papan bila hari sudah berganti.
  final String logDate;
  final CheckInProgress progress;
}
