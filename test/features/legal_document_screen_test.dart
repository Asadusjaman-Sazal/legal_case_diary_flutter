/// Tests for the Privacy Policy and Terms of Service screens.
///
/// These load the real bundled assets rather than a fixture, so they also prove
/// the pubspec asset entry and the file names are right — the failure they exist
/// to catch is a document that renders as nothing, or a Bengali reader being
/// shown the English text.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/settings/presentation/legal/legal_document_screen.dart';

/// Bengali-block characters, as a proxy for "this document is really
/// translated".
///
/// The block includes the taka sign (৳, U+09F3), which the English terms use
/// for the prices, so the English check below is a low threshold rather than
/// zero: a few currency signs are not a translation.
int _bengaliCharCount(String text) =>
    text.runes.where((rune) => rune >= 0x0980 && rune <= 0x09FF).length;

void main() {
  /// The documents are long, so the surface is made tall enough that the blocks
  /// asserted on are built rather than left off-screen in the lazy list.
  ///
  /// The screen reads its document from the real asset bundle, and that is real
  /// asynchronous I/O — which never completes under the widget tester's fake
  /// clock. The pump and the load therefore happen inside `runAsync`.
  Future<void> pump(
    WidgetTester tester,
    LegalDocument document, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: LegalDocumentScreen(document: document),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  group('asset selection', () {
    test('each document picks its file from the language', () {
      expect(
        LegalDocument.privacyPolicy.assetPath(const Locale('en')),
        'docs/legal/privacy_policy_EN.md',
      );
      expect(
        LegalDocument.privacyPolicy.assetPath(const Locale('bn')),
        'docs/legal/privacy_policy_BN.md',
      );
      expect(
        LegalDocument.termsOfService.assetPath(const Locale('en')),
        'docs/legal/terms_of_service_EN.md',
      );
      expect(
        LegalDocument.termsOfService.assetPath(const Locale('bn')),
        'docs/legal/terms_of_service_BN.md',
      );
    });

    test('a language with no document falls back to English', () {
      expect(
        LegalDocument.privacyPolicy.assetPath(const Locale('fr')),
        'docs/legal/privacy_policy_EN.md',
      );
    });
  });

  group('the bundled documents', () {
    test('both languages exist for both documents', () async {
      for (final document in LegalDocument.values) {
        for (final locale in const [Locale('en'), Locale('bn')]) {
          final text = await rootBundle.loadString(document.assetPath(locale));
          expect(
            text.trim(),
            isNotEmpty,
            reason: '${document.assetPath(locale)} should not be empty',
          );
        }
      }
    });

    test('the Bengali documents are actually in Bengali', () async {
      // A file that is merely a copy of the English one would silently show
      // English to a Bengali reader, so the text itself is checked.
      for (final document in LegalDocument.values) {
        final english = await rootBundle.loadString(
          document.assetPath(const Locale('en')),
        );
        final bengali = await rootBundle.loadString(
          document.assetPath(const Locale('bn')),
        );

        expect(
          _bengaliCharCount(bengali),
          greaterThan(1000),
          reason: '${document.name} has no meaningful Bengali text',
        );
        expect(
          _bengaliCharCount(english),
          lessThan(50),
          reason: '${document.name} English file looks translated',
        );
      }
    });
  });

  group('rendering', () {
    testWidgets('shows the Privacy Policy in English', (tester) async {
      await pump(tester, LegalDocument.privacyPolicy);

      // The window title, and the document's own heading beneath it.
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(
        find.textContaining('Privacy Policy — Legal Case Diary'),
        findsOneWidget,
      );
      expect(find.textContaining('1. Summary'), findsOneWidget);
      expect(
        find.textContaining('we collect nothing about you'),
        findsOneWidget,
      );
    });

    testWidgets('shows the Terms of Service in English', (tester) async {
      await pump(tester, LegalDocument.termsOfService);

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(
        find.textContaining('Terms of Service — Legal Case Diary'),
        findsOneWidget,
      );
      expect(find.textContaining('1. Agreement'), findsOneWidget);
      // The status note is part of the document's own opening, so it is on
      // screen without scrolling the whole thing.
      expect(
        find.textContaining('paid subscriptions take effect when purchasing'),
        findsOneWidget,
      );
    });

    testWidgets('shows the Bengali documents under Locale(bn)', (tester) async {
      await pump(
        tester,
        LegalDocument.privacyPolicy,
        locale: const Locale('bn'),
      );

      expect(find.text('গোপনীয়তা নীতি'), findsOneWidget);
      expect(
        find.textContaining('গোপনীয়তা নীতি — লিগ্যাল কেস ডায়েরি'),
        findsOneWidget,
      );
      expect(find.textContaining('১. সারসংক্ষেপ'), findsOneWidget);
      // Nothing of the English copy leaks through.
      expect(find.textContaining('1. Summary'), findsNothing);
    });

    testWidgets('shows the Bengali Terms of Service under Locale(bn)', (
      tester,
    ) async {
      await pump(
        tester,
        LegalDocument.termsOfService,
        locale: const Locale('bn'),
      );
      final l = await AppLocalizations.delegate.load(const Locale('bn'));

      // The window title comes from the ARB, so it is read from there too.
      expect(find.text(l.settingsAbout_termsOfService), findsOneWidget);
      expect(find.textContaining('১. সম্মতি'), findsOneWidget);
      expect(find.textContaining('Terms of Service — Legal Case Diary'), findsNothing);
    });

    testWidgets('renders the draft markers rather than hiding them', (
      tester,
    ) async {
      // The business decisions in these drafts are shown with their markers on
      // purpose: nothing should look settled while it is not.
      await pump(tester, LegalDocument.privacyPolicy);

      expect(find.textContaining('[TO CONFIRM'), findsWidgets);
    });
  });
}
