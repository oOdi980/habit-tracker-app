import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/features/habits/habit_models.dart';
import 'package:habit_tracker/features/habits/habits_controller.dart';

/// Lembar buat habit baru. Menutup dirinya dengan `true` bila habit berhasil dibuat.
class HabitFormSheet extends ConsumerStatefulWidget {
  const HabitFormSheet({
    super.key,
    required this.circleId,
    required this.canCreateShared,
    required this.partnerName,
  });

  final int circleId;

  /// Habit bersama butuh partner di sesi (server menolak bila belum ada).
  final bool canCreateShared;
  final String? partnerName;

  @override
  ConsumerState<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends ConsumerState<HabitFormSheet> {
  final TextEditingController _title = TextEditingController();

  HabitScope _scope = HabitScope.personal;
  int _target = 5;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Nama habit wajib diisi.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(habitsProvider(widget.circleId).notifier).create(
          title: title,
          scope: _scope,
          targetPerWeek: _target,
        );
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partner = widget.partnerName ?? 'partner';

    return Padding(
      // Naikkan konten di atas keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Habit baru', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_busy,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Nama habit', hintText: 'mis. Olahraga 30 menit'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<HabitScope>(
              segments: [
                const ButtonSegment<HabitScope>(value: HabitScope.personal, label: Text('Pribadi')),
                ButtonSegment<HabitScope>(
                  value: HabitScope.shared,
                  label: const Text('Bersama'),
                  enabled: widget.canCreateShared,
                ),
              ],
              selected: {_scope},
              onSelectionChanged: _busy ? null : (selection) => setState(() => _scope = selection.first),
            ),
            const SizedBox(height: 8),
            Text(
              !widget.canCreateShared
                  ? 'Habit bersama butuh partner di sesi ini. Undang dulu lewat menu.'
                  : _scope == HabitScope.personal
                      ? 'Hanya kamu yang check-in; $partner ikut memantau. Mulai dihitung Senin depan.'
                      : 'Hari dihitung kalau kalian berdua check-in. Mulai dihitung setelah $partner menyetujui.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            Text('Target: $_target× per minggu', style: theme.textTheme.titleSmall),
            Slider(
              value: _target.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_target×',
              onChanged: _busy ? null : (value) => setState(() => _target = value.round()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
