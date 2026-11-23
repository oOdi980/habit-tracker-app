import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/api/api_exception.dart';
import 'package:habit_tracker/core/ui/error_text.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({super.key, required this.onSwitch});

  /// Kembali ke formulir masuk.
  final VoidCallback onSwitch;

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _invite = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error; // pesan umum (tidak terkait satu field)
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _invite.dispose();
    super.dispose();
  }

  String? _fieldError(String field) {
    final messages = _fieldErrors[field];
    return (messages == null || messages.isEmpty) ? null : messages.first;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    // Pemeriksaan ringan di HP supaya tidak membuang request; aturan sebenarnya milik server.
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _fieldErrors = const <String, List<String>>{};
        _error = 'Nama, email, dan password wajib diisi.';
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _fieldErrors = const <String, List<String>>{
          'password': ['Password minimal 8 karakter.'],
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

    try {
      await ref.read(sessionProvider.notifier).register(
            name: name,
            email: email,
            password: password,
            inviteCode: _invite.text,
          );
      // Sukses: RootGate mengganti layar.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        // Pesan field sudah tampil di bawah kolomnya; sisanya (mis. 429) ditampilkan di sini.
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
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: InputDecoration(labelText: 'Nama', errorText: _fieldError('name')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: InputDecoration(labelText: 'Email', errorText: _fieldError('email')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password (min. 8 karakter)',
              errorText: _fieldError('password'),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _invite,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Kode undangan',
              helperText: 'Dari partner kamu. Kosongkan hanya untuk akun pertama di server.',
              helperMaxLines: 2,
              errorText: _fieldError('invite_code'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Daftar'),
          ),
          TextButton(
            onPressed: _busy ? null : widget.onSwitch,
            child: const Text('Sudah punya akun? Masuk'),
          ),
        ],
      ),
    );
  }
}
