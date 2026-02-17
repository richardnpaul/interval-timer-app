import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/edit_timer_screen.dart';
import 'package:interval_timer_app/ui/presets_library_screen.dart';
import 'package:interval_timer_app/ui/groups_library_screen.dart';
import 'widgets/active_timer_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _keepAwake = false;
  int _currentIndex = 0;

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
    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildActiveTimers();
        break;
      case 1:
        body = const PresetsLibraryScreen();
        break;
      case 2:
        body = const GroupsLibraryScreen();
        break;
      default:
        body = _buildActiveTimers();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Active'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Presets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_work),
            label: 'Groups',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditTimerScreen()),
                );
              },
              label: const Text('Start Timer'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildActiveTimers() {
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
                  const Icon(
                    Icons.timer_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
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
    );
  }
}
