/// Subscription banner tests — Task 21 Phase 4, plus the pre-expiry notice.
///
/// Pins every state and its boundaries (active and not ending soon, ending
/// within the week for an owner/individual and for an associate, the 48h grace,
/// past grace for both roles, plus the clock-skew correction) and that the
/// widget renders each message — with the right days and date — and nothing at
/// all when all is well.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
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

    test('the week before the end date warns an individual', () {
      for (final days in <int>[7, 5, 3, 1]) {
        expect(
          resolveSubscriptionBanner(
            expiry: at(Duration(days: days)),
            now: now,
            clockOffsetMs: 0,
            firmMember: false,
            role: AccountRole.individual,
          ),
          SubscriptionBannerState.endingSoon,
          reason: '$days days left is inside the warning week',
        );
      }
    });

    test('eight days out is still quiet', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(days: 8)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.none,
      );
    });

    test('the plan\'s last day warns without the plan having ended', () {
      // Ending at 23:00 tonight: still active, so this is a warning, not grace.
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(hours: 11)),
          now: now,
          clockOffsetMs: 0,
          firmMember: false,
          role: AccountRole.individual,
        ),
        SubscriptionBannerState.endingSoon,
      );
    });

    test('a firm member is told to ask the owner before the end date', () {
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(days: 7)),
          now: now,
          clockOffsetMs: 0,
          firmMember: true,
          role: AccountRole.associate,
        ),
        SubscriptionBannerState.endingSoonAssociate,
      );
      // The owner of the same firm is asked to renew, as they are the one who
      // can pay.
      expect(
        resolveSubscriptionBanner(
          expiry: at(const Duration(days: 7)),
          now: now,
          clockOffsetMs: 0,
          firmMember: true,
          role: AccountRole.owner,
        ),
        SubscriptionBannerState.endingSoon,
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

  group('wording facts', () {
    test('the ending-soon banner carries the days left and the date', () {
      final expiry = at(const Duration(days: 7));
      final info = resolveSubscriptionBannerInfo(
        expiry: expiry,
        now: now,
        clockOffsetMs: 0,
        firmMember: false,
        role: AccountRole.individual,
      );
      expect(info.state, SubscriptionBannerState.endingSoon);
      expect(info.daysLeft, 7);
      expect(info.expiry, expiry);
    });

    test('the other states carry nothing to word', () {
      final info = resolveSubscriptionBannerInfo(
        expiry: at(const Duration(hours: -49)),
        now: now,
        clockOffsetMs: 0,
        firmMember: false,
        role: AccountRole.individual,
      );
      expect(info.state, SubscriptionBannerState.expiredOwner);
      expect(info.daysLeft, isNull);
      expect(info.expiry, isNull);
    });

    test('the recorded clock offset moves the day count with it', () {
      // Device two days behind the server: a plan ending in 9 device days is 7
      // server days out, so the warning is already due.
      final info = resolveSubscriptionBannerInfo(
        expiry: at(const Duration(days: 9)),
        now: now,
        clockOffsetMs: 2 * 24 * 60 * 60 * 1000,
        firmMember: false,
        role: AccountRole.individual,
      );
      expect(info.state, SubscriptionBannerState.endingSoon);
      expect(info.daysLeft, 7);
    });
  });

  group('grace countdown', () {
    test('formats the window in the locale digits', () {
      expect(
        formatGraceCountdown(
          const Duration(hours: 47, minutes: 59, seconds: 58),
          'en',
        ),
        '47:59:58',
      );
      expect(
        formatGraceCountdown(
          const Duration(hours: 47, minutes: 59, seconds: 58),
          'bn',
        ),
        '৪৭:৫৯:৫৮',
      );
      expect(
        formatGraceCountdown(const Duration(minutes: 5, seconds: 3), 'en'),
        '00:05:03',
      );
      expect(formatGraceCountdown(Duration.zero, 'en'), '00:00:00');
      expect(
        formatGraceCountdown(const Duration(seconds: -5), 'en'),
        '00:00:00',
      );
      expect(
        formatGraceCountdown(const Duration(hours: 49), 'en'),
        '48:00:00',
      );
    });
  });

  group('widget', () {
    Future<void> pump(WidgetTester tester, SubscriptionBannerInfo info) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionBannerInfoProvider.overrideWithValue(info),
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

    testWidgets('renders the ending-soon message with days and date', (
      tester,
    ) async {
      final expiry = at(const Duration(days: 7));
      await pump(
        tester,
        SubscriptionBannerInfo(
          state: SubscriptionBannerState.endingSoon,
          daysLeft: 7,
          expiry: expiry,
        ),
      );
      final date = AppDateUtils.formatDateDDMMYYYY(expiry, locale: 'en');
      expect(
        find.textContaining('ends in 7 days, on $date'),
        findsOneWidget,
      );
      expect(find.textContaining('Renew to keep syncing'), findsOneWidget);
    });

    testWidgets('on the last day it names the date, not "in 1 days"', (
      tester,
    ) async {
      final expiry = at(const Duration(days: 1));
      await pump(
        tester,
        SubscriptionBannerInfo(
          state: SubscriptionBannerState.endingSoon,
          daysLeft: 1,
          expiry: expiry,
        ),
      );
      final date = AppDateUtils.formatDateDDMMYYYY(expiry, locale: 'en');
      expect(find.text('Your subscription ends on $date. '
          'Renew to keep syncing.'), findsOneWidget);
    });

    testWidgets('renders the associate wording before the end date', (
      tester,
    ) async {
      final expiry = at(const Duration(days: 3));
      await pump(
        tester,
        SubscriptionBannerInfo(
          state: SubscriptionBannerState.endingSoonAssociate,
          daysLeft: 3,
          expiry: expiry,
        ),
      );
      final date = AppDateUtils.formatDateDDMMYYYY(expiry, locale: 'en');
      expect(
        find.textContaining("Your firm's plan ends in 3 days, on $date"),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ask your firm owner to renew'),
        findsOneWidget,
      );
    });

    testWidgets('renders the grace message', (tester) async {
      await pump(
        tester,
        const SubscriptionBannerInfo(state: SubscriptionBannerState.grace),
      );
      expect(
        find.textContaining('Renew to avoid losing sync access'),
        findsOneWidget,
      );
    });

    testWidgets('renders the live countdown inside the grace window', (
      tester,
    ) async {
      final expiry = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      await pump(
        tester,
        SubscriptionBannerInfo(
          state: SubscriptionBannerState.grace,
          expiry: expiry,
        ),
      );

      expect(
        find.byKey(const ValueKey('subscription-grace-countdown')),
        findsOneWidget,
      );
      expect(find.textContaining('Sync stops in'), findsOneWidget);

      // Dispose the banner so its one-second timer is cancelled with the test.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('renders the owner message', (tester) async {
      await pump(
        tester,
        const SubscriptionBannerInfo(
          state: SubscriptionBannerState.expiredOwner,
        ),
      );
      expect(
        find.textContaining('Renew your subscription to restore sync'),
        findsOneWidget,
      );
    });

    testWidgets('renders the associate message', (tester) async {
      await pump(
        tester,
        const SubscriptionBannerInfo(
          state: SubscriptionBannerState.expiredAssociate,
        ),
      );
      expect(
        find.textContaining('Contact your firm owner to renew'),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when all is well', (tester) async {
      await pump(tester, SubscriptionBannerInfo.none);
      expect(find.byType(Text), findsNothing);
    });
  });
}
