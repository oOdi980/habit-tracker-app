import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/core/util/dates.dart';
import 'package:habit_tracker/features/circles/circle_models.dart';
import 'package:habit_tracker/features/circles/circle_repository.dart';

Future<void> showInviteDialog(BuildContext context, {required int circleId}) {
  return showDialog<void>(
    context: context,
    builder: (_) => InviteDialog(circleId: circleId),
  );
}

/// Membuat kode undangan untuk partner. Kode TIDAK dibuat otomatis saat dialog dibuka: setiap
/// kode baru menghanguskan kode lama yang masih aktif, dan dibatasi 10 kali per jam di server.
class InviteDialog extends ConsumerStatefulWidget {
  const InviteDialog({super.key, required this.circleId});

  final int circleId;

  @override
  ConsumerState<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<InviteDialog> {
  CircleInvite? _invite;
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final invite = await ref.read(circleRepositoryProvider).createInvite(widget.circleId);
      if (!mounted) return;
      setState(() => _invite = invite);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(CircleInvite invite) async {
    await Clipboard.setData(ClipboardData(text: invite.displayCode));
    if (!mounted) return;
    showSnack(context, 'Kode disalin.');
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Undang partner'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (invite == null)
            const Text(
              'Buat kode lalu kirim ke partner. Dia memasukkannya saat daftar atau di menu "Pakai kode undangan". '
              'Kode lama yang masih aktif akan hangus.',
            )
          else ...[
            Center(
              child: SelectableText(
                invite.displayCode,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Berlaku sampai ${formatLocalDateTime(invite.expiresAt)} dan hanya bisa dipakai sekali.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tutup')),
        if (invite != null) TextButton(onPressed: () => _copy(invite), child: const Text('Salin')),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(invite == null ? 'Buat kode' : 'Buat ulang'),
        ),
      ],
    );
  }
}
