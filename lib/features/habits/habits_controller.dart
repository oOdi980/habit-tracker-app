import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/habits/habit_repository.dart';
import 'package:habit_tracker/features/today/today_controller.dart';

@immutable
class HabitsState {
  const HabitsState({required this.list, required this.loadedAt});

  final HabitList list;
  final DateTime loadedAt;

  HabitsState withHabits(List<Habit> habits) => HabitsState(
        list: HabitList(date: list.date, habits: habits),
        loadedAt: loadedAt,
      );
}

/// Daftar habit per sesi (termasuk yang menunggu persetujuan dan yang belum mulai).
final habitsProvider = AsyncNotifierProvider.family<HabitsController, HabitsState, int>(HabitsController.new);

class HabitsController extends FamilyAsyncNotifier<HabitsState, int> {
  @override
  Future<HabitsState> build(int arg) async {
    ref.watch(sessionProvider.select((s) => s.user?.id));

    final list = await ref.read(habitRepositoryProvider).list(arg);
    return HabitsState(list: list, loadedAt: DateTime.now());
  }

  Future<String?> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncLoading<HabitsState>();

    try {
      final list = await ref.read(habitRepositoryProvider).list(arg);
      state = AsyncData(HabitsState(list: list, loadedAt: DateTime.now()));
      return null;
    } catch (e, st) {
      if (previous == null) state = AsyncError<HabitsState>(e, st);
      return errorMessageOf(e);
    }
  }

  Future<void> refreshIfStale({Duration maxAge = const Duration(seconds: 30)}) async {
    final current = state.valueOrNull;
    if (current == null || state.isLoading) return;
    if (DateTime.now().difference(current.loadedAt) < maxAge) return;
    await refresh();
  }

  Future<String?> create({
    required String title,
    required HabitScope scope,
    required int targetPerWeek,
  }) async {
    try {
      final habit = await ref.read(habitRepositoryProvider).create(
            arg,
            title: title,
            scope: scope,
            targetPerWeek: targetPerWeek,
          );
      _upsert(habit);
      _todayChanged();
      return null;
    } catch (e) {
      return errorMessageOf(e);
    }
  }

  /// Menyetujui habit bersama dari partner. Tanggal mulainya ditentukan server.
  Future<String?> accept(int habitId) async {
    try {
      final habit = await ref.read(habitRepositoryProvider).accept(habitId);
      _upsert(habit);
      _todayChanged();
      return null;
    } catch (e) {
      return errorMessageOf(e);
    }
  }

  /// Menolak/membatalkan/menghapus. Habit yang belum dihitung dihapus permanen; habit aktif
  /// diarsipkan (tetap dihitung sampai minggu ini selesai) dan tetap muncul dengan status "ending".
  Future<String?> remove(int habitId) async {
    try {
      final archived = await ref.read(habitRepositoryProvider).remove(habitId);
      if (archived == null) {
        _drop(habitId);
      } else {
        _upsert(archived);
      }
      _todayChanged();
      return null;
    } catch (e) {
      return errorMessageOf(e);
    }
  }

  void _upsert(Habit habit) {
    final current = state.valueOrNull;
    if (current == null) return;

    final habits = [...current.list.habits];
    final index = habits.indexWhere((h) => h.id == habit.id);
    if (index >= 0) {
      habits[index] = habit;
    } else {
      habits.add(habit);
    }
    state = AsyncData(current.withHabits(habits));
  }

  void _drop(int habitId) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncData(current.withHabits(current.list.habits.where((h) => h.id != habitId).toList()));
  }

  /// Papan hari ini bergantung pada daftar habit; tandai basi supaya dimuat ulang (satu request).
  void _todayChanged() => ref.invalidate(todayProvider(arg));
}
