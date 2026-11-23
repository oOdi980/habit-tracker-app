import 'package:habit_tracker/core/util/json.dart';

enum HabitScope {
  personal,
  shared;

  static HabitScope parse(Object? value, String field) {
    if (value == 'personal') return HabitScope.personal;
    if (value == 'shared') return HabitScope.shared;
    throw FormatException('$field bukan scope yang dikenal: $value');
  }

  /// Nilai yang dikirim/diterima server ("personal" / "shared").
  String get apiValue => name;
}

/// Tahap hidup habit (dihitung server dari tanggal lokal sesi).
enum HabitStatus {
  pendingApproval('pending_approval'),
  upcoming('upcoming'),
  active('active'),
  ending('ending'),
  ended('ended'),
  unknown('');

  const HabitStatus(this.apiValue);

  final String apiValue;

  static HabitStatus parse(String value) {
    for (final status in HabitStatus.values) {
      if (status != HabitStatus.unknown && status.apiValue == value) return status;
    }
    return HabitStatus.unknown;
  }
}

/// Perubahan target yang tertahan dan baru berlaku pada [from] (Senin).
class NextTarget {
  const NextTarget({required this.target, required this.from});

  factory NextTarget.fromJson(Json json) => NextTarget(
        target: asInt(json['target'], 'next_target.target'),
        from: asString(json['from'], 'next_target.from'),
      );

  final int target;
  final String from;
}

/// Habit di daftar habit (GET /api/circles/{id}/habits dan respons buat/terima habit).
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.scope,
    required this.ownerId,
    required this.createdBy,
    required this.status,
    required this.targetPerWeek,
    required this.nextTarget,
    required this.startsOn,
    required this.endsOn,
    required this.needsMyApproval,
  });

  factory Habit.fromJson(Json json) {
    final next = json['next_target'];

    return Habit(
      id: asInt(json['id'], 'habit.id'),
      title: asString(json['title'], 'habit.title'),
      scope: HabitScope.parse(json['scope'], 'habit.scope'),
      ownerId: asIntOrNull(json['owner_id'], 'habit.owner_id'),
      createdBy: asInt(json['created_by'], 'habit.created_by'),
      status: HabitStatus.parse(asString(json['status'], 'habit.status')),
      targetPerWeek: asInt(json['target_per_week'], 'habit.target_per_week'),
      nextTarget: next == null ? null : NextTarget.fromJson(asJson(next, 'habit.next_target')),
      startsOn: asStringOrNull(json['starts_on'], 'habit.starts_on'),
      endsOn: asStringOrNull(json['ends_on'], 'habit.ends_on'),
      needsMyApproval: asBool(json['needs_my_approval'], 'habit.needs_my_approval'),
    );
  }

  final int id;
  final String title;
  final HabitScope scope;

  /// Pemilik habit personal; null untuk habit bersama.
  final int? ownerId;
  final int createdBy;
  final HabitStatus status;
  final int targetPerWeek;
  final NextTarget? nextTarget;
  final String? startsOn;
  final String? endsOn;

  /// Habit bersama yang menunggu persetujuan USER YANG MELIHAT (bukan pembuatnya).
  final bool needsMyApproval;

  /// Boleh dihapus/diarsipkan oleh [userId]: habit bersama oleh keduanya, personal oleh pemiliknya.
  /// (Server tetap menjadi penentu akhir; ini hanya untuk menyembunyikan tombol yang pasti ditolak.)
  bool canBeRemovedBy(int userId) => scope == HabitScope.shared || ownerId == userId;
}

/// Isi GET /api/circles/{id}/habits.
class HabitList {
  const HabitList({required this.date, required this.habits});

  factory HabitList.fromJson(Json json) => HabitList(
        date: asString(json['date'], 'date'),
        habits: asJsonList(json['habits'], 'habits').map(Habit.fromJson).toList(),
      );

  /// Tanggal hari ini menurut zona sesi.
  final String date;
  final List<Habit> habits;
}
