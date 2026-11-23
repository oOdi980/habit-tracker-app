import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/today/today_models.dart';
import 'package:habit_tracker/features/today/today_repository.dart';

@immutable
class TodayState {
  const TodayState({required this.board, required this.loadedAt});

  final TodayBoard board;

  /// Kapan papan ini diambil (jam HP). Hanya untuk memutuskan perlu tidaknya muat ulang saat
  /// aplikasi dibuka kembali; bukan untuk logika tanggal (itu urusan server).
  final DateTime loadedAt;
}

/// Papan hari ini per sesi. Tidak ada polling: data dimuat saat dibuka, ditarik manual,
/// dan dimuat ulang saat aplikasi kembali ke layar bila sudah lama.
final todayProvider = AsyncNotifierProvider.family<TodayController, TodayState, int>(TodayController.new);

class TodayController extends FamilyAsyncNotifier<TodayState, int> {
  @override
  Future<TodayState> build(int arg) async {
    // Ganti akun = papan baru. Tanpa ini papan akun lama bisa tersisa di memori.
    ref.watch(sessionProvider.select((s) => s.user?.id));

    final board = await ref.read(todayRepositoryProvider).board(arg);
    return TodayState(board: board, loadedAt: DateTime.now());
  }

  /// Muat ulang tanpa mengosongkan layar. Mengembalikan pesan error, atau null bila sukses.
  Future<String?> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncLoading<TodayState>();

    try {
      final board = await ref.read(todayRepositoryProvider).board(arg);
      state = AsyncData(TodayState(board: board, loadedAt: DateTime.now()));
      return null;
    } catch (e, st) {
      // Data lama tetap tampil kalau ada; error hanya jadi pesan.
      if (previous == null) state = AsyncError<TodayState>(e, st);
      return errorMessageOf(e);
    }
  }

  /// Dipanggil saat aplikasi kembali dibuka: muat ulang hanya bila datanya sudah basi.
  Future<void> refreshIfStale({Duration maxAge = const Duration(seconds: 60)}) async {
    final current = state.valueOrNull;
    if (current == null || state.isLoading) return;
    if (DateTime.now().difference(current.loadedAt) < maxAge) return;
    await refresh();
  }

  /// Check-in ([undo] = false) atau batalkan check-in hari ini ([undo] = true).
  /// Mengembalikan pesan error, atau null bila sukses.
  Future<String?> setCheckedIn(int habitId, {required bool undo}) async {
    final session = ref.read(sessionProvider);
    final me = session.user;
    if (me == null) return 'Kamu belum masuk.';

    final repo = ref.read(todayRepositoryProvider);

    try {
      final result = undo
          ? await repo.undoCheckIn(habitId)
          : await repo.checkIn(habitId, tappedAt: DateTime.now());

      final current = state.valueOrNull;
      if (current == null) return null;

      // Server memakai tanggal/minggu SESI. Bila beda dengan papan yang tampil, hari (atau minggu)
      // sudah berganti sejak papan dimuat: menempel hasil ke papan lama akan menyesatkan, muat ulang.
      final sameDay = result.logDate == current.board.date && result.progress.weekStart == current.board.weekStart;
      if (!sameDay) {
        await refresh();
        return null;
      }

      state = AsyncData(
        TodayState(
          board: current.board.withCheckIn(
            habitId: habitId,
            userId: me.id,
            checkedIn: !undo,
            progress: result.progress,
          ),
          loadedAt: current.loadedAt,
        ),
      );
      return null;
    } on ApiException catch (e) {
      // 422/404 di sini biasanya berarti papan basi (habit berakhir, minggu terkunci, habit dihapus
      // partner). Segarkan di latar belakang supaya tampilan menyusul kenyataan.
      if (e.type == ApiErrorType.validation || e.type == ApiErrorType.notFound) {
        await refresh();
      }
      return e.message;
    } catch (e) {
      return errorMessageOf(e);
    }
  }
}
