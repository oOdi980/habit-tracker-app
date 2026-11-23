import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';

enum _SetupMode { create, join }

/// Zona waktu yang ditawarkan. Dikunci server setelah sesi dibuat, jadi pilihannya sengaja sedikit
/// dan jelas. Nilainya nama zona IANA yang diterima validasi server.
const List<({String label, String value})> _timezones = [
  (label: 'WIB', value: 'Asia/Jakarta'),
  (label: 'WITA', value: 'Asia/Makassar'),
  (label: 'WIT', value: 'Asia/Jayapura'),
];

/// Membuat sesi baru atau bergabung lewat kode undangan. Dipakai sebagai layar awal (belum punya
/// sesi) dan sebagai layar yang di-push dari menu (menambah sesi lain).
class CircleSetupScreen extends ConsumerStatefulWidget {
  const CircleSetupScreen({super.key});

  @override
  ConsumerState<CircleSetupScreen> createState() => _CircleSetupScreenState();
}

class _CircleSetupScreenState extends ConsumerState<CircleSetupScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _code = TextEditingController();

  _SetupMode _mode = _SetupMode.create;
  String _timezone = _timezones.first.value;
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String? _fieldError(String field) {
    final messages = _fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final isCreate = _mode == _SetupMode.create;
    final name = _name.text.trim();
    final code = _code.text.trim();

    if (isCreate && name.isEmpty) {
      setState(() {
        _fieldErrors = const <String, List<String>>{
          'name': ['Nama sesi wajib diisi.'],
        };
        _error = null;
      });
      return;
    }
    if (!isCreate && code.isEmpty) {
      setState(() {
        _fieldErrors = const <String, List<String>>{
          'code': ['Kode undangan wajib diisi.'],
        };
        _error = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const <String, List<String>>{};
    });

    final session = ref.read(sessionProvider.notifier);

    try {
      if (isCreate) {
        await session.createCircle(name: name, timezone: _timezone);
      } else {
        await session.joinCircle(code);
      }

      if (!mounted) return;
      // Dipakai sebagai layar awal: RootGate yang menggantinya. Di-push dari menu: tutup sendiri.
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorMessageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCreate = _mode == _SetupMode.create;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai sesi'),
        actions: [
          // Sebagai layar awal tidak ada tombol kembali; beri jalan keluar (salah akun, dsb).
          if (!canPop)
            TextButton(
              onPressed: _busy ? null : () => ref.read(sessionProvider.notifier).logout(),
              child: const Text('Keluar'),
            ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Sesi adalah ruang berdua: habit, progres, dan reward/punishment kalian ada di sini.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              SegmentedButton<_SetupMode>(
                segments: const [
                  ButtonSegment<_SetupMode>(value: _SetupMode.create, label: Text('Buat sesi baru')),
                  ButtonSegment<_SetupMode>(value: _SetupMode.join, label: Text('Pakai kode undangan')),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() {
                          _mode = selection.first;
                          _error = null;
                          _fieldErrors = const <String, List<String>>{};
                        }),
              ),
              const SizedBox(height: 24),
              if (isCreate) ...[
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Nama sesi',
                    hintText: 'mis. Odi & Anjal',
                    errorText: _fieldError('name'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Zona waktu', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    for (final zone in _timezones)
                      ButtonSegment<String>(value: zone.value, label: Text(zone.label)),
                  ],
                  selected: {_timezone},
                  onSelectionChanged: _busy ? null : (selection) => setState(() => _timezone = selection.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Menentukan kapan hari dan minggu berganti untuk kalian berdua. '
                  'Tidak bisa diubah setelah sesi dibuat, jadi pilih zona tempat kalian berada.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ] else
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Kode undangan',
                    hintText: 'ABCD-EFGH',
                    errorText: _fieldError('code'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isCreate ? 'Buat sesi' : 'Gabung'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
