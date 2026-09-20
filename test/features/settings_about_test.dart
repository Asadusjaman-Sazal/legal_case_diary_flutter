/// Tests for the About screen and the More About the App screen (Phase 4).
///
/// Both mirror their mockups (`settings_about`, `settings_moreAboutTheApp`) and
/// show the bundled `appVersion`. About's "More About the App" row is the only
/// navigation target that exists yet; the remaining rows report their Part A
/// state through a snackbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/settings/presentation/legal/legal_document_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/more_about_app_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/more_about_the_app_screen.dart';

import 'settings_test_support.dart';

void main() {
  /// Pumps the About route with a tall surface: both screens are long, and
  /// `MaterialApp` viewports build lazily, so a phone-sized viewport would hide
  /// the rows a test taps.
  Future<void> pumpAbout(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsAbout,
      locale: locale,
      routes: [
        GoRoute(
          path: AppRoutes.settingsAbout,
          builder: (context, state) => const MoreAboutAppScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsMoreAbout,
          builder: (context, state) => const MoreAboutTheAppScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsPrivacyPolicy,
          builder: (context, state) =>
              const LegalDocumentScreen(document: LegalDocument.privacyPolicy),
        ),
        GoRoute(
          path: AppRoutes.settingsTermsOfService,
          builder: (context, state) =>
              const LegalDocumentScreen(document: LegalDocument.termsOfService),
        ),
      ],
    );
  }

  testWidgets('shows the bundled app logo in the placeholder gavel frame', (
    tester,
  ) async {
    await pumpAbout(tester);

    // The placeholder gavel chip is gone...
    expect(find.byIcon(Icons.gavel), findsNothing);

    final logo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/icons/app_logo.png',
    );
    // ...replaced by the bundled logo...
    expect(logo, findsOneWidget);
    // ...in the same 64 × 64 frame the placeholder occupied.
    expect(tester.getSize(logo), const Size(64, 64));

    // The asset is really bundled (declared under `assets:` in pubspec.yaml),
    // so the image loads instead of falling back to the gavel.
    final bytes = await rootBundle.load('assets/icons/app_logo.png');
    expect(bytes.lengthInBytes, greaterThan(0));

    // The frame is white like the card behind it, so the logo's transparent
    // side margins blend in rather than showing as dark bands.
    final frame = tester.widget<Container>(
      find.ancestor(of: logo, matching: find.byType(Container)).first,
    );
    expect(
      (frame.decoration as BoxDecoration).color,
      AppColors.surfaceContainerLowest,
    );
  });

  testWidgets('shows the app identity, bundled version and developer card', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Legal Case Diary'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
    expect(find.text('DESIGNED & DEVELOPED BY'), findsOneWidget);
    expect(find.text('Asadusjaman Sazal'), findsOneWidget);
    expect(find.text('ADVOCATE'), findsOneWidget);
    expect(
      find.text('District & Sessions Judge Court, Narayanganj.'),
      findsOneWidget,
    );
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('adv.asadusjaman@gmail.com'), findsOneWidget);
    expect(find.text('WHATSAPP'), findsOneWidget);
    expect(find.text('+8801835252721'), findsOneWidget);

    // The mockup's remote photo is replaced by the bundled asset.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/dev_profile.jpg',
      ),
      findsOneWidget,
    );
  });

  testWidgets('lists the app-info rows and the data-safety note', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.text('More About the App'), findsOneWidget);
    // The FAQs are reached from their own settings row, so About has no FAQ row.
    expect(find.text('FAQ'), findsNothing);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('DATA SAFETY'), findsOneWidget);
    expect(
      find.text(
        'Your diary and your backup files are stored on your device in '
        'encrypted form. Nothing is uploaded unless you send it.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('© 2025 ASADUSJAMAN SAZAL'), findsOneWidget);
  });

  testWidgets('opens More About the App from its row', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    // The pushed screen replaces the visible route.
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('KEY FEATURES'), findsOneWidget);
  });

  testWidgets('rows without a screen report their Part A state', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();

    expect(find.text('Arrives in a later task'), findsOneWidget);
    // The row only reports: the About screen stays put.
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Check for updates'), findsNothing);
  });

  // The document body loads from the asset bundle, which is real asynchronous
  // I/O the test clock does not drive, so these two pin the row's navigation and
  // the window title; `legal_document_screen_test.dart` covers the document text
  // under both languages.
  testWidgets('the Privacy Policy row opens the document', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The row's label is still in the tree below the pushed route, so the check
    // is on the screen that opened and on the document's own heading, not on the
    // duplicated row text.
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(
      find.textContaining('Privacy Policy — Legal Case Diary'),
      findsOneWidget,
    );
  });

  testWidgets('the Terms of Service row opens the document', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(
      find.textContaining('Terms of Service — Legal Case Diary'),
      findsOneWidget,
    );
  });

  testWidgets('shows the version card, description and key features', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    expect(find.text('More About the App'), findsOneWidget);
    expect(find.text('Legal Case Diary'), findsOneWidget);
    expect(find.text('Version $appVersion'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    // The description names this app, and the feature list names only what the
    // offline version has.
    expect(
      find.textContaining('built for lawyers in Bangladesh'),
      findsOneWidget,
    );
    expect(find.textContaining('Justice Ledger'), findsNothing);

    expect(find.text('KEY FEATURES'), findsOneWidget);
    expect(find.text('Daily Cause List'), findsOneWidget);
    expect(find.text('Offline Backup'), findsOneWidget);
    expect(find.text('Case References'), findsOneWidget);
    expect(find.text('Hearing Notifications'), findsOneWidget);
    expect(find.text('Secure Sync'), findsNothing);

    expect(find.text('Rate App'), findsOneWidget);
    expect(find.text('Share App'), findsOneWidget);
    // The footer is one rich-text span: the label plus the highlighted name.
    expect(find.textContaining('Designed & Developed by'), findsOneWidget);
    expect(find.textContaining('Adv. Asadusjaman Sazal'), findsOneWidget);
  });

  testWidgets('store and update actions report their Part A state', (
    tester,
  ) async {
    await pumpAbout(tester);
    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Arrives in a later task'), findsOneWidget);

    await tester.tap(find.text('Rate App'));
    await tester.pumpAndSettle();
    expect(find.text('Arrives in a later task'), findsOneWidget);

    await tester.tap(find.text('Share App'));
    await tester.pumpAndSettle();
    expect(find.text('Arrives in a later task'), findsOneWidget);

    // Still on the same screen: nothing navigated away from the pushed route.
    expect(find.text('KEY FEATURES'), findsOneWidget);
  });

  testWidgets('the app theme does not paint the outlined actions black', (
    tester,
  ) async {
    // The shared settings harness pumps without the app theme, so this class of
    // bug is invisible to every other test — the theme paints outlined buttons
    // black, which left the blue "Check for updates" label on a black surface.
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.settingsMoreAbout,
      routes: [
        GoRoute(
          path: AppRoutes.settingsMoreAbout,
          builder: (context, state) => const MoreAboutTheAppScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsPrivacyPolicy,
          builder: (context, state) =>
              const LegalDocumentScreen(document: LegalDocument.privacyPolicy),
        ),
        GoRoute(
          path: AppRoutes.settingsTermsOfService,
          builder: (context, state) =>
              const LegalDocumentScreen(document: LegalDocument.termsOfService),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.lightTheme(const Locale('en')),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    // The painted surface behind each outlined action's label.
    Color? paintedBehind(String label) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      return tester
          .widgetList<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .first
          .color;
    }

    expect(paintedBehind('Check for updates'), isNot(Colors.black));
    expect(paintedBehind('Share App'), isNot(Colors.black));
  });

  testWidgets('renders the Bengali copy under Locale(bn)', (tester) async {
    await pumpAbout(tester, locale: const Locale('bn'));
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsAbout_title), findsOneWidget);
    expect(find.text(l.settingsAbout_moreAboutApp), findsOneWidget);
    expect(find.text(l.settingsAbout_dataSafetyTitle.toUpperCase()), findsOne);

    await tester.tap(find.text(l.settingsAbout_moreAboutApp));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsMoreAbout_keyFeatures.toUpperCase()), findsOne);
    expect(find.text(l.settingsMoreAbout_rateApp), findsOneWidget);
  });
}
