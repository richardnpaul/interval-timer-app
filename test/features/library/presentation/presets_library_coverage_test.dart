import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/core/domain/group_node.dart';
import 'package:interval_timer_app/core/domain/timer_preset.dart';
import 'package:interval_timer_app/features/library/application/library_notifiers.dart';
import 'package:interval_timer_app/features/library/presentation/presets_library_screen.dart';
import 'package:interval_timer_app/features/library/presentation/edit_preset_screen.dart';
import 'package:interval_timer_app/features/routine_builder/presentation/routine_builder_screen.dart';

void main() {
  group('PresetsLibraryScreen Coverage Tests', () {
    testWidgets('Empty state displays correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([])),
            routinesProvider.overrideWith(() => FakeRoutinesNotifier([])),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      expect(find.text('Library is empty'), findsOneWidget);
      expect(find.text('Tap + to create a preset or routine'), findsOneWidget);
    });

    testWidgets('Routine interactions: Tap, Delete Button, and Swipe', (
      tester,
    ) async {
      final routine = GroupNode(id: 'r1', name: 'Test Routine');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([])),
            routinesProvider.overrideWith(
              () => FakeRoutinesNotifier([routine]),
            ),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      // Tap to navigate
      await tester.tap(find.text('Test Routine'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineBuilderScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Delete via IconButton
      await tester.tap(find.byTooltip('Delete routine'));
      await tester.pump();
      expect(find.text('Routine "Test Routine" deleted'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Test Routine'), findsNothing);

      // Restore and test Swipe
      // (We need a fresh pump or state update, simpler to just test in a separate test or re-setup)
    });

    testWidgets('Routine swipe to delete', (tester) async {
      final routine = GroupNode(id: 'r1', name: 'Test Routine');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([])),
            routinesProvider.overrideWith(
              () => FakeRoutinesNotifier([routine]),
            ),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      await tester.drag(find.text('Test Routine'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Routine "Test Routine" deleted'), findsOneWidget);
      expect(find.text('Test Routine'), findsNothing);
    });

    testWidgets('Preset interactions: Tap, Delete Button, and Swipe', (
      tester,
    ) async {
      final preset = TimerPreset(
        id: 'p1',
        name: 'Test Preset',
        defaultDuration: 75,
      ); // 1m 15s

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([preset])),
            routinesProvider.overrideWith(() => FakeRoutinesNotifier([])),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      expect(find.text('1m 15s'), findsOneWidget);

      // Tap to navigate
      await tester.tap(find.text('Test Preset'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPresetScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Delete via IconButton
      await tester.tap(find.byTooltip('Delete preset'));
      await tester.pump();
      expect(find.text('Preset "Test Preset" deleted'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Test Preset'), findsNothing);
    });

    testWidgets('Preset swipe to delete', (tester) async {
      final preset = TimerPreset(
        id: 'p1',
        name: 'Test Preset',
        defaultDuration: 30,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([preset])),
            routinesProvider.overrideWith(() => FakeRoutinesNotifier([])),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      await tester.drag(find.text('Test Preset'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Preset "Test Preset" deleted'), findsOneWidget);
      expect(find.text('Test Preset'), findsNothing);
    });

    testWidgets('FloatingActionButton Menu interactions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            presetsProvider.overrideWith(() => FakePresetsNotifier([])),
            routinesProvider.overrideWith(() => FakeRoutinesNotifier([])),
          ],
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('New Timer Preset'), findsOneWidget);
      expect(find.text('New Routine Build'), findsOneWidget);

      // Test New Timer Preset navigation
      await tester.tap(find.text('New Timer Preset'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPresetScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Test New Routine Build navigation
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Routine Build'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineBuilderScreen), findsOneWidget);
    });
  });
}

class FakeRoutinesNotifier extends RoutinesNotifier {
  final List<GroupNode> initialRoutines;
  FakeRoutinesNotifier(this.initialRoutines);

  @override
  List<GroupNode> build() => initialRoutines;

  @override
  Future<void> deleteRoutine(String id) async {
    state = state.where((r) => r.id != id).toList();
  }
}

class FakePresetsNotifier extends PresetsNotifier {
  final List<TimerPreset> initialPresets;
  FakePresetsNotifier(this.initialPresets);

  @override
  List<TimerPreset> build() => initialPresets;

  @override
  Future<void> deletePreset(String id) async {
    state = state.where((p) => p.id != id).toList();
  }
}
