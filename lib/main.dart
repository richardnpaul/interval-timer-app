import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interval_timer_app/core/services/background_service.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';
import 'package:interval_timer_app/features/timer/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Storage
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);

  // Initialize Background Service
  await initializeService();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const IntervalTimerApp(),
    ),
  );
}

class IntervalTimerApp extends StatelessWidget {
  const IntervalTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interval Timer',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const DashboardScreen(),
    );
  }
}
