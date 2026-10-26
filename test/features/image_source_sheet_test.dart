/// The Gallery / Files chooser above the picture pickers.
///
/// The system gallery cannot carry our own Files button, so this sheet supplies
/// it. The two choices must read as one kind of control: no filled button, no
/// background, the same black icon-and-text style (user request).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/image_source_sheet.dart';

void main() {
  late AppLocalizations l;

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => pickPictureBytes(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('Files is a plain black icon-and-text row, like Gallery', (
    tester,
  ) async {
    await openSheet(tester);

    final gallery = find.byKey(const ValueKey('image-source-gallery'));
    final files = find.byKey(const ValueKey('image-source-files'));
    expect(gallery, findsOneWidget);
    expect(files, findsOneWidget);

    // No button chrome around Files: it is not a TextButton (the previous
    // version was) and carries no filled background.
    expect(
      find.ancestor(of: files, matching: find.byType(TextButton)),
      findsNothing,
    );
    expect(
      find.ancestor(of: files, matching: find.byType(FilledButton)),
      findsNothing,
    );

    final galleryText = tester.widget<Text>(find.text(l.imageSource_gallery));
    final filesText = tester.widget<Text>(
      find.descendant(of: files, matching: find.text(l.imageSource_files)),
    );
    expect(galleryText.style?.color, AppColors.onSurface);
    expect(filesText.style?.color, AppColors.onSurface);
    expect(filesText.style?.fontSize, galleryText.style?.fontSize);

    final galleryIcon = tester.widget<Icon>(
      find.descendant(
        of: gallery,
        matching: find.byIcon(Icons.photo_library_outlined),
      ),
    );
    final filesIcon = tester.widget<Icon>(
      find.descendant(of: files, matching: find.byIcon(Icons.folder_open)),
    );
    expect(galleryIcon.color, AppColors.onSurface);
    expect(filesIcon.color, AppColors.onSurface);

    // The Files choice sits directly under Gallery and shares its left edge.
    final galleryRect = tester.getRect(gallery);
    final filesRect = tester.getRect(files);
    expect(filesRect.top, greaterThanOrEqualTo(galleryRect.bottom));
    expect(filesRect.left, closeTo(galleryRect.left, 0.5));

    // Dismiss without opening either picker.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });
}
