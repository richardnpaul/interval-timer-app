import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/groups_library_screen.dart';
import 'package:interval_timer_app/ui/presets_library_screen.dart';
import 'package:interval_timer_app/ui/edit_preset_screen.dart';
import 'package:interval_timer_app/ui/routine_builder_screen.dart';

void main() {
  group('Explicit Deletion UI Tests', () {
    testWidgets(
      'GroupsLibraryScreen has explicit delete button that removes routine',
      (tester) async {
        final routine = GroupNode(id: 'r1', name: 'Test Routine');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              routinesProvider.overrideWith(
                () => FakeRoutinesNotifier([routine]),
              ),
            ],
            child: const MaterialApp(home: GroupsLibraryScreen()),
          ),
        );

        expect(find.text('Test Routine'), findsOneWidget);

        final deleteButtonFinder = find.widgetWithIcon(
          IconButton,
          Icons.delete_outline,
        );
        expect(
          deleteButtonFinder,
          findsOneWidget,
          reason: 'Expected to find explicit delete button on routine tile',
        );

        await tester.tap(deleteButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(find.text('Test Routine'), findsNothing);
      },
    );

    testWidgets(
      'PresetsLibraryScreen has explicit delete button that removes preset',
      (tester) async {
        final preset = TimerPreset(
          id: 'p1',
          name: 'Test Preset',
          defaultDuration: 10,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              presetsProvider.overrideWith(() => FakePresetsNotifier([preset])),
            ],
            child: const MaterialApp(home: PresetsLibraryScreen()),
          ),
        );

        expect(find.text('Test Preset'), findsOneWidget);

        final deleteButtonFinder = find.widgetWithIcon(
          IconButton,
          Icons.delete_outline,
        );
        expect(
          deleteButtonFinder,
          findsOneWidget,
          reason: 'Expected to find explicit delete button on preset tile',
        );

        await tester.tap(deleteButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(find.text('Test Preset'), findsNothing);
      },
    );

    testWidgets('EditPresetScreen has delete button that removes preset', (
      tester,
    ) async {
      final preset = TimerPreset(
        id: 'p1',
        name: 'Test Preset',
        defaultDuration: 10,
      );
      bool presetDeleted = false;

      // We need a specific notifier override to check if delete was called
      final presetsNotifier = FakePresetsNotifier([preset]);
      presetsNotifier.onDelete = (id) {
        if (id == 'p1') presetDeleted = true;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [presetsProvider.overrideWith(() => presetsNotifier)],
          child: MaterialApp(home: EditPresetScreen(preset: preset)),
        ),
      );

      final deleteButtonFinder = find.widgetWithIcon(TextButton, Icons.delete);
      expect(
        deleteButtonFinder,
        findsOneWidget,
        reason: 'Expected to find a delete button in EditPresetScreen',
      );

      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle(); // UI shows dialog

      final confirmDelete = find.widgetWithText(FilledButton, 'Delete');
      expect(confirmDelete, findsOneWidget);
      await tester.tap(confirmDelete);

      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Check for confirmation dialog if one is added, but for now let's just assert delete happens
      expect(presetDeleted, isTrue, reason: 'Preset should have been deleted');
    });

    testWidgets('RoutineBuilderScreen has delete button for root routine', (
      tester,
    ) async {
      final routine = GroupNode(id: 'r1', name: 'Test Routine');
      bool routineDeleted = false;

      final routinesNotifier = FakeRoutinesNotifier([routine]);
      routinesNotifier.onDelete = (id) {
        if (id == 'r1') routineDeleted = true;
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [routinesProvider.overrideWith(() => routinesNotifier)],
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      // Open the edit sheet for the root routine
      await tester.tap(find.textContaining('Root:'));
      await tester.pumpAndSettle();

      final deleteButtonFinder = find.text('Delete Routine');
      expect(
        deleteButtonFinder,
        findsOneWidget,
        reason: 'Expected to find a Delete Routine button in root edit sheet',
      );

      await tester.tap(deleteButtonFinder);
      await tester.pumpAndSettle(); // wait for dialog

      final confirmDelete = find.widgetWithText(FilledButton, 'Delete');
      await tester.tap(confirmDelete);

      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      expect(
        routineDeleted,
        isTrue,
        reason: 'Routine should have been deleted',
      );
    });
  });
}

class FakeRoutinesNotifier extends RoutinesNotifier {
  final List<GroupNode> initialRoutines;
  void Function(String)? onDelete;

  FakeRoutinesNotifier(this.initialRoutines);

  @override
  List<GroupNode> build() => initialRoutines;

  @override
  Future<void> deleteRoutine(String id) async {
    state = state.where((r) => r.id != id).toList();
    if (onDelete != null) onDelete!(id);
  }
}

class FakePresetsNotifier extends PresetsNotifier {
  final List<TimerPreset> initialPresets;
  void Function(String)? onDelete;

  FakePresetsNotifier(this.initialPresets);

  @override
  List<TimerPreset> build() => initialPresets;

  @override
  Future<void> deletePreset(String id) async {
    state = state.where((p) => p.id != id).toList();
    if (onDelete != null) onDelete!(id);
  }
}
