/// Subscription banner tests — Task 21 Phase 4.
///
/// Pins the three states and their boundaries (active, grace, past grace for an
/// owner/individual and for an associate, plus the clock-skew correction) and
/// that the widget renders each message and nothing at all when all is well.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart'
    show AccountRole;
import 'package:legal_case_diary/features/payments/presentation/subscription_banner.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  int at(Duration fromNow) => now.add(fromNow).millisecondsSinceEpoch;

  group('state derivation', () {
    test('an active subscription shows nothing', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(days: 10)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.none,
      );
    });

    test('no expiry (a free account) shows nothing', () {
      expect(
        resolveSubscriptionBanner(
          expiry: null,
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.none,
      );
    });

    test('inside the 48h grace the warning shows', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -1)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.grace,
      );
    });

    test('past grace the owner message shows', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -49)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.expiredOwner,
      );
    });

    test('past grace an associate is told to contact the owner', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -49)),
          now: now,
          clockOffsetMs: 0,
          firmMember: true,
          role: AccountRole.associate,
        ),
        SubscriptionBannerState.expiredAssociate,
      );
      // The owner of the same firm gets the owner message.
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -49)),
          now: now,
          clockOffsetMs: 0,
          firmMember: true,
          role: AccountRole.owner,
        ),
        SubscriptionBannerState.expiredOwner,
      );
    });

    test('a device clock ahead does not falsely enter grace', () {
      // 49h past by the device; 2h behind by server time → still grace.
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -49)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.expiredOwner,
      );
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: -49)),
          now: now,
          clockOffsetMs: -2 * 60 * 60 * 1000,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.grace,
      );
    });
  });

  group('widget', () {
    Future<void> pump(WidgetTester tester, SubscriptionBannerState state) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionBannerStateProvider.overrideWithValue(state),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(body: SubscriptionBanner()),
          ),
        ),
      );
    }

    testWidgets('renders the grace message', (tester) async {
      await pump(tester, SubscriptionBannerState.grace);
      expect(
        find.textContaining('Renew to avoid losing sync access'),
        findsOneWidget,
      );
    });

    testWidgets('renders the owner message', (tester) async {
      await pump(tester, SubscriptionBannerState.expiredOwner);
      expect(
        find.textContaining('Renew your subscription to restore sync'),
        findsOneWidget,
      );
    });

    testWidgets('renders the associate message', (tester) async {
      await pump(tester, SubscriptionBannerState.expiredAssociate);
      expect(
        find.textContaining('Contact your firm owner to renew'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when all is well', (tester) async {
      await pump(tester, SubscriptionBannerState.none);
      expect(find.byType(Text), findsNothing);
    });
  });
}
