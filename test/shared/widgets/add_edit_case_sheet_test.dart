import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/shared/widgets/add_edit_case_sheet.dart';

Widget _localizedApp(
  Widget child, {
  CaseWritePermissions permissions = const CaseWritePermissions(
    canAdd: true,
    canEdit: true,
  ),
}) {
  return ProviderScope(
    overrides: [
      caseWritePermissionsProvider.overrideWith((ref) async => permissions),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('AddEditCaseSheet Phase 1', () {
    testWidgets(
      'renders fields in order and hides lower-only fields initially',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _localizedApp(
            const AddEditCaseSheet(lookupData: AddEditCaseLookupData()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Case'), findsOneWidget);
        final header = tester.widget<Container>(
          find.byKey(const ValueKey('add-edit-header')),
        );
        expect(
          header.padding,
          const EdgeInsets.symmetric(horizontal: 24, vertical: 11.2),
        );
        expect(
          find.byKey(const ValueKey('add-edit-higher-lower-court')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-edit-division')), findsNothing);
        expect(find.byKey(const ValueKey('add-edit-district')), findsNothing);
        expect(
          find.byKey(const ValueKey('add-edit-court-category')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('add-edit-name-of-court')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-case-type')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-case-number')),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<InputDecorator>(find.byType(InputDecorator))
              .any(
                (decorator) => decorator.decoration.fillColor == Colors.white,
              ),
          isTrue,
        );
        await tester.enterText(
          find.byKey(const ValueKey('add-edit-case-number')),
          'A-1/2026',
        );
        await tester.pump();
        expect(
          tester
              .widgetList<InputDecorator>(find.byType(InputDecorator))
              .any(
                (decorator) =>
                    decorator.decoration.fillColor == const Color(0xFFF1F5F9),
              ),
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('add-edit-petitioner')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-petitioner-lead-counsel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-respondent')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-respondent-lead-counsel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-on-behalf')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-petitioner-phone')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-respondent-phone')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-section-court')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-section-parties')),
          findsOneWidget,
        );
        expect(find.text('Petitioner Lead Counsel'), findsOneWidget);
        expect(find.text('Respondent Lead Counsel'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;
        for (final key in [
          'add-edit-section-details',
          'add-edit-section-schedule',
          'add-edit-case-title',
          'add-edit-case-remarks',
          'add-edit-next-date',
          'add-edit-notification',
          'add-edit-day-offset',
          'add-edit-step',
          'add-edit-note',
        ]) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey(key)),
            240,
            scrollable: scrollable,
          );
          expect(find.byKey(ValueKey(key)), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('add-edit-save')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('add-edit-save'))).height,
          greaterThan(48),
        );
      },
    );

    testWidgets('selecting Lower Divisional Courts reveals the lower cascade', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(lookupData: AddEditCaseLookupData()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('add-edit-higher-lower-court')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(lowerCourtsOption)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('add-edit-division')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-edit-district')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('add-edit-court-category')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('add-edit-district')));
      await tester.pump();
      expect(
        find.text('Please select an option from Division first.'),
        findsOneWidget,
      );
    });

    testWidgets('canEdit false disables editable controls and save', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(
            lookupData: AddEditCaseLookupData(),
            canAdd: false,
            canEdit: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('add-edit-save')),
      );
      expect(saveButton.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-next-date')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<InkWell>(find.byKey(const ValueKey('add-edit-next-date')))
            .onTap,
        isNull,
      );
    });

    testWidgets('notification toggle changes its icon state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(lookupData: AddEditCaseLookupData()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-notification')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('add-edit-notification')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final enabledNotification = tester.widget<IconButton>(
        find.byKey(const ValueKey('add-edit-notification')),
      );
      expect(enabledNotification.onPressed, isNotNull);
      enabledNotification.onPressed!();
      await tester.pump();
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      final notification = tester.widget<IconButton>(
        find.byKey(const ValueKey('add-edit-notification')),
      );
      final style = notification.style!;
      expect(style.backgroundColor?.resolve({}), Colors.transparent);
      expect(style.foregroundColor?.resolve({}), Colors.black);
    });
  });
}
