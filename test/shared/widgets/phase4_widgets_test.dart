import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_sub_page_modal.dart';
import 'package:legal_case_diary/shared/widgets/calendar_picker_dialog.dart';

void main() {
  group('SettingsSubPageModal', () {
    testWidgets('renders title, body, actions, and invokes back callback', (
      WidgetTester tester,
    ) async {
      var backPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsSubPageModal(
            title: 'View Settings',
            onBack: () => backPressed = true,
            actions: const [Icon(Icons.more_vert)],
            child: const Text('Settings content'),
          ),
        ),
      );

      expect(find.text('View Settings'), findsOneWidget);
      expect(find.text('Settings content'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      expect(backPressed, isTrue);
    });

    testWidgets('default back action pops the current route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsSubPageModal(
                      title: 'Profile',
                      child: Text('Profile content'),
                    ),
                  ),
                );
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Profile content'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Profile content'), findsNothing);
    });
  });

  group('CalendarPickerDialog', () {
    testWidgets('renders a dialog with a close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CalendarPickerDialog(
              initialDate: AppDateUtils.bangladeshTodayStartOfDay(),
              hearingCounts: const {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Dialog), findsOneWidget);
      final l = AppLocalizations.of(tester.element(find.byType(Dialog).first));
      expect(find.text(l.sharedActions_close), findsOneWidget);
    });
  });
}
