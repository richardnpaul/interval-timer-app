import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/edit_preset_screen.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EditPresetScreen Additional Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
      );
    });

    testWidgets('Creates a new preset and saves it', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditPresetScreen()),
        ),
      );

      // Verify title
      expect(find.text('New Preset'), findsOneWidget);
      expect(find.text('Delete Preset'), findsNothing);

      // Enter name
      await tester.enterText(
        find.byType(TextFormField).first,
        'My Custom Preset',
      );

      // Enter duration
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seconds'),
        '30',
      );

      // Tap save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final presets = container.read(presetsProvider);
      expect(presets.length, 1);
      expect(presets.first.name, 'My Custom Preset');
      expect(presets.first.defaultDuration, 30);
    });

    testWidgets('Validates name before saving', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditPresetScreen()),
        ),
      );

      // Don't enter name, just tap save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('Name is required'), findsOneWidget);

      // Presets should be empty
      final presets = container.read(presetsProvider);
      expect(presets, isEmpty);
    });

    testWidgets('Validates duration before saving', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditPresetScreen()),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'Valid Name');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seconds'),
        '0',
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Check for validation error
      expect(find.text('Must be a positive number'), findsOneWidget);

      // Presets should be empty
      final presets = container.read(presetsProvider);
      expect(presets, isEmpty);
    });

    testWidgets('Cancels deletion dialog', (tester) async {
      final preset = TimerPreset(
        id: 'p1',
        name: 'Existing',
        defaultDuration: 10,
      );
      container.read(presetsProvider.notifier).savePreset(preset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: EditPresetScreen(preset: preset)),
        ),
      );

      // Tap delete
      await tester.tap(find.widgetWithIcon(TextButton, Icons.delete));
      await tester.pumpAndSettle();

      // Tap cancel in dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Preset should still exist
      final presets = container.read(presetsProvider);
      expect(presets.length, 1);
    });
  });
}
