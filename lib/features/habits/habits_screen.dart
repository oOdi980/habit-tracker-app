import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/core/util/dates.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/habits/habit_form_sheet.dart';
import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/habits/habits_controller.dart';

/// Daftar semua habit sesi: menunggu persetujuan, akan mulai, aktif, dan yang sedang berhenti.
/// Di sinilah habit dibuat, disetujui/ditolak, dan dihapus. (Edit target dan izin menyusul di fase berikutnya.)
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key, required this.circleId});

  final int circleId;

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  final Set<int> _busy = <int>{};

  Circle? get _circle {
    final session = ref.read(sessionProvider);
    for (final circle in session.circles) {
      if (circle.id == widget.circleId) return circle;
    }
    return null;
  }

  String _nameOf(int? userId) {
    final circle = _circle;
    if (circle != null) {
      for (final member in circle.members) {
        if (member.id == userId) return member.name;
      }
    }
    return 'partner';
  }

  Future<void> _refresh() async {
    final error = await ref.read(habitsProvider(widget.circleId).notifier).refresh();
    if (!mounted) return;
    if (error != null) showSnack(context, error);
  }

  Future<void> _openForm() async {
    final session = ref.read(sessionProvider);
    final myId = session.user?.id;
    final circle = _circle;
    if (myId == null || circle == null) return;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HabitFormSheet(
        circleId: widget.circleId,
        canCreateShared: circle.members.length >= kCircleCapacity,
        partnerName: circle.partnerOf(myId)?.name,
      ),
    );

    if (!mounted || created != true) return;
    showSnack(context, 'Habit dibuat.');
  }

  /// Menjalankan satu aksi untuk satu habit dengan penjaga tap-ganda dan pesan error seragam.
  Future<void> _run(Habit habit, Future<String?> Function() action, {String? successMessage}) async {
    if (_busy.contains(habit.id)) return;

    setState(() => _busy.add(habit.id));
    final error = await action();
    if (!mounted) return;

    setState(() => _busy.remove(habit.id));
    if (error != null) {
      showSnack(context, error);
    } else if (successMessage != null) {
      showSnack(context, successMessage);
    }
  }

  Future<void> _confirmRemove(Habit habit) async {
    final (title, body, action) = switch (habit.status) {
      HabitStatus.pendingApproval => (
          habit.needsMyApproval ? 'Tolak habit ini?' : 'Batalkan habit ini?',
          'Habit akan dihapus.',
          habit.needsMyApproval ? 'Tolak' : 'Batalkan',
        ),
      HabitStatus.upcoming => (
          'Hapus habit ini?',
          'Habit belum mulai dihitung, jadi dihapus permanen.',
          'Hapus',
        ),
      _ => (
          'Hentikan habit ini?',
          'Habit tetap dihitung sampai minggu ini selesai, lalu berhenti. Riwayatnya tetap tersimpan.',
          'Hentikan',
        ),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(action)),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    await _run(habit, () => ref.read(habitsProvider(widget.circleId).notifier).remove(habit.id));
  }

  @override
  Widget build(BuildContext context) {
    final circleId = widget.circleId;
    final listAsync = ref.watch(habitsProvider(circleId));
    final myId = ref.watch(sessionProvider.select((s) => s.user?.id));

    final value = listAsync.valueOrNull;
    Widget body;

    if (value == null || myId == null) {
      final error = listAsync.error;
      body = error != null
          ? ErrorRetryView(
              message: errorMessageOf(error),
              onRetry: () => ref.invalidate(habitsProvider(circleId)),
            )
          : const CenteredLoading();
    } else {
      body = _buildList(context, value.list.habits, myId);
    }

    return Scaffold(
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Habit baru'),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Habit> habits, int myId) {
    List<Habit> byStatus(HabitStatus status) => habits.where((h) => h.status == status).toList();

    final pending = byStatus(HabitStatus.pendingApproval);
    final upcoming = byStatus(HabitStatus.upcoming);
    final active = byStatus(HabitStatus.active);
    final ending = byStatus(HabitStatus.ending);
    final isEmpty = pending.isEmpty && upcoming.isEmpty && active.isEmpty && ending.isEmpty;

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Ruang di bawah supaya tombol "Habit baru" tidak menutupi kartu terakhir.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  'Belum ada habit. Tekan "Habit baru" untuk mulai.',
                  textAlign: TextAlign.center,
                ),
              ),
            ..._section(context, 'Menunggu persetujuan', pending, myId),
            ..._section(context, 'Akan mulai', upcoming, myId),
            ..._section(context, 'Aktif', active, myId),
            ..._section(context, 'Berhenti setelah minggu ini', ending, myId),
          ],
        ),
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<Habit> habits, int myId) {
    if (habits.isEmpty) return const <Widget>[];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final habit in habits) _habitCard(context, habit, myId),
    ];
  }

  Widget _habitCard(BuildContext context, Habit habit, int myId) {
    final theme = Theme.of(context);
    final busy = _busy.contains(habit.id);

    final scopeText = habit.scope == HabitScope.shared ? 'Bersama' : 'Pribadi · ${_nameOf(habit.ownerId)}';

    final String detail;
    switch (habit.status) {
      case HabitStatus.pendingApproval:
        detail = habit.needsMyApproval
            ? 'Diusulkan ${_nameOf(habit.createdBy)}. Setujui supaya mulai dihitung.'
            : 'Menunggu persetujuan ${_nameOf(_otherThan(habit.createdBy))}.';
      case HabitStatus.upcoming:
        detail = habit.startsOn == null ? 'Segera mulai' : 'Mulai ${formatDayAndShortDate(habit.startsOn!)}';
      case HabitStatus.ending:
        detail = habit.endsOn == null ? 'Berhenti segera' : 'Berhenti ${formatDayAndShortDate(habit.endsOn!)}';
      default:
        final next = habit.nextTarget;
        detail = next == null
            ? 'Sedang dihitung'
            : 'Target jadi ${next.target}× mulai ${formatDayAndShortDate(next.from)}';
    }

    final Widget actions;
    if (habit.status == HabitStatus.pendingApproval && habit.needsMyApproval) {
      actions = Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: busy
                ? null
                : () => _run(
                      habit,
                      () => ref.read(habitsProvider(widget.circleId).notifier).accept(habit.id),
                      successMessage: 'Habit disetujui.',
                    ),
            child: const Text('Setujui'),
          ),
          OutlinedButton(onPressed: busy ? null : () => _confirmRemove(habit), child: const Text('Tolak')),
        ],
      );
    } else if (habit.status != HabitStatus.ending && habit.canBeRemovedBy(myId)) {
      actions = TextButton.icon(
        onPressed: busy ? null : () => _confirmRemove(habit),
        icon: const Icon(Icons.delete_outline),
        label: Text(habit.status == HabitStatus.active ? 'Hentikan' : 'Hapus'),
      );
    } else {
      actions = const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$scopeText · ${habit.targetPerWeek}× per minggu',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
            Text(detail),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ),
      ),
    );
  }

  /// Anggota sesi selain [userId] (untuk teks "menunggu persetujuan X").
  int? _otherThan(int userId) {
    final circle = _circle;
    if (circle == null) return null;
    for (final member in circle.members) {
      if (member.id != userId) return member.id;
    }
    return null;
  }
}
