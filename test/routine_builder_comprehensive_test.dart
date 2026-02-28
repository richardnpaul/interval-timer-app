import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/routine_builder_screen.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RoutineBuilderScreen Comprehensive UI Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
    });

    testWidgets('Add items from library, quick timer, and sub-groups', (
      tester,
    ) async {
      // Setup a preset
      final preset = TimerPreset(
        id: 'p1',
        name: 'Exercise',
        defaultDuration: 60,
        color: '#FF0000',
      );
      await container.read(presetsProvider.notifier).savePreset(preset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RoutineBuilderScreen()),
        ),
      );

      // 1. Add Sub-Group via FAB
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Sub-Group'));
      await tester.pumpAndSettle();
      expect(find.text('Group'), findsOneWidget);

      // 2. Add from Library to that group
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Exercise'), findsOneWidget);

      // 3. Add Quick Timer to the same group
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Timer'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Quick One',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Duration (seconds)'),
        '30',
      );
      await tester.tap(find.text('Add Timer'));
      await tester.pumpAndSettle();
      expect(find.text('Quick One'), findsOneWidget);
    });

    testWidgets('Edit Timer Instance and Group properties', (tester) async {
      final child = TimerInstance(id: 't1', name: 'Old Name', duration: 10);
      final routine = GroupNode(id: 'r1', name: 'Routine', children: [child]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      // Edit Timer
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'New Name',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsOneWidget);

      // Edit Group (Root)
      await tester.tap(find.textContaining('Root:'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parallel'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Repetitions  (0 = infinite)'),
        '5',
      );
      await tester.tap(find.byType(FilledButton).last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Root: parallel'), findsOneWidget);
      expect(find.textContaining('Reps: 5'), findsOneWidget);
    });

    testWidgets('Move items up and down', (tester) async {
      final child1 = TimerInstance(id: 't1', name: 'First', duration: 10);
      final child2 = TimerInstance(id: 't2', name: 'Second', duration: 10);
      final routine = GroupNode(
        id: 'r1',
        name: 'Routine',
        children: [child1, child2],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      // Move 'First' down
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);

      // Move 'Second' up
      await tester.tap(find.byTooltip('Move up').last);
      await tester.pumpAndSettle();
    });

    testWidgets('Delete item from builder', (tester) async {
      final child = TimerInstance(id: 't1', name: 'To Delete', duration: 10);
      final routine = GroupNode(id: 'r1', name: 'Routine', children: [child]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      expect(find.text('To Delete'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('To Delete'), findsNothing);
    });
  });
}
