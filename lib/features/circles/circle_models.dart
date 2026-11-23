import 'package:habit_tracker/core/util/json.dart';

/// Satu sesi berisi tepat 2 orang (aturan server: config habit.max_circle_members).
const int kCircleCapacity = 2;

class CircleMember {
  const CircleMember({required this.id, required this.name});

  factory CircleMember.fromJson(Json json) => CircleMember(
        id: asInt(json['id'], 'member.id'),
        name: asString(json['name'], 'member.name'),
      );

  final int id;
  final String name;
}

class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.timezone,
    required this.members,
    required this.isFull,
  });

  factory Circle.fromJson(Json json) {
    final rawMembers = json['members'];
    final members = rawMembers == null
        ? const <CircleMember>[]
        : asJsonList(rawMembers, 'circle.members').map(CircleMember.fromJson).toList();

    return Circle(
      id: asInt(json['id'], 'circle.id'),
      name: asString(json['name'], 'circle.name'),
      timezone: asString(json['timezone'], 'circle.timezone'),
      members: members,
      isFull: json['is_full'] is bool ? json['is_full'] as bool : members.length >= kCircleCapacity,
    );
  }

  final int id;
  final String name;
  final String timezone;
  final List<CircleMember> members;
  final bool isFull;

  /// Anggota selain [myId]; null bila belum ada partner.
  CircleMember? partnerOf(int myId) {
    for (final member in members) {
      if (member.id != myId) return member;
    }
    return null;
  }

  Circle withMembers(List<CircleMember> newMembers) => Circle(
        id: id,
        name: name,
        timezone: timezone,
        members: newMembers,
        isFull: newMembers.length >= kCircleCapacity,
      );
}

/// Kode undangan yang baru dibuat. Kode lama otomatis hangus di server.
class CircleInvite {
  const CircleInvite({required this.code, required this.expiresAt});

  factory CircleInvite.fromJson(Json json) => CircleInvite(
        code: asString(json['code'], 'invite.code'),
        expiresAt: DateTime.parse(asString(json['expires_at'], 'invite.expires_at')),
      );

  final String code;
  final DateTime expiresAt;

  /// "ABCD-EFGH": mudah dibaca dan diketik. Server menerima kode dengan atau tanpa tanda hubung.
  String get displayCode {
    if (code.length <= 4) return code;
    return '${code.substring(0, 4)}-${code.substring(4)}';
  }
}
