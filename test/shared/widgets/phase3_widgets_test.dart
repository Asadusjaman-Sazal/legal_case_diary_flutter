import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
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
            alignStatusLabelRight: true,
            step: 'Warrant issued',
            note: 'Submit Process',
            onPhone: () => phonePressed = true,
            onMessage: () => messagePressed = true,
            onUpdate: () => updatePressed = true,
          ),
        ),
      );

      expect(find.text('CR-1254/2023'), findsOneWidget);
      expect(find.text('Abdur Rahim vs State'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Abdur Rahim vs State')).style?.fontSize,
        15,
      );
      expect(find.text('Warrant issued'), findsOneWidget);
      expect(find.text('Submit Process'), findsOneWidget);
      expect(find.byTooltip('Phone'), findsOneWidget);
      expect(find.byTooltip('Message'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(
        tester.getSize(find.byTooltip('Phone')).height,
        tester.getSize(find.byTooltip('Message')).height,
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        tester.getSize(find.byTooltip('Phone')).height,
      );
      final cardRect = tester.getRect(find.byType(CaseCard));
      final statusRect = tester.getRect(
        find.byKey(const ValueKey('case-card-status-label')),
      );
      expect(
        statusRect.right,
        closeTo(cardRect.right - AppSpacing.cardPadding - 1, 0.1),
      );

      await tester.tap(find.byTooltip('Phone'));
      await tester.tap(find.byTooltip('Message'));
      await tester.tap(find.text('Update'));

      expect(phonePressed, isTrue);
      expect(messagePressed, isTrue);
      expect(updatePressed, isTrue);
    });

    testWidgets('gives party names the full card content width', (
      WidgetTester tester,
    ) async {
      const partyTitle = 'Karim Ali & Ors Vs Abdul Hamid';

      await tester.pumpWidget(
        _localizedApp(
          const SizedBox(
            width: 360,
            child: CaseCard(
              caseNumber: 'WP/10425/2023',
              title: partyTitle,
              statusLabel: 'Petitioner',
              alignStatusLabelRight: true,
              showPhoneButton: false,
              showMessageButton: false,
              showUpdateButton: false,
            ),
          ),
        ),
      );

      final cardRect = tester.getRect(find.byType(CaseCard));
      final titleRect = tester.getRect(find.text(partyTitle));
      final statusRect = tester.getRect(
        find.byKey(const ValueKey('case-card-status-label')),
      );
      expect(
        titleRect.width,
        closeTo(cardRect.width - 2 - (AppSpacing.cardPadding * 2), 0.1),
      );
      expect(titleRect.top, greaterThan(statusRect.bottom));
    });

    testWidgets('keeps contact actions visible without a phone number', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _localizedApp(
          const CaseCard(caseNumber: 'CR-11/2024', title: 'No contact matter'),
        ),
      );

      expect(find.byTooltip('Phone'), findsOneWidget);
      expect(find.byTooltip('Message'), findsOneWidget);
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
            note: 'actual note.',
          ),
        ),
      );

      expect(find.text('Next Date'), findsOneWidget);
      expect(find.text('15/08/2024'), findsOneWidget);
      expect(find.text('Step'), findsOneWidget);
      expect(find.text('Hearing'), findsOneWidget);
      expect(find.text('Note: actual note.'), findsOneWidget);

      await tester.pumpWidget(
        _localizedApp(
          const CaseCard(
            variant: CaseCardVariant.list,
            caseNumber: 'CR-10/2024',
            title: 'Regular matter',
            nextDate: '15/08/2024',
            step: 'Hearing',
            note: '   ',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('case-card-note')), findsNothing);

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

    testWidgets(
      'single-select picker keeps search unfocused and closes from X',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _localizedApp(
            CustomDropdown<String>(
              label: 'Court Name',
              fieldKey: const ValueKey('single-dialog-field'),
              items: const ['District Court', 'High Court'],
              itemLabel: (item) => item,
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('single-dialog-field')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('custom-dropdown-dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('custom-dropdown-title')),
          findsOneWidget,
        );
        final titleBar = tester.widget<Container>(
          find.byKey(const ValueKey('custom-dropdown-title-bar')),
        );
        expect(titleBar.color, Colors.black);
        expect(
          find.byKey(const ValueKey('custom-dropdown-search')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('custom-dropdown-search')))
              .height,
          48,
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('custom-dropdown-search')),
              )
              .autofocus,
          isFalse,
        );
        expect(
          find.byKey(const ValueKey('custom-dropdown-close')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.clear), findsNothing);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('custom-dropdown-close-action')),
              )
              .height,
          60,
        );

        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        final dialogShape = dialog.shape! as RoundedRectangleBorder;
        expect(dialogShape.borderRadius, BorderRadius.circular(4));
        final dialogSize = tester.getSize(
          find.byKey(const ValueKey('custom-dropdown-dialog')),
        );
        final hostWidth = tester.getSize(find.byType(Scaffold)).width;
        expect(dialogSize.width, closeTo(hostWidth * .92, 0.1));
        final titleBarRect = tester.getRect(
          find.byKey(const ValueKey('custom-dropdown-title-bar')),
        );
        final searchRect = tester.getRect(
          find.byKey(const ValueKey('custom-dropdown-search')),
        );
        expect(searchRect.top, greaterThan(titleBarRect.bottom));
        final closeRect = tester.getRect(
          find.byKey(const ValueKey('custom-dropdown-close')),
        );
        expect(closeRect.top, closeTo(titleBarRect.top, 8));

        await tester.tap(find.byKey(const ValueKey('custom-dropdown-close')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('custom-dropdown-dialog')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'multi-select stays open, clears, and confirms selected values',
      (WidgetTester tester) async {
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
        await tester.tap(find.text('Filed').first);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('custom-dropdown-dialog')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('custom-dropdown-selected-values')),
            matching: find.text('Filed'),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('custom-dropdown-selected-values')),
              )
              .height,
          56,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('custom-dropdown-clear')))
              .height,
          60,
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('custom-dropdown-done')))
              .height,
          60,
        );
        final clearRect = tester.getRect(
          find.byKey(const ValueKey('custom-dropdown-clear')),
        );
        final doneRect = tester.getRect(
          find.byKey(const ValueKey('custom-dropdown-done')),
        );
        expect(clearRect.width, closeTo(doneRect.width, 0.1));
        expect(doneRect.left - clearRect.right, 16);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('custom-dropdown-selected-values')),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('custom-dropdown-clear')));
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('custom-dropdown-selected-values')),
            matching: find.text('—'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Filed').first);
        await tester.tap(find.text('Hearing').first);
        await tester.tap(find.byKey(const ValueKey('custom-dropdown-done')));
        await tester.pumpAndSettle();

        expect(selected, ['Filed', 'Hearing']);
        expect(
          find.byKey(const ValueKey('custom-dropdown-dialog')),
          findsNothing,
        );
      },
    );
  });

  group('plainDatePickerInitialDate', () {
    test('returns date-only today by default', () {
      final initial = plainDatePickerInitialDate(DateTime(2026, 7, 31, 14, 35));

      expect(initial, DateTime(2026, 7, 31));
    });
  });
}
