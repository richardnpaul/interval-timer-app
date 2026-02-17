import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/ui/groups_library_screen.dart';
import 'package:interval_timer_app/ui/dashboard_screen.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/models/timer_group.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:interval_timer_app/services/storage_service.dart';
import 'package:interval_timer_app/services/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'groups_widget_test.mocks.dart';

class MockBackgroundServiceWrapper extends BackgroundServiceWrapper {
  final StreamController<Map<String, dynamic>?> _controller =
      StreamController.broadcast();
  @override
  Stream<Map<String, dynamic>?> on(String method) => _controller.stream;
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}
}

class MockPermissionService extends PermissionService {
  @override
  Future<PermissionStatus> requestNotificationPermission() async =>
      PermissionStatus.granted;
}

class MockSettingsService extends SettingsService {
  @override
  Future<bool> isWakelockEnabled() async => false;
  @override
  Future<void> setWakelock(bool enabled) async {}
}

class MockAudioService extends AudioService {
  @override
  Future<void> playAlarm(String? customPath) async {}
}

@GenerateMocks([StorageService])
void main() {
  late MockStorageService mockStorage;
  late MockBackgroundServiceWrapper mockService;
  late MockPermissionService mockPermission;
  late MockSettingsService mockSettings;
  late MockAudioService mockAudio;

  setUp(() {
    mockStorage = MockStorageService();
    mockService = MockBackgroundServiceWrapper();
    mockPermission = MockPermissionService();
    mockSettings = MockSettingsService();
    mockAudio = MockAudioService();

    when(mockStorage.loadGroups()).thenReturn([]);
    when(mockStorage.loadPresets()).thenReturn([]);
  });

  Widget buildTestWidget(Widget home) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        backgroundServiceWrapperProvider.overrideWithValue(mockService),
        permissionServiceProvider.overrideWithValue(mockPermission),
        settingsServiceProvider.overrideWithValue(mockSettings),
        audioServiceProvider.overrideWithValue(mockAudio),
      ],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
    );
  }

  testWidgets('GroupsLibraryScreen should show empty state when no groups', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget(const GroupsLibraryScreen()));
    await tester.pump();

    expect(find.text('No saved groups'), findsOneWidget);
  });

  testWidgets('GroupsLibraryScreen should show list of groups', (
    WidgetTester tester,
  ) async {
    final group = TimerGroup(id: 'g1', label: 'Workout', timerIds: ['p1']);
    when(mockStorage.loadGroups()).thenReturn([group]);

    await tester.pumpWidget(buildTestWidget(const GroupsLibraryScreen()));
    await tester.pump();

    expect(find.text('Workout'), findsOneWidget);
  });

  testWidgets('Should be able to add a new group via EditGroupScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final preset = TimerPreset(id: 'p1', label: 'Yoga', durationSeconds: 60);
    when(mockStorage.loadPresets()).thenReturn([preset]);
    when(mockStorage.loadGroups()).thenReturn([]);

    await tester.pumpWidget(buildTestWidget(const GroupsLibraryScreen()));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.text('New Group'), findsOneWidget);

    // 3. Enter a label
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'Flexibility');
    await tester.pumpAndSettle();

    // 4. Select the preset
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    // 5. Tap the save (check) button
    final checkButton = find.byIcon(Icons.check);
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    expect(find.text('Flexibility'), findsOneWidget);
    verify(mockStorage.saveGroups(any)).called(1);
  });

  testWidgets('Starting a group should add all timers to Active list', (
    WidgetTester tester,
  ) async {
    final p1 = TimerPreset(id: 'p1', label: 'Yoga', durationSeconds: 60);
    final group = TimerGroup(id: 'g1', label: 'Workout', timerIds: ['p1']);

    when(mockStorage.loadPresets()).thenReturn([p1]);
    when(mockStorage.loadGroups()).thenReturn([group]);

    await tester.pumpWidget(buildTestWidget(const DashboardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.group_work));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsOneWidget);
  });
}
