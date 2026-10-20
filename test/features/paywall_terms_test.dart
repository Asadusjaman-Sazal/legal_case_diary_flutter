/// Subscription plans screen (paywall) term rows, 2026-10-20:
///
///  * every term is a full-width row — the term and its price per month on the
///    left, the total and the round chosen mark on the right;
///  * the default term is **6 Months on every card**, individual and chamber
///    alike, and a term can no longer be deselected: a card always carries one,
///    marked by the 2 px ink outline and the filled round mark;
///  * Firm sells a one-month plan, priced above its three-month rate; Firm Plus
///    and Enterprise still start at three months;
///  * no price is struck through, no saving is named in words and there is no
///    headline price line: the per-month figures state the ladder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/app_colors.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/paywall_screen.dart';

void main() {
  /// Opens the paywall over a free profile; only the term logic is under test.
  ///
  /// [height] is the logical viewport height. The default fits the whole page so
  /// a test can assert on any card without scrolling; the pinned-toggle test
  /// shrinks it so there is something left to scroll.
  Future<void> pumpPaywall(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double height = 4200,
  }) async {
    tester.view.physicalSize = Size(1200, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          firmMemberProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const PaywallScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every card opens on 6 Months', (tester) async {
    await pumpPaywall(tester);

    // Starter and Pro, on the individual tab.
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);
    expect(find.text('Subscribe — 6 Months/৳660'), findsOneWidget);
    expect(find.textContaining('1 Month/'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    // Firm, Firm Plus and Enterprise open on their six-month plan too.
    expect(find.text('Subscribe — 6 Months/৳1,350'), findsOneWidget);
    expect(find.text('Subscribe — 6 Months/৳2,700'), findsOneWidget);
    expect(find.text('Subscribe — 6 Months/৳8,000'), findsOneWidget);
  });

  testWidgets('tapping the selected term keeps it selected', (tester) async {
    await pumpPaywall(tester);

    // The six-month row is the default, and re-tapping it changes nothing.
    final halfYearly = find.byKey(
      const ValueKey('paywall-term-starter-starter_half_yearly'),
    );
    await tester.ensureVisible(halfYearly);
    await tester.tap(halfYearly);
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);

    // Selecting the chosen term again is a no-op, not a clear.
    await tester.ensureVisible(halfYearly);
    await tester.tap(halfYearly);
    await tester.pumpAndSettle();
    expect(find.text('Subscribe — 6 Months/৳300'), findsOneWidget);
  });

  testWidgets('each row names its own price per month, and nothing is struck', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // Starter: ৳80 → ৳60 → ৳50 → ৳45 a month, with the totals beside them.
    expect(find.text('৳80/month'), findsOneWidget);
    expect(find.text('৳60/month'), findsOneWidget);
    expect(find.text('৳50/month'), findsOneWidget);
    expect(find.text('৳45/month'), findsOneWidget);
    expect(find.text('৳540'), findsOneWidget);

    // The old prose is gone with the strike-through it described.
    expect(find.text('Or choose'), findsNothing);
    expect(find.text('1 month free on 6 months'), findsNothing);
    expect(find.text('2 months free on 1 year'), findsNothing);
    expect(find.textContaining(' Off'), findsNothing);
  });

  testWidgets('a firm annual rounds its price per month to the taka', (
    tester,
  ) async {
    await pumpPaywall(tester);

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    // ৳2,500 a year is ৳208.33 a month, shown as ৳208; ৳5,000 a year is
    // ৳416.67, shown as ৳417; ৳8,000 for six months is ৳1,333.33, shown as
    // ৳1,333. The total beside each stays the exact amount charged.
    expect(find.text('৳208/month'), findsOneWidget);
    expect(find.text('৳417/month'), findsOneWidget);
    expect(find.text('৳1,333/month'), findsOneWidget);
    expect(find.text('৳2,500'), findsOneWidget);
    expect(find.text('৳5,000'), findsOneWidget);
    expect(find.text('৳8,000'), findsOneWidget);
  });

  testWidgets('Firm has a 1 Month row; Firm Plus and Enterprise do not', (
    tester,
  ) async {
    await pumpPaywall(tester);

    await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
    await tester.pumpAndSettle();

    // Only the Firm card sells a month, and its month costs more per month than
    // its quarter, so the two rows are not the same offer.
    expect(find.text('1 Month'), findsOneWidget);
    expect(find.text('৳300/month'), findsOneWidget);
    expect(find.text('৳250/month'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('paywall-term-firm_plus-firm_plus_monthly')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('paywall-term-enterprise-enterprise_monthly')),
      findsNothing,
    );
  });

  testWidgets('the toggle scrolls away with the intro, not pinned', (
    tester,
  ) async {
    await pumpPaywall(tester, height: 800);

    final toggle = find.byKey(const ValueKey('paywall-audience-individual'));
    final starter = find.byKey(const ValueKey('paywall-plan-starter'));
    final toggleBefore = tester.getRect(toggle);
    final starterBefore = tester.getRect(starter);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // The toggle moved up with the page (or left the tree) rather than staying
    // at a fixed offset the way a pinned header would.
    final movedAway =
        toggle.evaluate().isEmpty ||
        tester.getRect(toggle).top < toggleBefore.top;
    expect(movedAway, isTrue);
    // The cards scrolled too, so this is ordinary scrolling, not a layout jump.
    expect(tester.getRect(starter).top, lessThan(starterBefore.top));
  });

  testWidgets('a touched card inks, and stays inked until another is touched', (
    tester,
  ) async {
    await pumpPaywall(tester);

    final starter = find.byKey(const ValueKey('paywall-plan-starter'));
    final pro = find.byKey(const ValueKey('paywall-plan-pro'));

    // No card has been touched: even Most Popular and Current Plan are grey.
    expect(_cardBorder(tester, starter).color, AppColors.outlineVariant);
    expect(_cardBorder(tester, pro).color, AppColors.outlineVariant);
    expect(
      _cardBorder(tester, find.byKey(const ValueKey('paywall-plan-free'))).color,
      AppColors.outlineVariant,
    );

    // Touch Starter and lift: the ink stays after the finger is gone.
    await tester.tap(starter);
    await tester.pumpAndSettle();
    expect(_cardBorder(tester, starter).color, AppColors.primary);
    expect(_cardBorder(tester, starter).width, 2);
    expect(_cardBorder(tester, pro).color, AppColors.outlineVariant);

    // Touch Pro: the ink moves, and Starter goes back to grey.
    await tester.tap(pro);
    await tester.pumpAndSettle();
    expect(_cardBorder(tester, pro).color, AppColors.primary);
    expect(_cardBorder(tester, starter).color, AppColors.outlineVariant);
  });

  testWidgets('the selected term is marked with the ink outline, not green', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // The six-month row is the card's default, so the quarter and the month
    // are the rows outside the mark.
    final selected = find.byKey(
      const ValueKey('paywall-term-starter-starter_quarterly'),
    );
    final unselected = find.byKey(
      const ValueKey('paywall-term-starter-starter_monthly'),
    );
    expect(_termBorder(tester, unselected).color, AppColors.outlineVariant);

    await tester.tap(selected);
    await tester.pumpAndSettle();

    final border = _termBorder(tester, selected);
    expect(border.color, AppColors.primary);
    expect(border.color, isNot(AppColors.success));
    expect(border.width, 2);
  });

  testWidgets('the stacked rows survive a small phone at large text', (
    tester,
  ) async {
    // The 3-across row needed a large-text fallback above 1.3; full-width rows
    // must not, so this is the claim they replaced it with, measured just past
    // that threshold on a 360pt phone. (1.5 also trips a pre-existing overflow
    // in the card's title+badge row, which is outside the term rows.)
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountProfileProvider.overrideWith((ref) => Stream.value(null)),
          firmMemberProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.35)),
              child: const PaywallScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The cards start below the fold on an 800pt phone, so scroll to the rows.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('paywall-term-starter-starter_monthly')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1 Month'), findsWidgets);
    expect(find.text('৳80/month'), findsOneWidget);
  });

  testWidgets('a small phone at the largest text scale overflows nowhere', (
    tester,
  ) async {
    // The two defects this replaces: the card's title + badge row went past the
    // card's edge by 3 px at 1.5, and the Individual / Firm pill by 73 px at
    // 2.0 on a 360 pt phone. The viewport is tall as well as narrow so every
    // card's header is built and laid out, not only the one on screen.
    for (final scale in <double>[1.5, 2.0]) {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountProfileProvider.overrideWith((ref) => Stream.value(null)),
            firmMemberProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: const PaywallScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'the toggle at $scale');

      // The chamber tab carries the longest title + badge pair — Firm and
      // Most Popular — so it is where a header row would overflow first.
      await tester.tap(find.byKey(const ValueKey('paywall-audience-firm')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'a card header at $scale');
    }
  });

  testWidgets('the action is 55 tall', (tester) async {
    await pumpPaywall(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('paywall-subscribe-starter')),
    );
    expect(button.style?.minimumSize?.resolve({}), const Size.fromHeight(55));
  });

  testWidgets('a feature pairs a 12 px icon gap with the lighter row fill', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // The gap between an icon and its sentence is one gutter (12 px), measured
    // on the rendered boxes rather than read from the widget tree, because the
    // 20 px glyph carries its own padding inside the icon box.
    final icon = find.byIcon(Icons.folder_outlined).first;
    final text = find.text('Up to 50 cases');
    expect(tester.getRect(text).left - tester.getRect(icon).right, 12);

    // The term rows take the lighter grey (surfaceContainer); the audience
    // pill keeps surfaceContainerHigh, so the two are deliberately one step
    // apart, as the user chose.
    final row = find.byKey(
      const ValueKey('paywall-term-starter-starter_monthly'),
    );
    final fill = tester.widget<Material>(
      find.descendant(of: row, matching: find.byType(Material)).first,
    );
    expect(fill.color, AppColors.surfaceContainer);
    expect(AppColors.surfaceContainer, isNot(AppColors.surfaceContainerHigh));
  });

  testWidgets('exactly one row per card is marked, and the mark follows a tap', (
    tester,
  ) async {
    await pumpPaywall(tester);

    // A card always carries a term to buy, and only one of them is marked.
    expect(_markedRows(tester, SubscriptionTier.starter), 1);
    expect(_markedRows(tester, SubscriptionTier.pro), 1);

    final quarterly = find.byKey(
      const ValueKey('paywall-term-starter-starter_quarterly'),
    );
    await tester.ensureVisible(quarterly);
    await tester.tap(quarterly);
    await tester.pumpAndSettle();

    // Still one mark, and it is now on the 3 Months row.
    expect(_markedRows(tester, SubscriptionTier.starter), 1);
    expect(_termBorder(tester, quarterly).width, 2);
    expect(
      _termBorder(
        tester,
        find.byKey(const ValueKey('paywall-term-starter-starter_monthly')),
      ).width,
      1,
    );
  });
}

/// How many of [tier]'s term rows carry the 2 px chosen outline.
int _markedRows(WidgetTester tester, SubscriptionTier tier) {
  var marked = 0;
  for (final plan in plansForTier(tier)) {
    final row = find.byKey(ValueKey('paywall-term-${tier.key}-${plan.key}'));
    if (_termBorder(tester, row).width == 2) marked++;
  }
  return marked;
}

/// The border of a card's frame, which is an [AnimatedContainer].
BorderSide _cardBorder(WidgetTester tester, Finder card) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: card, matching: find.byType(AnimatedContainer)).first,
  );
  return ((container.decoration! as BoxDecoration).border! as Border).top;
}

/// The border of one term button's inner container.
BorderSide _termBorder(WidgetTester tester, Finder term) {
  final container = tester.widget<Container>(
    find.descendant(of: term, matching: find.byType(Container)).first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).top;
}
