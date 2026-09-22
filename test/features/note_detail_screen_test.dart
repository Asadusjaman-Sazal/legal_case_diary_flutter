/// Tests for the note editor's typography (Task 11's Note screen).
///
/// The body field is `bodyLg`; the title sits 2 px above it, which is the
/// pairing the user asked for and a deliberate departure from the mockup's
/// `headline-lg`. The two fields are therefore compared against each other
/// rather than against a literal, so the relationship survives a token change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/constants/app_typography.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/notes/presentation/note_detail_screen.dart';

void main() {
  Widget app(Widget child) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    ),
  );

  /// The editor's fields, in build order: title first, then body.
  List<TextField> fields(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).toList();

  testWidgets('the note title is 2 px bigger than the note body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const NoteDetailScreen()));
    await tester.pumpAndSettle();

    final title = fields(tester)[0];
    final body = fields(tester)[1];

    expect(title.style?.fontSize, AppTypography.bodyLg.fontSize! + 2);
    expect(body.style?.fontSize, AppTypography.bodyLg.fontSize);
    expect(title.decoration?.hintStyle?.fontSize, title.style?.fontSize);
    expect(
      title.decoration?.hintStyle?.fontFamily,
      AppTypography.titleLg.fontFamily,
    );
  });
}
