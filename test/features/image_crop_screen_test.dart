/// The "Select Image" page for the profile picture and firm logo.
///
/// The page shows the whole image under a frame; dragging moves it, dragging a
/// corner resizes it, rotating turns the image, and Save returns the frame's
/// area in the rotated image. These pin the two shapes, the move, the resize
/// limits, the rotation, Save and Cancel.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/avatar_image_processor.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/image_crop_screen.dart';

/// A smooth 200 x 100 source; its 2:1 shape is not either frame's shape, so a
/// selection can be told from a full-image pass-through.
CropSource _source() {
  final image = img.Image(width: 200, height: 100);
  for (var y = 0; y < 100; y++) {
    for (var x = 0; x < 200; x++) {
      image.setPixel(x, y, img.ColorRgb8(x, y * 2, 128));
    }
  }
  // Made synchronously: `Isolate.run` does not complete inside a widget test's
  // fake clock, and the page only needs the bytes and their size.
  return CropSource(bytes: img.encodeJpg(image), width: 200, height: 100);
}

/// A 1600 x 1200 source, large enough that the frame can shrink to its floor.
CropSource _largeSource() {
  return CropSource(
    bytes: img.encodeJpg(img.Image(width: 1600, height: 1200)),
    width: 1600,
    height: 1200,
  );
}

void main() {
  late AppLocalizations l;

  Future<CropSelection?> openCrop(
    WidgetTester tester, {
    required CropSource source,
    required double aspectRatio,
    required bool circular,
    required bool save,
    Future<void> Function(WidgetTester tester)? gesture,
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
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text(l.imageCrop_title), findsOneWidget);

    if (gesture != null) await gesture(tester);

    if (save) {
      await tester.tap(find.byKey(const ValueKey('image-crop-save')));
    } else {
      await tester.tap(find.text(l.sharedActions_cancel));
    }
    await tester.pumpAndSettle();
    return result;
  }

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('the profile frame starts centred and square', (tester) async {
    final selection = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 1,
      circular: true,
      save: true,
    );

    expect(selection, isNotNull);
    final rect = selection!.rect;
    expect(rect.width / rect.height, closeTo(1, 0.03));
    expect(rect.x, closeTo((200 - rect.width) / 2, 3));
    expect(rect.y, closeTo((100 - rect.height) / 2, 3));
    expect(rect.width, lessThan(200));
    expect(selection.rotationQuarterTurns, 0);
  });

  testWidgets('the logo frame keeps the 148:100 ratio', (tester) async {
    final selection = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 148 / 100,
      circular: false,
      save: true,
    );

    expect(selection, isNotNull);
    final rect = selection!.rect;
    expect(rect.width / rect.height, closeTo(148 / 100, 0.03));
    expect(rect.x, closeTo((200 - rect.width) / 2, 3));
    expect(rect.y, closeTo((100 - rect.height) / 2, 3));
  });

  testWidgets('dragging moves the frame', (tester) async {
    final centred = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 1,
      circular: true,
      save: true,
    );
    final dragged = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 1,
      circular: true,
      save: true,
      gesture: (tester) async {
        await tester.drag(
          find.byKey(const ValueKey('image-crop-canvas')),
          const Offset(80, 30),
        );
        await tester.pumpAndSettle();
      },
    );

    expect(centred, isNotNull);
    expect(dragged, isNotNull);
    expect(dragged!.rect.x, greaterThan(centred!.rect.x));
    expect(dragged.rect.y, greaterThan(centred.rect.y));
  });

  testWidgets('a corner drag shrinks the frame no smaller than 512 px', (
    tester,
  ) async {
    final selection = await openCrop(
      tester,
      source: _largeSource(),
      aspectRatio: 1,
      circular: true,
      save: true,
      gesture: (tester) async {
        final handle = find.byKey(
          const ValueKey('image-crop-handle-bottomRight'),
        );
        expect(handle, findsOneWidget);
        await tester.drag(handle, const Offset(-400, -400));
        await tester.pumpAndSettle();
      },
    );

    expect(selection, isNotNull);
    // The floor is the 512 source pixels the stored picture is made from.
    expect(selection!.rect.width, closeTo(512, 2));
    expect(selection.rect.height, closeTo(512, 2));
  });

  testWidgets('a corner drag cannot pull the frame off the image', (
    tester,
  ) async {
    final selection = await openCrop(
      tester,
      source: _largeSource(),
      aspectRatio: 1,
      circular: true,
      save: true,
      gesture: (tester) async {
        // Shrink first, then drag the freed corner far past the image's edge.
        await tester.drag(
          find.byKey(const ValueKey('image-crop-handle-bottomRight')),
          const Offset(-300, -300),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const ValueKey('image-crop-handle-topLeft')),
          const Offset(-2000, -2000),
        );
        await tester.pumpAndSettle();
      },
    );

    expect(selection, isNotNull);
    final rect = selection!.rect;
    expect(rect.x, greaterThanOrEqualTo(0));
    expect(rect.y, greaterThanOrEqualTo(0));
    expect(rect.x + rect.width, lessThanOrEqualTo(1600));
    expect(rect.y + rect.height, lessThanOrEqualTo(1200));
    expect(rect.width / rect.height, closeTo(1, 0.03));
  });

  testWidgets('the logo frame resizes sideways, holding its wide ratio', (
    tester,
  ) async {
    final initial = await openCrop(
      tester,
      source: _largeSource(),
      aspectRatio: 148 / 100,
      circular: false,
      save: true,
    );
    final smaller = await openCrop(
      tester,
      source: _largeSource(),
      aspectRatio: 148 / 100,
      circular: false,
      save: true,
      gesture: (tester) async {
        // A purely sideways pull: the untouched vertical side must not pin the
        // width at its starting value (the 0.0.661 defect).
        await tester.drag(
          find.byKey(const ValueKey('image-crop-handle-bottomRight')),
          const Offset(-150, 0),
        );
        await tester.pumpAndSettle();
      },
    );

    expect(initial, isNotNull);
    expect(smaller, isNotNull);
    expect(smaller!.rect.width, lessThan(initial!.rect.width - 50));
    expect(smaller.rect.width / smaller.rect.height, closeTo(148 / 100, 0.03));
  });

  testWidgets('all four corners resize the frame', (tester) async {
    final initial = await openCrop(
      tester,
      source: _largeSource(),
      aspectRatio: 1,
      circular: true,
      save: true,
    );
    expect(initial, isNotNull);

    // Each corner pulled toward the frame's centre must shrink it.
    const pulls = <String, Offset>{
      'topLeft': Offset(120, 40),
      'topRight': Offset(-120, 40),
      'bottomLeft': Offset(120, -40),
      'bottomRight': Offset(-120, -40),
    };
    for (final entry in pulls.entries) {
      final selection = await openCrop(
        tester,
        source: _largeSource(),
        aspectRatio: 1,
        circular: true,
        save: true,
        gesture: (tester) async {
          await tester.drag(
            find.byKey(ValueKey('image-crop-handle-${entry.key}')),
            entry.value,
          );
          await tester.pumpAndSettle();
        },
      );
      expect(selection, isNotNull, reason: entry.key);
      expect(
        selection!.rect.width,
        lessThan(initial!.rect.width - 50),
        reason: entry.key,
      );
    }
  });

  testWidgets('the rotate button turns the saved image a quarter', (
    tester,
  ) async {
    final selection = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 1,
      circular: true,
      save: true,
      gesture: (tester) async {
        await tester.tap(find.byKey(const ValueKey('image-crop-rotate')));
        await tester.pumpAndSettle();
      },
    );

    expect(selection, isNotNull);
    expect(selection!.rotationQuarterTurns, 1);
    // The source is 200 x 100, so the rotated image is 100 tall by 200 wide;
    // the selected rectangle must fit that, not the original axes.
    expect(selection.rect.x + selection.rect.width, lessThanOrEqualTo(100));
    expect(selection.rect.y + selection.rect.height, lessThanOrEqualTo(200));
  });

  testWidgets('cancel returns nothing', (tester) async {
    final selection = await openCrop(
      tester,
      source: _source(),
      aspectRatio: 1,
      circular: true,
      save: false,
    );

    expect(selection, isNull);
  });
}
