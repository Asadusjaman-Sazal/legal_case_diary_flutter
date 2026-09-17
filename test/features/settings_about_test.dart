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
    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('DATA SAFETY'), findsOneWidget);
    expect(
      find.text(
        'Your data is stored locally on your device and encrypted in the '
        'cloud.',
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
    expect(find.text('FAQ'), findsNothing);
  });

  testWidgets('rows without a screen report their Part A state', (
    tester,
  ) async {
    await pumpAbout(tester);

    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();

    expect(find.text('Arrives in a later task'), findsOneWidget);
    // The row only reports: the About screen stays put.
    expect(find.text('FAQ'), findsOneWidget);
    expect(find.text('Check for updates'), findsNothing);
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
    expect(find.textContaining('comprehensive digital diary'), findsOneWidget);

    expect(find.text('KEY FEATURES'), findsOneWidget);
    expect(find.text('Daily Cause List'), findsOneWidget);
    expect(find.text('Offline Backup'), findsOneWidget);
    expect(find.text('Case References'), findsOneWidget);
    expect(find.text('Secure Sync'), findsOneWidget);

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
