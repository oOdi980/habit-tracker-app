import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertConfigured();

  runApp(const ProviderScope(child: HabitApp()));
}
