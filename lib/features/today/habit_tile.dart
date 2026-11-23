import 'package:flutter/material.dart';

import 'package:habit_tracker/core/util/dates.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/today/today_models.dart';

/// Kartu satu habit di papan hari ini. Murni tampilan: tidak tahu soal jaringan atau state global,
/// semua aksi lewat callback (mudah dites sebagai widget biasa).
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.myId,
    required this.members,
    required this.busy,
    required this.onCheckIn,
    required this.onUndo,
  });

  final TodayHabit habit;
  final int myId;
  final List<CircleMember> members;

  /// Ada request check-in/undo yang sedang berjalan untuk habit ini.
  final bool busy;
  final VoidCallback onCheckIn;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // clamp() pada double bertipe num; LinearProgressIndicator butuh double.
    final double ratio =
        habit.targetPerWeek <= 0 ? 0.0 : (habit.weekDone / habit.targetPerWeek).clamp(0.0, 1.0).toDouble();
    final doneByMe = habit.isDoneTodayBy(myId);

    // Habit bersama: kedua anggota relevan. Personal: hanya pemiliknya.
    final relevant = habit.scope == HabitScope.shared
        ? members
        : members.where((m) => m.id == habit.ownerId).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(habit.title, style: theme.textTheme.titleMedium)),
                if (habit.weekAchieved)
                  Tooltip(
                    message: 'Target minggu ini tercapai',
                    child: Icon(Icons.verified, color: scheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${habit.weekDone} dari ${habit.targetPerWeek} hari minggu ini',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: ratio, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            if (habit.scope == HabitScope.shared) ...[
              const SizedBox(height: 6),
              Text(
                'Hari dihitung kalau kalian berdua check-in.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final member in relevant)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      habit.isDoneTodayBy(member.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 18,
                      color: habit.isDoneTodayBy(member.id) ? scheme.primary : scheme.outline,
                    ),
                    label: Text(member.id == myId ? 'Kamu' : member.name),
                  ),
                if (habit.leaveStatus == 'pending')
                  const Chip(visualDensity: VisualDensity.compact, label: Text('Izin menunggu persetujuan')),
                if (habit.leaveStatus == 'approved')
                  const Chip(visualDensity: VisualDensity.compact, label: Text('Izin minggu ini disetujui')),
                if (habit.status == HabitStatus.ending)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      habit.endsOn == null
                          ? 'Berhenti setelah minggu ini'
                          : 'Berhenti ${formatDayAndShortDate(habit.endsOn!)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _action(context, doneByMe),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(BuildContext context, bool doneByMe) {
    if (!habit.canCheckIn) {
      // Habit personal partner: hanya dipantau.
      return Text(
        'Dipantau saja',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
      );
    }

    if (doneByMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 20),
          const SizedBox(width: 6),
          const Text('Sudah hari ini'),
          const SizedBox(width: 8),
          TextButton(onPressed: busy ? null : onUndo, child: const Text('Batalkan')),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: busy ? null : onCheckIn,
      icon: busy
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check),
      label: const Text('Check-in'),
    );
  }
}
