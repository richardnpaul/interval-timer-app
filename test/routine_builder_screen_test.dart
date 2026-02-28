import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/routine_builder_screen.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RoutineBuilderScreen Additional Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
    });

    testWidgets('Shows error if saving without a name', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: RoutineBuilderScreen()),
        ),
      );

      // Verify the screen loads
      expect(find.text('Root: sequential'), findsOneWidget);

      // Find save button and tap it
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Check for snackbar
      expect(find.text('Please enter a routine name first.'), findsOneWidget);

      // Routines should be empty
      final routines = container.read(routinesProvider);
      expect(routines, isEmpty);
    });

    testWidgets('Can wrap active selection in a new group', (tester) async {
      final child1 = TimerInstance(id: 't1', name: 'Timer 1', duration: 10);
      final child2 = TimerInstance(id: 't2', name: 'Timer 2', duration: 15);
      final routine = GroupNode(
        id: 'r1',
        name: 'My Routine',
        children: [child1, child2],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      // Tap multi-select
      await tester.tap(find.byTooltip('Multi-select'));
      await tester.pumpAndSettle();

      // Select both items
      await tester.tap(find.widgetWithText(ListTile, 'Timer 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Timer 2'));
      await tester.pumpAndSettle();

      // Tap wrap
      await tester.tap(find.byTooltip('Wrap selected in group'));
      await tester.pumpAndSettle();

      // Ensure the UI updated to show a single wrapper group with 2 items inside
      expect(find.text('Group'), findsOneWidget); // Default group name
      expect(find.text('Timer 1'), findsOneWidget);
    });

    testWidgets('Cancels delete routine dialog', (tester) async {
      final routine = GroupNode(id: 'r1', name: 'My Routine');
      container.read(routinesProvider.notifier).saveRoutine(routine);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: routine)),
        ),
      );

      // Tap the root group header to edit it
      await tester.tap(find.textContaining('Root:'));
      await tester.pumpAndSettle();

      // Tap delete routine
      await tester.tap(find.textContaining('Delete Routine'));
      await tester.pumpAndSettle();

      // Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verfiy routine is not deleted
      final routines = container.read(routinesProvider);
      expect(routines.length, 1);
    });
  });
}
