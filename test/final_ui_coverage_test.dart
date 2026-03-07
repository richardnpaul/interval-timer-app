import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interval_timer_app/models/group_node.dart';
import 'package:interval_timer_app/models/timer_instance.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/ui/groups_library_screen.dart';
import 'package:interval_timer_app/ui/presets_library_screen.dart';
import 'package:interval_timer_app/ui/edit_preset_screen.dart';
import 'package:interval_timer_app/ui/routine_builder_screen.dart';
import 'package:interval_timer_app/ui/widgets/audio_picker_tile.dart';
import 'package:interval_timer_app/ui/widgets/color_swatch_picker.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioFileService implements AudioFileService {
  @override
  String getFileName(String? path) =>
      path == null ? 'Default Beep' : 'MockFile';

  @override
  Future<String?> pickAndSaveAudio() async => 'mock/path.mp3';

  @override
  String generateUniqueFileName(String originalName) => 'unique_mock.mp3';

  @override
  Future<Directory> getSoundsDirectory() async => Directory('/tmp/mock_sounds');

  @override
  Future<String> saveToInternalStorage(File sourceFile, String name) async =>
      '/tmp/mock_sounds/mock.mp3';
}

class MockBackgroundServiceWrapper implements BackgroundServiceWrapper {
  final _controller = StreamController<Map<String, dynamic>?>.broadcast();

  @override
  Stream<Map<String, dynamic>?> on(String method) => _controller.stream;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    // No-op for mock
  }
}

void main() {
  group('Final UI Coverage Tests', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          audioFileServiceProvider.overrideWithValue(MockAudioFileService()),
          backgroundServiceWrapperProvider.overrideWithValue(
            MockBackgroundServiceWrapper(),
          ),
        ],
      );
    });

    testWidgets('GroupsLibraryScreen: New Routine dialog flow', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GroupsLibraryScreen()),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(find.text('New Routine'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New Routine'), findsNothing);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My Routine');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Root:'), findsOneWidget);
    });

    testWidgets('PresetsLibraryScreen: label calculation and color handling', (
      tester,
    ) async {
      final p1 = TimerPreset(
        id: '1',
        name: 'Short',
        defaultDuration: 30,
        color: '#FF0000',
      );
      final p2 = TimerPreset(id: '2', name: 'Exact', defaultDuration: 120);
      final p3 = TimerPreset(id: '3', name: 'Mixed', defaultDuration: 135);

      await container.read(presetsProvider.notifier).savePreset(p1);
      await container.read(presetsProvider.notifier).savePreset(p2);
      await container.read(presetsProvider.notifier).savePreset(p3);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      expect(find.text('30s'), findsOneWidget);
      expect(find.text('2m'), findsOneWidget);
      expect(find.text('2m 15s'), findsOneWidget);
    });

    testWidgets('PresetsLibraryScreen: Tap FAB, then delete explicitly', (
      tester,
    ) async {
      final p1 = TimerPreset(id: '1', name: 'To Swap', defaultDuration: 30);
      await container.read(presetsProvider.notifier).savePreset(p1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      // Tap FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('New Preset'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tap delete explicitly
      await tester.tap(find.byTooltip('Delete preset'));
      await tester.pumpAndSettle();
      expect(find.text('To Swap'), findsNothing);
    });

    testWidgets('GroupsLibraryScreen: Start and Delete', (tester) async {
      final r1 = GroupNode(id: 'r1', name: 'Routine X');
      await container.read(routinesProvider.notifier).saveRoutine(r1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GroupsLibraryScreen()),
        ),
      );

      // Start
      await tester.tap(find.byTooltip('Start routine'));
      await tester.pumpAndSettle();

      // Delete
      await tester.tap(find.byTooltip('Delete routine'));
      await tester.pumpAndSettle();
      expect(find.text('Routine X'), findsNothing);
    });

    testWidgets('RoutineBuilderScreen: Delete Routine from builder sheet', (
      tester,
    ) async {
      final r1 = GroupNode(id: 'r1', name: 'Existing Routine');
      await container.read(routinesProvider.notifier).saveRoutine(r1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: r1)),
        ),
      );

      // Edit Root Group
      await tester.tap(find.textContaining('Root:'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Routine'), findsOneWidget);
      await tester.tap(find.text('Delete Routine'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Modal confirm dialog should show
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Existing Routine'), findsNothing);
    });

    testWidgets('RoutineBuilderScreen: Save with empty name', (tester) async {
      final r1 = GroupNode(id: 'r1', name: '');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: r1)),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a routine name first.'), findsOneWidget);
    });

    testWidgets('EditPresetScreen: Delete Preset', (tester) async {
      final p1 = TimerPreset(id: '1', name: 'To Delete', defaultDuration: 30);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: EditPresetScreen(preset: p1)),
        ),
      );

      await tester.tap(find.text('Delete Preset'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    });

    testWidgets('EditPresetScreen: name validation', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditPresetScreen()),
        ),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Name is required'), findsOneWidget);
    });

    testWidgets('AudioPickerTile: Reset to default', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: AudioPickerTile(
                initialPath: 'some/path.mp3',
                soundOffset: 0,
                onPathChanged: (_) {},
                onOffsetChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
    });

    testWidgets('EditPresetScreen: Color & Audio Picker interactions', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditPresetScreen()),
        ),
      );

      // Tap the second color in the ColorSwatchPicker (kColorPalette[1])
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();

      // Tap Alarm Sound tile
      await tester.tap(find.text('Alarm Sound'));
      await tester.pumpAndSettle();

      // Change Offset
      await tester.enterText(find.byType(TextFormField).last, '5');
      await tester.pumpAndSettle();

      // Give it a name to allow saving
      await tester.enterText(
        find.byType(TextFormField).first,
        'Interaction Test',
      );

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final presets = container.read(presetsProvider);
      final saved = presets.firstWhere((p) => p.name == 'Interaction Test');
      expect(saved.soundPath, 'mock/path.mp3');
      expect(saved.soundOffset, 5);
      expect(saved.color, kColorPalette[1]);
    });

    test('Constructor coverage for Groups & Presets screens', () {
      // ignore: prefer_const_constructors
      expect(GroupsLibraryScreen().key, isNull);
      // ignore: prefer_const_constructors
      expect(PresetsLibraryScreen().key, isNull);
    });

    testWidgets('RoutineBuilderScreen: Edge and Interaction Coverage', (
      tester,
    ) async {
      final t1 = TimerInstance(id: 't1', name: 'T1', duration: 10);
      final t2 = TimerInstance(id: 't2', name: 'T2', duration: 10);
      final subGroup = GroupNode(
        id: 'g2',
        name: 'Sub Group',
        children: [t1, t2],
      );
      final r1 = GroupNode(id: 'r1', name: 'Root', children: [subGroup]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: RoutineBuilderScreen(existing: r1)),
        ),
      );

      // 1. Selection Mode & Wrap
      await tester.tap(find.byTooltip('Multi-select'));
      await tester.pumpAndSettle();

      // Check Checkboxes: Sub Group(0), T1(1), T2(2)
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(Checkbox).first,
      ); // Uncheck Sub Group to hit `_selectedIds.remove`
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Wrap selected in group'));
      await tester.pumpAndSettle();

      // 2. Edit Sub-Group (first edit icon is on sub-group wrapper now)
      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();

      // Enter bad reps
      await tester.enterText(find.byType(TextField).last, 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // 3. Edit Timer Instance
      await tester.tap(find.byTooltip('Edit').last);
      await tester.pumpAndSettle();

      // Change Color Ensure we pick picker inside sheet
      final colorTarget1 = find
          .descendant(
            of: find.byType(ColorSwatchPicker),
            matching: find.byType(GestureDetector),
          )
          .at(1);
      await tester.ensureVisible(colorTarget1);
      await tester.tap(colorTarget1);
      await tester.pumpAndSettle();
      // Toggle Switch
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Change Sound & Offset
      await tester.ensureVisible(find.text('Alarm Sound'));
      await tester.tap(find.text('Alarm Sound'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(find.byType(TextFormField).last, '2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final saveTarget = find.text('Save Changes');
      await tester.ensureVisible(saveTarget);
      await tester.tap(saveTarget);
      await tester.pumpAndSettle();

      // 4. Quick Timer sheet Color Picker
      await tester.tap(find.byTooltip('Add to routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick Timer'));
      await tester.pumpAndSettle();

      final colorTarget2 = find
          .descendant(
            of: find.byType(ColorSwatchPicker),
            matching: find.byType(GestureDetector),
          )
          .at(2);
      await tester.ensureVisible(colorTarget2);
      await tester.tap(colorTarget2);
      await tester.pumpAndSettle();
      final quickNameField = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first;
      await tester.ensureVisible(quickNameField);
      await tester.enterText(quickNameField, 'Quick');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final addTarget = find.widgetWithText(FilledButton, 'Add Timer');
      await tester.ensureVisible(addTarget);
      await tester.tap(addTarget);
      await tester.pumpAndSettle();

      // 5. Wrap Error (Different parents)
      await tester.tap(find.byTooltip('Multi-select'));
      await tester.pumpAndSettle();

      // T1/T2 are child of wrapper(Root->Sub->Wrap), Quick is child of Root
      await tester.tap(find.byType(Checkbox).at(2)); // T1 (nested)
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).last); // Quick (root child)
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Wrap selected in group'));
      await tester.pumpAndSettle();
      expect(
        find.text('All selected items must have the same parent to wrap.'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();

      // 6. Save routine correctly
      await tester.enterText(find.byType(TextField).first, 'Valid Save Name');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
    });

    testWidgets('RoutineBuilderScreen: Empty presets Library Sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: RoutineBuilderScreen(
              existing: GroupNode(id: 'r1', name: 'R'),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Add to routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From Library'));
      await tester.pumpAndSettle();
      expect(
        find.text('No presets yet. Create some in the Library tab first.'),
        findsOneWidget,
      );
    });

    testWidgets('GroupsLibraryScreen: Tap and Swipe to dismiss', (
      tester,
    ) async {
      final r1 = GroupNode(id: 'r_swipe', name: 'Swipe Routine');
      await container.read(routinesProvider.notifier).saveRoutine(r1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GroupsLibraryScreen()),
        ),
      );

      // Tap
      await tester.tap(find.text('Swipe Routine'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineBuilderScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Swipe to dismiss
      await tester.drag(find.text('Swipe Routine'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.text('Swipe Routine'), findsNothing);
    });

    testWidgets('PresetsLibraryScreen: Tap and Swipe to dismiss', (
      tester,
    ) async {
      final p1 = TimerPreset(
        id: 'p_swipe',
        name: 'Swipe Preset',
        defaultDuration: 30,
      );
      await container.read(presetsProvider.notifier).savePreset(p1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PresetsLibraryScreen()),
        ),
      );

      // Tap
      await tester.tap(find.text('Swipe Preset'));
      await tester.pumpAndSettle();
      expect(find.byType(EditPresetScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Swipe to dismiss
      await tester.drag(find.text('Swipe Preset'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();
      expect(find.text('Swipe Preset'), findsNothing);
    });
  });
}
