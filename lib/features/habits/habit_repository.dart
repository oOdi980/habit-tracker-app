import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_client.dart';
import 'package:habit_tracker/core/providers.dart';
import 'package:habit_tracker/core/util/json.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => HabitRepository(ref.watch(apiClientProvider)),
);

class HabitRepository {
  HabitRepository(this._api);

  final ApiClient _api;

  Future<HabitList> list(int circleId) async {
    final body = await _api.get('/api/circles/$circleId/habits');
    return HabitList.fromJson(body);
  }

  Future<Habit> create(
    int circleId, {
    required String title,
    required HabitScope scope,
    required int targetPerWeek,
  }) async {
    final body = await _api.post('/api/circles/$circleId/habits', body: {
      'title': title,
      'scope': scope.apiValue,
      'target_per_week': targetPerWeek,
    });
    return Habit.fromJson(asJson(body['habit'], 'habit'));
  }

  Future<Habit> accept(int habitId) async {
    final body = await _api.post('/api/habits/$habitId/accept');
    return Habit.fromJson(asJson(body['habit'], 'habit'));
  }

  /// Menolak/membatalkan/menghapus habit. Server membalas 204 bila habit dihapus permanen
  /// (null di sini), atau habit berstatus "ending" bila habit aktif diarsipkan.
  Future<Habit?> remove(int habitId) async {
    final body = await _api.delete('/api/habits/$habitId');
    final habit = body['habit'];
    return habit == null ? null : Habit.fromJson(asJson(habit, 'habit'));
  }
}
