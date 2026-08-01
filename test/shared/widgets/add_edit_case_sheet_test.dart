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
          find.byKey(const ValueKey('add-edit-case-title')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-case-remarks')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-next-date')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-notification')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('add-edit-day-offset')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-edit-step')), findsOneWidget);
        expect(find.byKey(const ValueKey('add-edit-note')), findsOneWidget);
        expect(find.byKey(const ValueKey('add-edit-save')), findsOneWidget);
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
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-edit-notification')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('add-edit-notification')));
      await tester.pump();
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });
  });
}
