import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/groups_library_screen.dart';
import 'package:interval_timer_app/ui/presets_library_screen.dart';

/// Root shell with three bottom-navigation tabs:
///   0 — Routines (build & start);
///   1 — Library (manage presets);
///   2 — Active  (Phase 5 placeholder).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    ref.read(permissionServiceProvider).requestNotificationPermission();
  }

  static const _titles = ['Routines', 'Library', 'Active'];

  @override
  Widget build(BuildContext context) {
    final activeRoutine = ref.watch(activeRoutineProvider);

    final tabs = [
      const GroupsLibraryScreen(),
      const PresetsLibraryScreen(),
      // ── Phase 5 placeholder ───────────────────────────────────────────────
      Center(
        child: activeRoutine == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_off_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No routine running',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to Routines and tap ▶ to start one',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_filled,
                    size: 64,
                    color: Colors.deepOrangeAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Running: ${activeRoutine.definition.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    onPressed: () =>
                        ref.read(activeRoutineProvider.notifier).stopRoutine(),
                  ),
                ],
              ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Routines',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Active',
          ),
        ],
      ),
    );
  }
}
