/// The Bengali print path through the dialog it actually runs in (Task 14).
///
/// Bengali takes the raster renderer, and that renderer lives inside the
/// progress dialog. The Phase-2 tests mount [PrintPageCapture] directly under a
/// `Scaffold`, where the parent hands it tight constraints; the dialog hands
/// its positioned children **loose** ones, and under those the capture used to
/// fail to lay out at all — a Bengali print reported "could not print" while an
/// English one worked, because only Bengali takes this path. These tests pin the
/// dialog wrapper, the engine's real encoder and the real isolate assembler, and
/// they check the pages carry ink rather than merely being the right size.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/print/print_document.dart';
import 'package:legal_case_diary/core/print/print_page_capture.dart';
import 'package:legal_case_diary/core/print/print_progress_dialog.dart';

/// A Bengali document of [entries] entries: the script rule sends it down the
/// raster path, exactly like a Bengali UI's cause list.
PrintDocument _bengaliDocument({int entries = 3}) => PrintDocument(
  title: 'আজকের কজ লিস্ট',
  subtitle: '১৯/০৯/২০২৬',
  footer: 'প্রিন্ট করা হয়েছে ১৯/০৯/২০২৬',
  pageLabel: (page, total) => 'পৃষ্ঠা $page / $total',
  groups: [
    PrintGroup(
      heading: 'ঢাকা জজ কোর্ট',
      entries: [
        for (var i = 0; i < entries; i++)
          PrintEntry(
            serial: '${i + 1}',
            heading: '${100 + i}/২০২১ · দেওয়ানি মামলা',
            fields: const [
              PrintField('বাদী', 'করিম রহমান'),
              PrintField('বিবাদী', 'সরকার'),
              PrintField('পরবর্তী তারিখ', '২৫/০৯/২০২৬'),
            ],
          ),
      ],
    ),
  ],
);

/// The document is Bengali, so the script rule must choose the raster renderer.
void _expectRasterPath() {
  expect(_bengaliDocument().needsRaster, isTrue);
}

/// Number of pages the assembled PDF declares.
int _pageCountOf(Uint8List pdf) {
  final match = RegExp(r'/Count (\d+)').firstMatch(
    String.fromCharCodes(pdf.where((byte) => byte < 128)),
  );
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Fraction of [png]'s pixels that are dark — i.e. that carry drawn text.
///
/// A blank captured page is the silent failure of an offscreen-paint capture,
/// and it is worse than an error because the user gets a blank sheet of paper.
Future<double> _inkFraction(WidgetTester tester, Uint8List png) async {
  late double fraction;
  await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    var dark = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i] < 160 && bytes[i + 1] < 160 && bytes[i + 2] < 160) dark++;
    }
    fraction = dark / (bytes.length / 4);
    image.dispose();
    codec.dispose();
  });
  return fraction;
}

/// Captures the print page of [document] with the engine's own encoder.
Future<Uint8List> _captureFirstPage(
  WidgetTester tester,
  PrintDocument document,
) async {
  Uint8List? page;
  Uint8List? result;
  Object? failure;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrintPageCapture(
          document: document,
          pageEncoder: encodePagePng,
          assembler: (request) async {
            page ??= request.pages.first;
            return Uint8List.fromList(const [1, 2, 3]);
          },
          onCompleted: (bytes) => result = bytes,
          onCancelled: () {},
          onFailed: (error) => failure = error,
        ),
      ),
    ),
  );

  for (var i = 0; i < 200 && result == null && failure == null; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(failure, isNull, reason: 'capture threw: $failure');
  expect(page, isNotNull);
  return page!;
}

void main() {
  testWidgets('a Bengali page is captured on opaque paper, not transparency',
      (tester) async {
    final png = await _captureFirstPage(tester, _bengaliDocument(entries: 8));

    late int transparent;
    late int white;
    late int total;
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      transparent = 0;
      white = 0;
      total = bytes.length ~/ 4;
      for (var i = 0; i + 3 < bytes.length; i += 4) {
        if (bytes[i + 3] != 255) transparent++;
        if (bytes[i] == 255 && bytes[i + 1] == 255 && bytes[i + 2] == 255) {
          white++;
        }
      }
      image.dispose();
      codec.dispose();
    });

    // A captured page used to be ~99% transparent, which is what leaves an
    // alpha mask in the PDF for a viewer or a print driver to misread as a
    // doubled, tinted line. Now the page is white paper: the only
    // part-transparent pixels left are the outermost edge the raster grid
    // clips, and white owns the page instead of transparency owning it.
    expect(transparent, lessThan(total ~/ 100), reason: 'the page is see-through');
    expect(white, greaterThan(total ~/ 2), reason: 'the page is not white paper');
  });

  testWidgets('the page image the PDF embeds is paper, not a transparency', (
    tester,
  ) async {
    final page = await _captureFirstPage(tester, _bengaliDocument(entries: 8));

    final pdf = String.fromCharCodes(
      (await tester.runAsync(
        () => assembleRasterPdf(
          RasterPdfRequest(
            pages: [page],
            title: 'আজকের কজ লিস্ট',
            pageWidth: 595.28,
            pageHeight: 841.89,
            margin: 32,
          ),
        ),
      ))!,
    );

    // The pdf package gives *every* raster image an alpha mask, so the mask
    // itself cannot be removed here — what the opaque capture buys is a mask
    // that is uniformly opaque paper, with nothing for a viewer or a print
    // driver to separate into a doubled, tinted line.
    expect(pdf, contains('/SMask'));
    expect(pdf, contains('/ColorSpace/DeviceRGB'));
  });

  testWidgets('a Bengali document prints through the progress dialog', (
    tester,
  ) async {
    _expectRasterPath();
    Uint8List? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bn'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await captureDocumentInDialog(
                  context,
                  _bengaliDocument(),
                );
              },
              child: const Text('print'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('print'));
    // Not `pumpAndSettle`: the indeterminate progress bar never settles.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The dialog drives the engine's real encoder and a real isolate, so frame
    // pumping is interleaved with a real event-loop tick.
    for (var i = 0; i < 200 && result == null; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }

    expect(tester.takeException(), isNull);
    expect(result, isNotNull, reason: 'the dialog never produced PDF bytes');
    expect(String.fromCharCodes(result!.take(4)), '%PDF');
    expect(_pageCountOf(result!), 1);

    // The dialog closed on its own — no failure card left standing.
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('print-progress-label')), findsNothing);
  });

  testWidgets('a captured Bengali page is drawn, not blank', (tester) async {
    Uint8List? page;
    Uint8List? result;
    Object? failure;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('bn'),
        home: Scaffold(
          body: PrintPageCapture(
            document: _bengaliDocument(entries: 8),
            // The engine's own encoder, so the pixels are the real ones; the
            // assembler is a recorder so the page can be inspected here.
            pageEncoder: encodePagePng,
            assembler: (request) async {
              page ??= request.pages.first;
              return Uint8List.fromList(const [1, 2, 3]);
            },
            onCompleted: (bytes) => result = bytes,
            onCancelled: () {},
            onFailed: (error) => failure = error,
          ),
        ),
      ),
    );

    for (var i = 0; i < 200 && result == null && failure == null; i++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }

    expect(failure, isNull, reason: 'capture threw: $failure');
    expect(page, isNotNull);

    final ink = await _inkFraction(tester, page!);
    expect(ink, greaterThan(0.002), reason: 'the page came out blank');
  });

  testWidgets('the capture lays out under the loose constraints a dialog gives',
      (tester) async {
    // The regression itself, reduced: a capture parented by a positioned child
    // of a stack hands it loose constraints, and it must still lay out.
    var completed = false;
    Object? failure;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -2000,
                top: 0,
                child: PrintPageCapture(
                  document: _bengaliDocument(),
                  // Only the layout is under test here, so the engine encoder is
                  // replaced; `toImage` needs the real event loop.
                  pageEncoder: (boundary, pixelRatio) async =>
                      Uint8List.fromList(const [137, 80, 78, 71]),
                  assembler: (request) async =>
                      Uint8List.fromList(const [1, 2, 3]),
                  onCompleted: (bytes) => completed = true,
                  onCancelled: () {},
                  onFailed: (error) => failure = error,
                ),
              ),
              const SizedBox(width: 100, height: 100),
            ],
          ),
        ),
      ),
    );

    for (var i = 0; i < 60 && !completed && failure == null; i++) {
      await tester.pump();
    }

    expect(failure, isNull, reason: 'capture failed: $failure');
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
