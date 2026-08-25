import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/pre_seeded_data.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/app_database.dart';
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
        expect(header.color, Colors.black);
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
        expect(find.byKey(const ValueKey('add-edit-case-year')), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('add-edit-case-number')),
          'Case #A/42-β — any text',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('add-edit-case-number')),
              )
              .controller
              ?.text,
          'Case #A/42-β — any text',
        );
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('add-edit-party-phone-prefix')),
              )
              .height,
          tester
              .getSize(find.byKey(const ValueKey('add-edit-party-phone')))
              .height,
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
          'A-1',
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
          find.byKey(const ValueKey('add-edit-party-phone')),
          findsOneWidget,
        );
        expect(find.text('+88'), findsOneWidget);
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
        expect(
          tester.widget<Text>(find.text('Parties')).textAlign,
          TextAlign.center,
        );
        expect(
          tester
              .widgetList<InputDecorator>(find.byType(InputDecorator))
              .any(
                (decorator) =>
                    decorator.decoration.enabledBorder is OutlineInputBorder,
              ),
          isTrue,
        );

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

    testWidgets('formats the next date as day/month/year and weekday', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          AddEditCaseSheet(
            lookupData: const AddEditCaseLookupData(),
            initialNextDate: DateTime(2026, 8, 5),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-next-date')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('05/08/26, Wed'), findsOneWidget);
      expect(find.text('Next Date'), findsOneWidget);
      expect(find.text('Pick a date'), findsNothing);
    });

    testWidgets('shows the standard six Day Offset choices', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(lookupData: AddEditCaseLookupData()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-day-offset')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('add-edit-day-offset'))),
        alignment: 0.5,
        duration: Duration.zero,
      );
      tester
          .widget<InkWell>(find.byKey(const ValueKey('add-edit-day-offset')))
          .onTap!();
      await tester.pumpAndSettle();

      expect(find.text('The same day'), findsAtLeastNWidgets(1));
      expect(find.text('The day before'), findsOneWidget);
      expect(find.text('Before 3 days'), findsOneWidget);
      expect(find.text('Before 7 days'), findsOneWidget);
      expect(find.text('Before 15 days'), findsOneWidget);
      expect(find.text('Before 30 days'), findsOneWidget);
    });

    testWidgets('restores remembered court hierarchy selections in add mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(
            lookupData: AddEditCaseLookupData(
              lastAddCaseHigherLowerCourt: lowerCourtsOption,
              lastAddCaseDivision: divisionChattogramId,
              lastAddCaseDistrict: 'feni',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lower Divisional Courts'), findsOneWidget);
      expect(find.text('Chittagong'), findsOneWidget);
      expect(find.text('Feni'), findsOneWidget);
    });

    testWidgets('ignores an invalid remembered district for its division', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const AddEditCaseSheet(
            lookupData: AddEditCaseLookupData(
              lastAddCaseHigherLowerCourt: lowerCourtsOption,
              lastAddCaseDivision: divisionDhakaId,
              lastAddCaseDistrict: 'feni',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lower Divisional Courts'), findsOneWidget);
      expect(find.text('Dhaka'), findsOneWidget);
      expect(find.text('Select an option'), findsAtLeastNWidgets(1));
    });

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

    testWidgets('shows AD/HCD fields and scopes case types by case category', (
      WidgetTester tester,
    ) async {
      const caseCategory = CaseCategory(
        id: 'ad-civil',
        courtCategoryId: appellateDivisionId,
        name: 'Civil Cases',
        orderIndex: 0,
        isCustom: false,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      );
      const court = Court(
        id: 'ad-court',
        courtName: 'Appellate Division',
        higherLowerCourts: higherCourtsOption,
        courtCategoryId: appellateDivisionId,
        orderIndex: 0,
        isCustom: false,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      );
      const caseType = CaseType(
        id: 'ad-civil-appeal',
        courtCategoryId: appellateDivisionId,
        caseCategoryId: 'ad-civil',
        name: 'Civil Appeal',
        orderIndex: 0,
        isCustom: false,
        isUserModified: false,
        updatedAt: 0,
        isDeleted: false,
      );

      await tester.pumpWidget(
        _localizedApp(
          AddEditCaseSheet(
            lookupData: const AddEditCaseLookupData(
              caseCategories: [caseCategory],
              courts: [court],
              caseTypes: [caseType],
              lastAddCaseHigherLowerCourt: appellateDivisionId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('add-edit-honorable-judges')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-edit-case-category')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-edit-tender-number')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-edit-previous-court-case')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('add-edit-district-of-origin')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('add-edit-case-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Civil Cases').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-case-type')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(
        find.byKey(const ValueKey('add-edit-form-scroll')),
        const Offset(0, 40),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-edit-case-type')));
      await tester.pumpAndSettle();
      expect(find.text('Civil Appeal'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('custom-dropdown-close')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-result')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('add-edit-result')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-edit-step')), findsNothing);
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
