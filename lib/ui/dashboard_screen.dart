
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/edit_timer_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'widgets/active_timer_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _keepAwake = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadWakelockState();
  }

  Future<void> _checkPermissions() async {
    await ref.read(permissionServiceProvider).requestNotificationPermission();
  }

  Future<void> _loadWakelockState() async {
    final enabled = await ref.read(settingsServiceProvider).isWakelockEnabled();
    setState(() {
      _keepAwake = enabled;
    });
  }

  Future<void> _toggleWakelock() async {
    setState(() {
      _keepAwake = !_keepAwake;
    });
    await ref.read(settingsServiceProvider).setWakelock(_keepAwake);
  }

  @override
  Widget build(BuildContext context) {
    final activeTimers = ref.watch(activeTimersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parallel Timer'),
        actions: [
          IconButton(
            icon: Icon(
              _keepAwake ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              color: _keepAwake ? Colors.orange : null,
            ),
            tooltip: 'Keep Screen On',
            onPressed: _toggleWakelock,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Global settings coming soon!')),
              );
            },
          ),
        ],
      ),
      body: activeTimers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No timers running',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to start a timer',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: activeTimers.length,
              itemBuilder: (context, index) {
                final timer = activeTimers[index];
                return ActiveTimerCard(timer: timer);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditTimerScreen()),
          );
        },
        label: const Text('Start Timer'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
