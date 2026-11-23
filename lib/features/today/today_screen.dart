import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/core/util/dates.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/today/habit_tile.dart';
import 'package:habit_tracker/features/today/today_controller.dart';
import 'package:habit_tracker/features/today/today_models.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key, required this.circleId, required this.onOpenHabits});

  final int circleId;

  /// Pindah ke tab daftar habit (dari banner "menunggu persetujuan").
  final VoidCallback onOpenHabits;

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// Habit yang sedang menunggu balasan server. Mencegah tap ganda (dan request percuma).
  final Set<int> _busy = <int>{};

  Future<void> _toggle(TodayHabit habit, {required bool undo}) async {
    if (_busy.contains(habit.id)) return;

    setState(() => _busy.add(habit.id));
    final error = await ref.read(todayProvider(widget.circleId).notifier).setCheckedIn(habit.id, undo: undo);
    if (!mounted) return;

    setState(() => _busy.remove(habit.id));
    if (error != null) showSnack(context, error);
  }

  Future<void> _refresh() async {
    final error = await ref.read(todayProvider(widget.circleId).notifier).refresh();
    if (!mounted) return;
    if (error != null) showSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final circleId = widget.circleId;
    final boardAsync = ref.watch(todayProvider(circleId));
    final myId = ref.watch(sessionProvider.select((s) => s.user?.id));

    // Papan selalu membawa daftar anggota terbaru; dipakai untuk menyegarkan sesi tanpa request tambahan
    // (mis. partner baru bergabung -> menu "Undang partner" hilang).
    ref.listen<AsyncValue<TodayState>>(todayProvider(circleId), (previous, next) {
      final board = next.valueOrNull?.board;
      if (board != null) {
        ref.read(sessionProvider.notifier).syncMembers(circleId, board.members);
      }
    });

    final value = boardAsync.valueOrNull;
    if (value == null || myId == null) {
      final error = boardAsync.error;
      if (error != null) {
        return ErrorRetryView(
          message: errorMessageOf(error),
          onRetry: () => ref.invalidate(todayProvider(circleId)),
        );
      }
      return const CenteredLoading();
    }

    final board = value.board;
    final partnerName = _partnerName(board, myId);

    final shared = board.habits.where((h) => h.scope == HabitScope.shared).toList();
    final mine = board.habits.where((h) => h.scope == HabitScope.personal && h.ownerId == myId).toList();
    final theirs = board.habits.where((h) => h.scope == HabitScope.personal && h.ownerId != myId).toList();

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          // Selalu bisa ditarik, termasuk saat isinya sedikit (kalau tidak, pull-to-refresh mati).
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(formatLongDate(board.date), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Minggu ini: ${formatWeekRange(board.weekStart, board.weekEnd)} · ${board.timezone}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (board.pendingHabitApprovals > 0)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.pending_actions),
                  title: Text('${board.pendingHabitApprovals} habit bersama menunggu persetujuanmu'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenHabits,
                ),
              ),
            if (board.otherPendingItems > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${board.otherPendingItems} hal lain menunggu (izin, reward/punishment). Layarnya menyusul.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (board.habits.isEmpty)
              _EmptyBoard(onOpenHabits: widget.onOpenHabits)
            else ...[
              ..._section(context, 'Bersama', shared, board, myId),
              ..._section(context, 'Punyamu', mine, board, myId),
              ..._section(context, 'Punya $partnerName', theirs, board, myId),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<TodayHabit> habits, TodayBoard board, int myId) {
    if (habits.isEmpty) return const <Widget>[];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final habit in habits)
        HabitTile(
          key: ValueKey<int>(habit.id),
          habit: habit,
          myId: myId,
          members: board.members,
          busy: _busy.contains(habit.id),
          onCheckIn: () => _toggle(habit, undo: false),
          onUndo: () => _toggle(habit, undo: true),
        ),
    ];
  }

  String _partnerName(TodayBoard board, int myId) {
    for (final member in board.members) {
      if (member.id != myId) return member.name;
    }
    return 'partner';
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({required this.onOpenHabits});

  final VoidCallback onOpenHabits;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text(
            'Belum ada habit yang sedang dihitung.\n'
            'Habit baru mulai dihitung Senin depan; habit bersama menunggu persetujuan partner dulu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onOpenHabits, child: const Text('Lihat daftar habit')),
        ],
      ),
    );
  }
}
