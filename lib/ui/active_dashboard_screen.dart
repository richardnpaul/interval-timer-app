import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/engine/dashboard_view_model.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/widgets/color_swatch_picker.dart';

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------

class ActiveDashboardScreen extends ConsumerWidget {
  const ActiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(activeRoutineProvider);

    if (snapshot == null) {
      return const _IdleView();
    }

    final vm = buildDashboardViewModel(snapshot.definition, snapshot.state);

    return switch (vm) {
      FinishedDashboardViewModel() => _FinishedView(vm: vm),
      SequentialDashboardViewModel() => _SequentialView(vm: vm),
      ParallelDashboardViewModel() => _ParallelView(vm: vm),
      IdleDashboardViewModel() => const _IdleView(),
    };
  }
}

// ---------------------------------------------------------------------------
// Idle
// ---------------------------------------------------------------------------

class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_off_outlined,
            size: 72,
            color: cs.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'No routine running',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Go to Routines and tap ▶ to start one',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Finished
// ---------------------------------------------------------------------------

class _FinishedView extends ConsumerWidget {
  final FinishedDashboardViewModel vm;
  const _FinishedView({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            '${vm.routineName} finished!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.done),
            label: const Text('Done'),
            onPressed: () =>
                ref.read(activeRoutineProvider.notifier).stopRoutine(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sequential
// ---------------------------------------------------------------------------

class _SequentialView extends ConsumerWidget {
  final SequentialDashboardViewModel vm;
  const _SequentialView({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // ── Header: routine name + rep badge ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  vm.routineName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vm.totalRepetitions != 1) ...[
                const SizedBox(width: 8),
                _RepBadge(
                  current: vm.currentRepetition,
                  total: vm.totalRepetitions,
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Stop routine',
                color: cs.error,
                onPressed: () =>
                    ref.read(activeRoutineProvider.notifier).stopRoutine(),
              ),
            ],
          ),
        ),
        // ── Hero timer ────────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Center(
            child: vm.hero == null
                ? const CircularProgressIndicator()
                : _HeroTimer(item: vm.hero!),
          ),
        ),
        // ── Up Next list ──────────────────────────────────────────────────
        if (vm.upNext.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Up Next',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: vm.upNext.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) => _UpNextTile(item: vm.upNext[i]),
            ),
          ),
        ] else
          const SizedBox(height: 24),
      ],
    );
  }
}

class _HeroTimer extends StatelessWidget {
  final ActiveTimerItem item;
  const _HeroTimer({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.color != null
        ? colorFromHex(item.color!)
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress ring
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: item.progress,
                strokeWidth: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: color,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Content
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.breadcrumb.isNotEmpty) ...[
                  Text(
                    item.breadcrumb,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  item.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatSeconds(item.remainingSeconds),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UpNextTile extends StatelessWidget {
  final UpNextItem item;
  const _UpNextTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.color != null
        ? colorFromHex(item.color!)
        : theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.breadcrumb.isNotEmpty)
                  Text(
                    item.breadcrumb,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                Text(item.name, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            _formatSeconds(item.durationSeconds),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Parallel
// ---------------------------------------------------------------------------

class _ParallelView extends ConsumerWidget {
  final ParallelDashboardViewModel vm;
  const _ParallelView({required this.vm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  vm.routineName,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (vm.totalRepetitions != 1) ...[
                const SizedBox(width: 8),
                _RepBadge(
                  current: vm.currentRepetition,
                  total: vm.totalRepetitions,
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Stop routine',
                color: cs.error,
                onPressed: () =>
                    ref.read(activeRoutineProvider.notifier).stopRoutine(),
              ),
            ],
          ),
        ),
        // Grid of timer cards
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: vm.activeTimers.length,
            itemBuilder: (context, i) =>
                _ParallelTimerCard(item: vm.activeTimers[i]),
          ),
        ),
      ],
    );
  }
}

class _ParallelTimerCard extends StatelessWidget {
  final ActiveTimerItem item;
  const _ParallelTimerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.color != null
        ? colorFromHex(item.color!)
        : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mini progress ring
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: item.progress,
                      strokeWidth: 6,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: color,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    _formatSeconds(item.remainingSeconds),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (item.breadcrumb.isNotEmpty) ...[
              Text(
                item.breadcrumb,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
            ],
            Text(
              item.name,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _RepBadge extends StatelessWidget {
  final int current;
  final int total; // 0 = infinite

  const _RepBadge({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = total == 0 ? '$current / ∞' : '$current / $total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

String _formatSeconds(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
