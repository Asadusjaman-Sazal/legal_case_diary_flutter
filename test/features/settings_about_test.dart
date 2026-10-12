/// Tests for the About screen and the More About the App screen (Phase 4).
///
/// Both mirror their mockups (`settings_about`, `settings_moreAboutTheApp`) and
/// show the bundled `appVersion`. Two user-requested departures from the About
/// mockup are pinned here: the developer card no longer carries the email and
/// WhatsApp rows, and the **Update** row (which replaced Support here — Support
/// moved to the Settings main page) opens the updater.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/constants/app_version.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/features/settings/presentation/legal/legal_document_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/guidelines_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/more_about_app_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/more_about_the_app_screen.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_about/support_screen.dart';
import 'package:legal_case_diary/features/settings/data/update_metadata_store.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/update_screen.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'settings_test_support.dart';

void main() {
  /// Pumps the About route with a tall surface: both screens are long, and
  /// `MaterialApp` viewports build lazily, so a phone-sized viewport would hide
  /// the rows a test taps.
  Future<void> pumpAbout(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    SharedPreferences? prefs,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettingsRouter(
      tester,
      location: AppRoutes.settingsAbout,
      locale: locale,
      overrides: [
        if (prefs != null)
          sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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
        GoRoute(
          path: AppRoutes.settingsSupport,
          builder: (context, state) => const SupportScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsAboutUpdate,
          builder: (context, state) => const UpdateScreen(),
        ),
        GoRoute(
          path: AppRoutes.settingsGuidelines,
          builder: (context, state) => const GuidelinesScreen(),
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
    expect(find.text('Designed & Developed By'), findsOneWidget);
    expect(find.text('Asadusjaman Sazal'), findsOneWidget);
    expect(find.text('Advocate'), findsOneWidget);
    expect(
      find.text('District & Sessions Judge Court, Narayanganj.'),
      findsOneWidget,
    );
    // The card carries identity only: the support channels moved to the Support
    // screen (user-requested), so neither contact row is here any more.
    expect(find.text('Email'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('adv.asadusjaman@gmail.com'), findsNothing);
    expect(find.text('+8801835252721'), findsNothing);

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
    // Support is **not** here: it moved to the Settings main page, so there is
    // one Support entry in the app rather than two.
    expect(find.text('Support'), findsNothing);
    // The updater is an ordinary row of the same group (user request), not a
    // card that expands in place.
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Data Safety'), findsOneWidget);
    expect(
      find.text(
        'Your diary and your backup files are stored on your device in '
        'encrypted form. Nothing is uploaded unless you send it.',
      ),
      findsOneWidget,
    );
    // The collapsible Update entry sits above Data Safety, so the copyright is
    // pushed below the fold and needs a scroll to be found (the ListView only
    // builds what is on screen).
    await tester.scrollUntilVisible(
      find.textContaining('© 2025 ASADUSJAMAN SAZAL'),
      200,
    );
    expect(find.textContaining('© 2025 ASADUSJAMAN SAZAL'), findsOneWidget);
  });

  testWidgets('opens More About the App from its row', (tester) async {
    await pumpAbout(tester);

    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    // The pushed screen replaces the visible route. It is marked by its own
    // content rather than by the removed Check for Updates action.
    expect(find.text('Version $appVersion'), findsOneWidget);
    expect(find.text('Key Features'), findsOneWidget);
  });

  testWidgets('the Update row opens the updater, the same row shape', (
    tester,
  ) async {
    // The entry used to be a larger card that expanded in place, toggling both
    // cards at once; it is now an ordinary row of the same shape and size as
    // its neighbours that opens a screen of its own (user request).
    await pumpAbout(tester);

    final updateRow = find.ancestor(
      of: find.text('Update'),
      matching: find.byType(SettingsLinkRow),
    );
    final neighbourRow = find.ancestor(
      of: find.text('Privacy Policy'),
      matching: find.byType(SettingsLinkRow),
    );
    expect(updateRow, findsOneWidget);
    expect(
      tester.getSize(updateRow).height,
      tester.getSize(neighbourRow).height,
      reason: 'an ordinary row of the group, not the taller card',
    );

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    // It pushes the updater's own page, with all three cards on it.
    expect(find.byType(UpdateScreen), findsOneWidget);
    expect(find.text('App Update'), findsOneWidget);
    expect(find.text('Auto Check For Update'), findsOneWidget);
    expect(find.text('Update Over Network'), findsOneWidget);
    expect(find.text('Check For Update'), findsOneWidget);
  });

  // The document body loads from the asset bundle, which is real asynchronous
  // I/O the test clock does not drive, so these two pin the row's navigation and
  // the window title; `legal_document_screen_test.dart` covers the document text
  // under both languages.
  testWidgets('the Update row carries the dot when an update is offered', (
    tester,
  ) async {
    // Seeded before the pump: the notifier reads preferences once when built.
    SharedPreferences.setMockInitialValues(<String, Object>{
      updateAvailableReleaseKey: jsonEncode(<String, Object?>{
        'version': '99.99.999',
        'url': 'https://example.test/app.apk',
      }),
    });
    await pumpAbout(tester, prefs: await SharedPreferences.getInstance());

    // The row says something is waiting, beside its chevron.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Update'),
          matching: find.byType(SettingsLinkRow),
        ),
        matching: find.byType(UpdateDot),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Update row carries no dot when nothing is waiting', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.byType(UpdateDot), findsNothing);
  });

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
    // The version card's own action is gone (user request): this screen no
    // longer offers an update check at all.
    expect(find.text('Check for updates'), findsNothing);
    // The description names this app, and the feature list names only what the
    // offline version has.
    expect(
      find.textContaining('built for lawyers in Bangladesh'),
      findsOneWidget,
    );
    expect(find.textContaining('Justice Ledger'), findsNothing);

    expect(find.text('Key Features'), findsOneWidget);
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

  testWidgets('store actions report their Part A state', (tester) async {
    await pumpAbout(tester);
    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rate App'));
    await tester.pumpAndSettle();
    expect(find.text('Arrives in a later task'), findsOneWidget);

    await tester.tap(find.text('Share App'));
    await tester.pumpAndSettle();
    expect(find.text('Arrives in a later task'), findsOneWidget);

    // Still on the same screen: nothing navigated away from the pushed route.
    expect(find.text('Key Features'), findsOneWidget);
  });

  testWidgets('the app name and version sit centred in their card', (
    tester,
  ) async {
    // The Check for Updates action that used to share this row is gone, so the
    // identity is centred rather than left-aligned beside a button (user
    // request). Centred is measured against the card, not the screen: the two
    // lines' midpoints must agree with the card's own.
    await pumpAbout(tester);
    await tester.tap(find.text('More About the App'));
    await tester.pumpAndSettle();

    final title = find.text('Legal Case Diary');
    final version = find.text('Version $appVersion');
    final card = find.ancestor(of: title, matching: find.byType(Container)).last;

    final cardMiddle = tester.getCenter(card).dx;
    // Equal to within a pixel: the two lines are centred, not merely indented.
    expect(tester.getCenter(title).dx, moreOrLessEquals(cardMiddle, epsilon: 1));
    expect(
      tester.getCenter(version).dx,
      moreOrLessEquals(cardMiddle, epsilon: 1),
    );
    expect(title, findsOneWidget);
    expect(version, findsOneWidget);
  });

  testWidgets('the app theme does not paint the outlined actions black', (
    tester,
  ) async {
    // The shared settings harness pumps without the app theme, so this class of
    // bug is invisible to every other test — the theme paints outlined buttons
    // black, which left the outlined labels on a black surface. (The version
    // card's Check for Updates action was the other outlined button here; Share
    // App is the one left after it was removed.)
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

    expect(paintedBehind('Share App'), isNot(Colors.black));
  });

  testWidgets('renders the Bengali copy under Locale(bn)', (tester) async {
    await pumpAbout(tester, locale: const Locale('bn'));
    final l = await AppLocalizations.delegate.load(const Locale('bn'));

    expect(find.text(l.settingsAbout_title), findsOneWidget);
    expect(find.text(l.settingsAbout_moreAboutApp), findsOneWidget);
    expect(find.text(l.settingsAbout_dataSafetyTitle), findsOne);

    await tester.tap(find.text(l.settingsAbout_moreAboutApp));
    await tester.pumpAndSettle();
    expect(find.text(l.settingsMoreAbout_keyFeatures), findsOne);
    expect(find.text(l.settingsMoreAbout_rateApp), findsOneWidget);
  });

  testWidgets('developer card keeps its identity block on the card centre', (
    tester,
  ) async {
    // A wide surface: the card is now wider than the developer card's one-line
    // court name, which is the case where the block used to be pinned to the
    // card's left edge instead of centring on it (visible in landscape).
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: AppRoutes.settingsAbout,
      routes: [
        GoRoute(
          path: AppRoutes.settingsAbout,
          builder: (context, state) => const MoreAboutAppScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    // The screen reads the updater's provider for its row's dot, so it needs a
    // scope like every other consumer — and preferences for that provider.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.lightTheme(const Locale('en')),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The floating label and every line of the identity block share the card's
    // centre line, as the mockup's block-level centring does.
    for (final label in const [
      'Designed & Developed By',
      'Asadusjaman Sazal',
      'Advocate',
    ]) {
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo(900 / 2, 0.5),
        reason: '"$label" should sit on the card centre line',
      );
    }
  });
}
