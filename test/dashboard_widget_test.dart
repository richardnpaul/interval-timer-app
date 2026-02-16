
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/ui/dashboard_screen.dart';
import 'package:interval_timer_app/services/audio_service.dart';
import 'package:interval_timer_app/providers/timer_providers.dart';
import 'package:interval_timer_app/models/active_timer.dart';
import 'package:interval_timer_app/models/timer_preset.dart';
import 'package:permission_handler/permission_handler.dart';

class MockBackgroundServiceWrapper extends BackgroundServiceWrapper {
  final StreamController<Map<String, dynamic>?> _controller = StreamController.broadcast();
  @override
  Stream<Map<String, dynamic>?> on(String method) => _controller.stream;
  @override
  void invoke(String method, [Map<String, dynamic>? args]) {}
}

class MockPermissionService extends PermissionService {
  @override
  Future<PermissionStatus> requestNotificationPermission() async => PermissionStatus.granted;
}

class MockSettingsService extends SettingsService {
  @override
  Future<bool> isWakelockEnabled() async => false;
  @override
  Future<void> setWakelock(bool enabled) async {}
}

class MockAudioService extends AudioService {
  @override
  Future<void> playAlarm(String? customPath) async {
    // No-op
  }
}

void main() {
  late MockBackgroundServiceWrapper mockService;
  late MockPermissionService mockPermission;
  late MockSettingsService mockSettings;
  late MockAudioService mockAudio;

  setUp(() {
    mockService = MockBackgroundServiceWrapper();
    mockPermission = MockPermissionService();
    mockSettings = MockSettingsService();
    mockAudio = MockAudioService();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        backgroundServiceWrapperProvider.overrideWithValue(mockService),
        permissionServiceProvider.overrideWithValue(mockPermission),
        settingsServiceProvider.overrideWithValue(mockSettings),
        audioServiceProvider.overrideWithValue(mockAudio),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  testWidgets('Dashboard should show empty state when no timers are running', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.text('No timers running'), findsOneWidget);
    expect(find.text('Tap + to start a timer'), findsOneWidget);
  });

  testWidgets('Dashboard should show ActiveTimerCard when a timer is added', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // Initial check
    expect(find.byType(Card), findsNothing);

    // Add a timer manually via the notifier
    final container = ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    container.read(activeTimersProvider.notifier).addTimer(
      TimerPreset(label: 'Workout', durationSeconds: 60),
    );

    await tester.pump();

    expect(find.text('Workout'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('Should be able to add a new timer via EditTimerScreen', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    // 1. Tap the Add button
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // 2. Verify we are on EditTimerScreen
    expect(find.text('New Timer'), findsAtLeast(1));

    // 3. Enter a label
    await tester.enterText(find.byType(TextField), 'Yoga');

    // 4. Tap the save (check) button
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('Settings: Toggle Screen Awake should work', (WidgetTester tester) async {
    final mockSettings = MockSettingsService();
    // Re-setup with local mock to avoid setUp overlap if needed, though buildTestWidget uses current mock.

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundServiceWrapperProvider.overrideWithValue(MockBackgroundServiceWrapper()),
          permissionServiceProvider.overrideWithValue(MockPermissionService()),
          settingsServiceProvider.overrideWithValue(mockSettings),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();

    final sunIcon = find.byIcon(Icons.wb_sunny_outlined);
    expect(sunIcon, findsOneWidget);

    await tester.tap(sunIcon);
    await tester.pump();

    // Verify sun icon changed (it's orange/Icons.wb_sunny when active)
    expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
  });
}
