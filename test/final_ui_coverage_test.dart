import 'dart:io';
import 'dart:async';
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
import 'package:interval_timer_app/ui/widgets/audio_picker_tile.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:interval_timer_app/services/audio_file_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAudioFileService implements AudioFileService {
  @override
  String getFileName(String? path) => path == null ? 'Default Beep' : 'MockFile';

  @override
  Future<String?> pickAndSaveAudio() async => 'mock/path.mp3';

  @override
  String generateUniqueFileName(String originalName) => 'unique_mock.mp3';

  @override
  Future<Directory> getSoundsDirectory() async => Directory('/tmp/mock_sounds');

  @override
  Future<String> saveToInternalStorage(File sourceFile, String name) async => '/tmp/mock_sounds/mock.mp3';
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
          backgroundServiceWrapperProvider.overrideWithValue(MockBackgroundServiceWrapper()),
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

    testWidgets('PresetsLibraryScreen: label calculation and color handling', (tester) async {
       final p1 = TimerPreset(id: '1', name: 'Short', defaultDuration: 30, color: '#FF0000');
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

    testWidgets('PresetsLibraryScreen: Tap FAB, then delete explicitly', (tester) async {
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

    testWidgets('RoutineBuilderScreen: Delete Routine from builder sheet', (tester) async {
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
  });
}
