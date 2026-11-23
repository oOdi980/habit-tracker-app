import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/core/ui/common_widgets.dart';
import 'package:habit_tracker/features/auth/session_controller.dart';
import 'package:habit_tracker/features/circles/circle_setup_screen.dart';
import 'package:habit_tracker/features/circles/invite_dialog.dart';
import 'package:habit_tracker/features/habits/habits_controller.dart';
import 'package:habit_tracker/features/habits/habits_screen.dart';
import 'package:habit_tracker/features/today/today_controller.dart';
import 'package:habit_tracker/features/today/today_screen.dart';

/// Kerangka setelah login: app bar (sesi + menu) dan dua tab: Hari ini, Habit.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  /// Tab Habit baru dibangun saat pertama dibuka. IndexedStack membangun semua anak sekaligus,
  /// dan membangun tab itu otomatis berarti satu request yang belum tentu dibutuhkan.
  bool _habitsVisited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Aplikasi kembali ke layar (HP dibuka lagi / tab browser aktif lagi): segarkan bila sudah lama.
  /// Ini pengganti polling: partner bisa check-in kapan saja, tapi server tidak dibombardir tiap detik.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final circleId = ref.read(sessionProvider).selectedCircleId;
    if (circleId == null) return;

    ref.read(todayProvider(circleId).notifier).refreshIfStale();
    if (_habitsVisited) ref.read(habitsProvider(circleId).notifier).refreshIfStale();
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 1) _habitsVisited = true;
    });

    if (index == 1) {
      final circleId = ref.read(sessionProvider).selectedCircleId;
      if (circleId != null) ref.read(habitsProvider(circleId).notifier).refreshIfStale();
    }
  }

  Future<void> _onMenu(String value, int circleId) async {
    final session = ref.read(sessionProvider.notifier);

    if (value == 'invite') {
      await showInviteDialog(context, circleId: circleId);
    } else if (value == 'new') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const CircleSetupScreen()),
      );
    } else if (value == 'logout') {
      await session.logout();
    } else if (value.startsWith('circle:')) {
      final id = int.tryParse(value.substring('circle:'.length));
      if (id != null) await session.selectCircle(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final circle = session.selectedCircle;
    final user = session.user;

    if (circle == null || user == null) {
      return const Scaffold(body: CenteredLoading());
    }

    final circleId = circle.id;
    final pendingApprovals = ref.watch(
      todayProvider(circleId).select((a) => a.valueOrNull?.board.pendingHabitApprovals ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(circle.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (value) => _onMenu(value, circleId),
            itemBuilder: (_) => [
              PopupMenuItem<String>(enabled: false, child: Text('Masuk sebagai ${user.name}')),
              const PopupMenuDivider(),
              // Setelah penuh, kode undangan tidak ada gunanya (server pun menolaknya).
              if (!circle.isFull)
                const PopupMenuItem<String>(value: 'invite', child: Text('Undang partner')),
              for (final other in session.circles)
                if (other.id != circleId)
                  PopupMenuItem<String>(value: 'circle:${other.id}', child: Text('Pindah ke ${other.name}')),
              const PopupMenuItem<String>(value: 'new', child: Text('Buat / gabung sesi lain')),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'logout', child: Text('Keluar')),
            ],
          ),
        ],
      ),
      // Key per sesi: pindah sesi membuang state layar lama (set "sedang diproses", dsb).
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(
            key: ValueKey<String>('today-$circleId'),
            circleId: circleId,
            onOpenHabits: () => _selectTab(1),
          ),
          if (_habitsVisited)
            HabitsScreen(key: ValueKey<String>('habits-$circleId'), circleId: circleId)
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Hari ini',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingApprovals > 0,
              label: Text('$pendingApprovals'),
              child: const Icon(Icons.checklist_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingApprovals > 0,
              label: Text('$pendingApprovals'),
              child: const Icon(Icons.checklist),
            ),
            label: 'Habit',
          ),
        ],
      ),
    );
  }
}
