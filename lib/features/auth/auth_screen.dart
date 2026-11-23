import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/features/auth/login_form.dart';
import 'package:habit_tracker/features/auth/register_form.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';

/// Layar masuk/daftar. Berganti bentuk di tempat (bukan push route): saat login berhasil, RootGate
/// mengganti seluruh layar, dan route yang di-push akan tertinggal menutupi layar baru.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(sessionProvider.select((s) => s.message));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.check_circle_outline, size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Habit Tracker',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  if (notice != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(notice, style: TextStyle(color: scheme.onSecondaryContainer)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_registering)
                    RegisterForm(onSwitch: () => setState(() => _registering = false))
                  else
                    LoginForm(onSwitch: () => setState(() => _registering = true)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
