import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/features/today/habit_tile.dart';
import 'package:habit_tracker/features/today/today_models.dart';
import '../support/fixtures.dart';

TodayHabit _habit({
  String scope = 'personal',
  int? ownerId = 1,
  int done = 2,
  List<int> doneToday = const <int>[],
  bool canCheckIn = true,
  String? leave,
}) =>
    TodayHabit.fromJson(todayHabitJson(
      scope: scope,
      ownerId: ownerId,
      done: done,
      doneToday: doneToday,
      canCheckIn: canCheckIn,
      leave: leave,
    ));

Future<void> _pump(
  WidgetTester tester,
  TodayHabit habit, {
  bool busy = false,
  VoidCallback? onCheckIn,
  VoidCallback? onUndo,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HabitTile(
            habit: habit,
            myId: 1,
            members: circle().members,
            busy: busy,
            onCheckIn: onCheckIn ?? () {},
            onUndo: onUndo ?? () {},
          ),
        ),
      ),
    ),
  );
}

Finder get _filledButton => find.byWidgetPredicate((widget) => widget is FilledButton);

void main() {
  testWidgets('menampilkan judul, progres, dan tombol check-in', (tester) async {
    var checkIns = 0;
    await _pump(tester, _habit(), onCheckIn: () => checkIns++);

    expect(find.text('Lari pagi'), findsOneWidget);
    expect(find.text('2 dari 5 hari minggu ini'), findsOneWidget);
    expect(find.text('Check-in'), findsOneWidget);

    await tester.tap(find.text('Check-in'));

    expect(checkIns, 1);
  });

  testWidgets('sudah check-in: tampil status dan tombol Batalkan', (tester) async {
    var undos = 0;
    await _pump(tester, _habit(doneToday: [1]), onUndo: () => undos++);

    expect(find.text('Sudah hari ini'), findsOneWidget);
    expect(find.text('Check-in'), findsNothing);

    await tester.tap(find.text('Batalkan'));

    expect(undos, 1);
  });

  testWidgets('saat request berjalan tombol dinonaktifkan (tidak bisa tap ganda)', (tester) async {
    var checkIns = 0;
    await _pump(tester, _habit(), busy: true, onCheckIn: () => checkIns++);

    final button = tester.widget<FilledButton>(_filledButton);

    expect(button.onPressed, isNull);
    expect(checkIns, 0);
  });

  testWidgets('habit personal partner hanya dipantau, tanpa tombol check-in', (tester) async {
    await _pump(tester, _habit(ownerId: 2, canCheckIn: false));

    expect(find.text('Dipantau saja'), findsOneWidget);
    expect(find.text('Check-in'), findsNothing);
    // Hanya pemilik (Anjal) yang relevan untuk habit personal.
    expect(find.text('Anjal'), findsOneWidget);
    expect(find.text('Kamu'), findsNothing);
  });

  testWidgets('habit bersama menampilkan kedua anggota dan aturan together', (tester) async {
    await _pump(tester, _habit(scope: 'shared', ownerId: null, doneToday: [2]));

    expect(find.text('Kamu'), findsOneWidget);
    expect(find.text('Anjal'), findsOneWidget);
    expect(find.text('Hari dihitung kalau kalian berdua check-in.'), findsOneWidget);
  });

  testWidgets('status izin tampil sebagai label', (tester) async {
    await _pump(tester, _habit(leave: 'approved'));

    expect(find.text('Izin minggu ini disetujui'), findsOneWidget);
  });

  testWidgets('target tercapai menampilkan ikon verified', (tester) async {
    await _pump(tester, _habit(done: 5));

    expect(find.byIcon(Icons.verified), findsOneWidget);
  });
}
