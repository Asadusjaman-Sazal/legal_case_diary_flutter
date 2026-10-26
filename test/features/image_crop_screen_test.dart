/// The crop step for the profile picture and the firm logo.
///
/// The important promise is the mapping: the rectangle returned is the part of
/// the source visible inside the shape on screen, so the image the app stores is
/// the area the user chose — square for the profile, 148:100 for the logo.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/avatar_image_processor.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/image_crop_screen.dart';

/// A smooth 200 x 100 source; its 2:1 shape is not either crop's shape, so the
/// test can tell a real selection from a full-image pass-through.
CropSource _source() {
  final image = img.Image(width: 200, height: 100);
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 200; x++) {
      image.setPixel(x, y, img.ColorRgb8(x, y * 2, 128));
    }
  }
  // Made synchronously: `Isolate.run` does not complete inside a widget test's
  // fake clock, and this screen only needs the bytes and their size.
  return CropSource(
    bytes: img.encodeJpg(image),
    width: 200,
    height: 100,
  );
}

void main() {
  late AppLocalizations l;

  Future<CropSelection?> openCrop(
    WidgetTester tester, {
    required CropSource source,
    required double aspectRatio,
    required bool circular,
    required bool confirm,
  }) async {
    CropSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<CropSelection>(
                  MaterialPageRoute(
                    builder: (_) => ImageCropScreen(
                      source: source,
                      aspectRatio: aspectRatio,
                      circular: circular,
                      title: l.imageCrop_title,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    // The engine's image decode is real asynchronous work; let it run outside
    // the fake clock, then settle onto the loaded crop page.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text(l.imageCrop_title), findsOneWidget);

    if (confirm) {
      await tester.tap(find.text(l.imageCrop_use));
    } else {
      await tester.tap(find.byIcon(Icons.close));
    }
    await tester.pumpAndSettle();
    return result;
  }

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('a square profile crop takes the centred square of a 2:1 image', (
    tester,
  ) async {
    final source = _source();

    final result = await openCrop(
      tester,
      source: source,
      aspectRatio: 1,
      circular: true,
      confirm: true,
    );

    expect(result, isNotNull);
    final selection = result;
    if (selection == null) fail('the crop returned no selection');
    // 200 x 100 in a square viewport: the full height and the centre half of
    // the width, i.e. x 50..150.
    expect(selection.rect.height, inInclusiveRange(99, 100));
    expect(selection.rect.width, inInclusiveRange(99, 100));
    expect(selection.rect.x, inInclusiveRange(49, 51));
    expect(selection.rect.y, inInclusiveRange(0, 1));
  });

  testWidgets('the logo crop takes the 148:100 band of the same image', (
    tester,
  ) async {
    final source = _source();

    final result = await openCrop(
      tester,
      source: source,
      aspectRatio: 148 / 100,
      circular: false,
      confirm: true,
    );

    expect(result, isNotNull);
    final selection = result;
    if (selection == null) fail('the crop returned no selection');
    // The visible area is 1.48:1, so a full-height band 148 px wide.
    expect(selection.rect.height, inInclusiveRange(99, 100));
    expect(selection.rect.width, inInclusiveRange(147, 148));
    expect(selection.rect.x, inInclusiveRange(25, 27));
    expect(
      selection.rect.width / selection.rect.height,
      closeTo(148 / 100, 0.02),
    );
  });

  testWidgets('cancel returns nothing', (tester) async {
    final source = _source();

    final result = await openCrop(
      tester,
      source: source,
      aspectRatio: 1,
      circular: true,
      confirm: false,
    );

    expect(result, isNull);
  });

  testWidgets('a pinch changes the selected area', (tester) async {
    final source = _source();

    // Open and settle on the crop page, then pinch inwards by 50%.
    CropSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<CropSelection>(
                  MaterialPageRoute(
                    builder: (_) => ImageCropScreen(
                      source: source,
                      aspectRatio: 1,
                      circular: true,
                      title: l.imageCrop_title,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    final crop = find.byKey(const ValueKey('image-crop-canvas'));
    final centre = tester.getCenter(crop);
    // Two pointers moving apart: 40 px apart becomes 80, a 2x zoom in.
    final first = await tester.startGesture(centre - const Offset(20, 0));
    final second = await tester.startGesture(centre + const Offset(20, 0));
    await first.moveTo(centre - const Offset(40, 0));
    await second.moveTo(centre + const Offset(40, 0));
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.imageCrop_use));
    await tester.pumpAndSettle();

    // Zooming in shows less of the source than the initial 100 px square.
    expect(result, isNotNull);
    final selection = result;
    if (selection == null) fail('the crop returned no selection');
    expect(math.max(selection.rect.width, selection.rect.height), lessThan(100));
  });
}
