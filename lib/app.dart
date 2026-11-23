import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/core/ui/theme.dart';
import 'package:habit_tracker/features/auth/auth_screen.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/circles/circle_setup_screen.dart';
import 'package:habit_tracker/features/home/home_shell.dart';

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const RootGate(),
    );
  }
}

/// Memilih layar dari status sesi. Semua perpindahan login/logout/sesi-dicabut terjadi di sini,
/// jadi tidak ada navigasi manual yang bisa ketinggalan.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    // Sesi berakhir saat dialog / layar tambahan sedang terbuka: tutup semuanya, supaya layar login
    // tidak tertutup route lama yang masih menumpuk di atasnya.
    ref.listen<SessionStatus>(
      sessionProvider.select((s) => s.status),
      (previous, next) {
        if (next == SessionStatus.unauthenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );

    switch (session.status) {
      case SessionStatus.booting:
        return const Scaffold(body: CenteredLoading());
      case SessionStatus.bootFailed:
        return Scaffold(
          body: ErrorRetryView(
            message: session.message ?? 'Tidak bisa terhubung ke server.',
            onRetry: () => ref.read(sessionProvider.notifier).retryBoot(),
            secondaryLabel: 'Keluar',
            onSecondary: () => ref.read(sessionProvider.notifier).logout(),
          ),
        );
      case SessionStatus.unauthenticated:
        return const AuthScreen();
      case SessionStatus.authenticated:
        return session.circles.isEmpty ? const CircleSetupScreen() : const HomeShell();
    }
  }
}
