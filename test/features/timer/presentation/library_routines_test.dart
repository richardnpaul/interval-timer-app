import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/timer/presentation/dashboard_screen.dart';
import 'package:interval_timer_app/core/providers/service_providers.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([MockSpec<PermissionService>()])
import 'library_routines_test.mocks.dart';

void main() {
  late MockPermissionService mockPermissionService;

  setUp(() {
    mockPermissionService = MockPermissionService();
  });

  testWidgets('Library tab (Presets) also displays saved routines', (
    WidgetTester tester,
  ) async {
    // Arrange
    SharedPreferences.setMockInitialValues({
      'timer_routines_v2':
          '[{"id": "test_routine", "name": "Test Routine", "children": [], "executionMode": "sequential", "repetitions": 1}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionServiceProvider.overrideWithValue(mockPermissionService),
          storageServiceProvider.overrideWithValue(storageService),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    // Switch to Library (Presets) tab - index 1
    await tester.tap(find.byIcon(Icons.library_books_outlined));
    await tester.pumpAndSettle();

    // Assert: Check if the routine name is visible in the Library tab
    // Currently, PresetsLibraryScreen only watches presetsProvider, not routinesProvider.
    expect(find.text('Test Routine'), findsOneWidget);
  });
}
