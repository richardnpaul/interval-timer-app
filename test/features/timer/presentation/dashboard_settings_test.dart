import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:interval_timer_app/features/timer/presentation/dashboard_screen.dart';
import 'package:interval_timer_app/core/providers/service_providers.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:interval_timer_app/core/services/storage_service.dart';

@GenerateNiceMocks([MockSpec<PermissionService>()])
import 'dashboard_settings_test.mocks.dart';

void main() {
  late MockPermissionService mockPermissionService;

  setUp(() {
    mockPermissionService = MockPermissionService();
  });

  testWidgets(
    'DashboardScreen has a settings icon that navigates to SettingsScreen',
    (WidgetTester tester) async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
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

      // Act & Assert
      // Check if settings icon exists in AppBar
      final settingsIcon = find.byIcon(Icons.settings);
      expect(
        settingsIcon,
        findsOneWidget,
        reason: 'Settings icon should be present in AppBar',
      );

      await tester.tap(settingsIcon);
      await tester.pumpAndSettle();

      // Verify navigation (SettingsScreen should be shown)
      // This will fail because SettingsScreen doesn't exist and the icon probably isn't there yet.
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
