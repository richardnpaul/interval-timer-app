import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:interval_timer_app/features/settings/presentation/settings_screen.dart';
import 'package:interval_timer_app/features/settings/application/settings_notifier.dart';
import 'package:interval_timer_app/features/settings/domain/settings_domain.dart';

@GenerateMocks([SettingsRepository])
import 'settings_screen_test.mocks.dart';

void main() {
  group('SettingsScreen', () {
    late MockSettingsRepository mockRepo;

    setUp(() {
      mockRepo = MockSettingsRepository();
    });

    Future<void> pumpSettingsScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsRepositoryProvider.overrideWithValue(mockRepo)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
    }

    testWidgets('displays toggle switches and reflects state', (
      WidgetTester tester,
    ) async {
      const settings = Settings(startCueEnabled: true, endCueEnabled: false);
      when(mockRepo.loadSettings()).thenReturn(settings);

      await pumpSettingsScreen(tester);

      expect(find.text('Routine Started Audio'), findsOneWidget);
      expect(find.text('Routine Finished Audio'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // First switch (start cue) should be true
      expect(tester.widget<Switch>(switches.at(0)).value, isTrue);
      // Second switch (end cue) should be false
      expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    });

    testWidgets('toggling switches calls notifier', (
      WidgetTester tester,
    ) async {
      const settings = Settings(startCueEnabled: true, endCueEnabled: true);
      when(mockRepo.loadSettings()).thenReturn(settings);
      when(mockRepo.saveSettings(any)).thenAnswer((_) async {});

      await pumpSettingsScreen(tester);

      // Toggle start cue off
      await tester.tap(find.text('Routine Started Audio'));
      await tester.pumpAndSettle();

      verify(
        mockRepo.saveSettings(
          argThat(
            predicate<Settings>(
              (s) => s.startCueEnabled == false && s.endCueEnabled == true,
            ),
          ),
        ),
      ).called(1);

      // Toggle end cue off
      // Note: State now has startCueEnabled: false
      await tester.tap(find.text('Routine Finished Audio'));
      await tester.pumpAndSettle();

      verify(
        mockRepo.saveSettings(
          argThat(
            predicate<Settings>(
              (s) => s.startCueEnabled == false && s.endCueEnabled == false,
            ),
          ),
        ),
      ).called(1);
    });
  });
}
