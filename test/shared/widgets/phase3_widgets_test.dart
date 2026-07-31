import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/shared/widgets/case_card.dart';
import 'package:legal_case_diary/shared/widgets/custom_dropdown.dart';
import 'package:legal_case_diary/shared/widgets/date_picker_helper.dart';

Widget _localizedApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('CaseCard', () {
    testWidgets('renders daily-cause details and invokes actions', (
      WidgetTester tester,
    ) async {
      var phonePressed = false;
      var messagePressed = false;
      var updatePressed = false;

      await tester.pumpWidget(
        _localizedApp(
          CaseCard(
            variant: CaseCardVariant.dailyCauseList,
            caseNumber: 'CR-1254/2023',
            title: 'Abdur Rahim vs State',
            subtitle: 'Section 323 of Penal Code',
            statusLabel: 'Accused',
            step: 'Warrant issued',
            note: 'Submit Process',
            onPhone: () => phonePressed = true,
            onMessage: () => messagePressed = true,
            onUpdate: () => updatePressed = true,
          ),
        ),
      );

      expect(find.text('CR-1254/2023'), findsOneWidget);
      expect(find.text('Warrant issued'), findsOneWidget);
      expect(find.text('Submit Process'), findsOneWidget);
      expect(find.byTooltip('Phone'), findsOneWidget);
      expect(find.byTooltip('Message'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      await tester.tap(find.byTooltip('Phone'));
      await tester.tap(find.byTooltip('Message'));
      await tester.tap(find.text('Update'));

      expect(phonePressed, isTrue);
      expect(messagePressed, isTrue);
      expect(updatePressed, isTrue);
    });

    testWidgets('renders compact and disposed variant details', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const CaseCard(
            variant: CaseCardVariant.list,
            caseNumber: 'CR-10/2024',
            title: 'Regular matter',
            nextDate: '15/08/2024',
            step: 'Hearing',
          ),
        ),
      );

      expect(find.text('Next Date'), findsOneWidget);
      expect(find.text('15/08/2024'), findsOneWidget);
      expect(find.text('Last Step'), findsOneWidget);
      expect(find.text('Hearing'), findsOneWidget);

      await tester.pumpWidget(
        _localizedApp(
          const CaseCard(
            variant: CaseCardVariant.disposed,
            caseNumber: 'CIV-3/2020',
            title: 'Disposed matter',
            disposedDate: '01/01/2026',
            showPhoneButton: false,
            showMessageButton: false,
            showUpdateButton: false,
          ),
        ),
      );

      expect(find.text('Disposed:'), findsOneWidget);
      expect(find.text('01/01/2026'), findsOneWidget);
      expect(find.byTooltip('Phone'), findsNothing);
      expect(find.byTooltip('Message'), findsNothing);
      expect(find.text('Update'), findsNothing);
    });

    testWidgets('applies the red left border only to overdue cards', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          CaseCard(
            key: const ValueKey('overdue-card'),
            variant: CaseCardVariant.overdue,
            caseNumber: 'CR-9/2024',
            title: 'Overdue matter',
            nextDate: '15/08/2024',
          ),
        ),
      );

      final overdueStrip = tester.widget<Container>(
        find.byKey(const ValueKey('case-card-overdue-strip')),
      );
      expect(overdueStrip.color, AppColors.error);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('case-card-overdue-strip')))
            .width,
        4,
      );

      await tester.pumpWidget(
        _localizedApp(
          const CaseCard(
            variant: CaseCardVariant.list,
            caseNumber: 'CR-10/2024',
            title: 'Regular matter',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('case-card-overdue-strip')),
        findsNothing,
      );
    });
  });

  group('CustomDropdown', () {
    testWidgets('searches and selects a single value', (
      WidgetTester tester,
    ) async {
      String? selected;

      await tester.pumpWidget(
        _localizedApp(
          StatefulBuilder(
            builder: (context, setState) => CustomDropdown<String>(
              hint: 'Select court',
              fieldKey: const ValueKey('single-dropdown-field'),
              items: const ['District Court', 'High Court'],
              value: selected,
              searchable: true,
              itemLabel: (item) => item,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('single-dropdown-field')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'High');
      await tester.pump();
      expect(find.text('District Court'), findsNothing);
      expect(find.text('High Court'), findsOneWidget);

      await tester.tap(find.text('High Court'));
      await tester.pumpAndSettle();
      expect(selected, 'High Court');
    });

    testWidgets('confirms a multi-select value list', (
      WidgetTester tester,
    ) async {
      List<String>? selected;

      await tester.pumpWidget(
        _localizedApp(
          CustomDropdown<String>(
            hint: 'Select steps',
            fieldKey: const ValueKey('multi-dropdown-field'),
            items: const ['Filed', 'Hearing', 'Disposed'],
            multiSelect: true,
            itemLabel: (item) => item,
            onMultiChanged: (values) => selected = values,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('multi-dropdown-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filed'));
      await tester.tap(find.text('Hearing'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(selected, ['Filed', 'Hearing']);
    });
  });

  group('plainDatePickerInitialDate', () {
    test('returns date-only today by default', () {
      final initial = plainDatePickerInitialDate(DateTime(2026, 7, 31, 14, 35));

      expect(initial, DateTime(2026, 7, 31));
    });
  });
}
