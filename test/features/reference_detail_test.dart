/// The read-only Case Reference detail, shared by the user's library and the
/// Server-wide page: its Case-Detail-style layout, the absent fields' em dash,
/// the Edit action and the read-only variant.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/case_reference/presentation/reference_detail_screen.dart';
import 'package:legal_case_diary/features/case_reference/presentation/reference_library.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// One server row with every field filled.
  ReferenceRow fullRow({String citation = '29 DLR (AD) 69'}) =>
      ReferenceRow.admin(
        id: 'r1',
        referenceAndPageNo: citation,
        parties: 'State v. Karim',
        statute: 'The Penal Code, 1860',
        sectionOrArticle: 'Section 54',
        caseNote: 'Witness turned hostile.',
        titleAndDescription: 'Bail guidelines.',
        commentsNotes: 'Call the client before the hearing.',
        tags: 'bail, evidence',
      );

  Future<void> pumpDetail(
    WidgetTester tester,
    ReferenceRow row, {
    Future<ReferenceRow?> Function(ReferenceRow currentRow)? onEdit,
    Future<bool> Function(BuildContext context)? onDelete,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(const Locale('en')),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ReferenceDetailScreen(
          row: row,
          onEdit: onEdit,
          onDelete: onDelete,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every field in the case-detail layout', (tester) async {
    await pumpDetail(
      tester,
      fullRow(),
      onEdit: (_) async => null,
      onDelete: (_) async => false,
    );

    final citation = tester.widget<Text>(
      find.byKey(const ValueKey('reference-detail-citation')),
    );
    expect(citation.data, '29 DLR (AD) 69');
    expect(citation.style?.fontSize, 24);
    expect(citation.style?.fontWeight, FontWeight.w600);
    expect(find.text('Official'), findsOneWidget);
    expect(find.text('The Penal Code, 1860'), findsOneWidget);

    // The Parties card.
    expect(
      find.byKey(const ValueKey('reference-detail-parties')),
      findsOneWidget,
    );
    expect(find.text(l.caseReferenceScreen_parties), findsOneWidget);
    expect(find.text('State v. Karim'), findsOneWidget);

    // The details card and all five labelled fields.
    final details = tester.widget<Container>(
      find.byKey(const ValueKey('reference-detail-details')),
    );
    final decoration = details.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surfaceContainerLowest);
    expect((decoration.border! as Border).top.color, AppColors.cardBorder);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AppSpacing.sheetRadius),
    );
    expect(find.text(l.caseReferenceDetail_details), findsOneWidget);
    for (final label in <String>[
      l.caseReferenceScreen_sectionOrArticle,
      l.caseReferenceScreen_caseNote,
      l.caseReferenceScreen_titleAndDescription,
      l.caseReferenceScreen_commentsNotes,
      l.caseReferenceScreen_tags,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Section 54'), findsOneWidget);
    expect(find.text('Witness turned hostile.'), findsOneWidget);
    expect(find.text('Bail guidelines.'), findsOneWidget);
    expect(find.text('Call the client before the hearing.'), findsOneWidget);
    expect(find.text('bail'), findsOneWidget);
    expect(find.text('evidence'), findsOneWidget);

    // Delete / Edit / Close sit under the Act/Law, packed from the left, with
    // no back button.
    final law = tester.getRect(
      find.byKey(const ValueKey('reference-detail-law')),
    );
    final delete = tester.getRect(
      find.byKey(const ValueKey('reference-detail-delete')),
    );
    final edit = tester.getRect(
      find.byKey(const ValueKey('reference-detail-edit')),
    );
    final close = tester.getRect(
      find.byKey(const ValueKey('reference-detail-close')),
    );
    expect(delete.top, greaterThan(law.bottom));
    expect((delete.top - edit.top).abs(), lessThan(0.5));
    expect((delete.top - close.top).abs(), lessThan(0.5));
    expect(delete.left, lessThan(edit.left));
    expect(edit.left, lessThan(close.left));
    expect(delete.left, AppSpacing.md);
    expect(delete.size, const Size(40, 40));
    expect(find.byKey(const ValueKey('reference-detail-back')), findsNothing);
  });

  testWidgets('hides Edit and shows an em dash for absent fields', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      ReferenceRow.admin(id: 'r2', referenceAndPageNo: '12 BLC 99'),
      onEdit: null,
    );

    expect(find.byKey(const ValueKey('reference-detail-edit')), findsNothing);
    expect(find.byKey(const ValueKey('reference-detail-delete')), findsNothing);
    // Close is the only remaining action, and it takes the row's left edge.
    final close = tester.getRect(
      find.byKey(const ValueKey('reference-detail-close')),
    );
    expect(close.left, AppSpacing.md);
    expect(
      find.byKey(const ValueKey('reference-detail-parties')),
      findsNothing,
    );
    // The Act/Law line and the five empty fields all read as an em dash.
    expect(find.text('—'), findsNWidgets(6));
  });

  testWidgets('Edit hands over the current row and shows the saved one', (
    tester,
  ) async {
    ReferenceRow? handed;
    await pumpDetail(
      tester,
      fullRow(),
      onEdit: (current) async {
        handed = current;
        return fullRow(citation: '29 DLR (AD) 70');
      },
    );

    await tester.tap(find.byKey(const ValueKey('reference-detail-edit')));
    await tester.pumpAndSettle();

    expect(handed?.referenceAndPageNo, '29 DLR (AD) 69');
    expect(find.text('29 DLR (AD) 70'), findsOneWidget);
  });

  testWidgets('a cancelled edit leaves the detail unchanged', (tester) async {
    var calls = 0;
    await pumpDetail(
      tester,
      fullRow(),
      onEdit: (_) async {
        calls++;
        return null;
      },
    );

    await tester.tap(find.byKey(const ValueKey('reference-detail-edit')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.text('29 DLR (AD) 69'), findsOneWidget);
  });

  testWidgets('Close returns to the screen that opened the detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(const Locale('en')),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-detail'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ReferenceDetailScreen(row: fullRow(), onEdit: null),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('reference-detail-citation')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('reference-detail-close')));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reference-detail-citation')),
      findsNothing,
    );
  });

  testWidgets('a cancelled Delete keeps the detail open', (tester) async {
    await pumpDetail(tester, fullRow(), onDelete: (_) async => false);

    await tester.tap(find.byKey(const ValueKey('reference-detail-delete')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reference-detail-citation')),
      findsOneWidget,
    );
  });

  testWidgets('Delete closes the detail once the host deleted the row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(const Locale('en')),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-detail'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReferenceDetailScreen(
                      row: fullRow(),
                      onDelete: (_) async => true,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-detail')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reference-detail-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reference-detail-citation')),
      findsNothing,
    );
  });
}
