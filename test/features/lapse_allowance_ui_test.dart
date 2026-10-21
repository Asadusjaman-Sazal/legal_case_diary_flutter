/// Phase 10's visible half: the banner that explains a lapse, the lock that
/// marks a read-only row, and the plan label that stops calling a lapsed paid
/// account *Free*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/payments/data/payment_plans.dart';
import 'package:legal_case_diary/features/payments/presentation/current_plan.dart';
import 'package:legal_case_diary/features/payments/presentation/lapse_allowance_ui.dart';
import 'package:legal_case_diary/features/settings/data/write_allowance.dart';
import 'package:legal_case_diary/shared/widgets/case_card.dart';

void main() {
  /// A lapsed Pro holding 150 cases: 100 writable, 50 read-only.
  WriteAllowance lapsedPro() => WriteAllowance.lapsed(
    ceiling: 100,
    writableCaseIds: [for (var i = 50; i < 150; i++) 'case-$i'],
    writableNoteIds: const <String>[],
    writableReferenceIds: const <String>[],
    liveCases: 150,
    liveNotes: 0,
    liveReferences: 0,
  );

  Future<void> pump(
    WidgetTester tester, {
    required WriteAllowance allowance,
    required Widget child,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          writeAllowanceProvider.overrideWith(
            (ref) => Stream<WriteAllowance>.value(allowance),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the banner counts what stays editable and offers renewal', (
    tester,
  ) async {
    await pump(
      tester,
      allowance: lapsedPro(),
      child: const LapseAllowanceBanner(kind: LapseRowKind.cases),
    );

    expect(find.textContaining('Your access is limited'), findsOneWidget);
    expect(find.textContaining('100 most recently updated cases'), findsOneWidget);
    expect(find.textContaining('50 are read-only'), findsOneWidget);
    expect(find.text('Renew'), findsOneWidget);
  });

  testWidgets('the banner is silent while rows are inside the allowance', (
    tester,
  ) async {
    final allowance = WriteAllowance.lapsed(
      ceiling: 100,
      writableCaseIds: [for (var i = 0; i < 40; i++) 'case-$i'],
      writableNoteIds: const <String>[],
      writableReferenceIds: const <String>[],
      liveCases: 40,
      liveNotes: 0,
      liveReferences: 0,
    );
    await pump(
      tester,
      allowance: allowance,
      child: const LapseAllowanceBanner(kind: LapseRowKind.cases),
    );

    expect(find.textContaining('Your access is limited'), findsNothing);
  });

  testWidgets('the banner is silent for a premium account', (tester) async {
    await pump(
      tester,
      allowance: const WriteAllowance.unlimited(liveCases: 150),
      child: const LapseAllowanceBanner(kind: LapseRowKind.cases),
    );

    expect(find.textContaining('Your access is limited'), findsNothing);
  });

  testWidgets('a read-only case card carries the lock', (tester) async {
    await pump(
      tester,
      allowance: lapsedPro(),
      child: const CaseCard(
        caseNumber: 'Civil 12/2026',
        title: 'A Vs B',
        isReadOnly: true,
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a writable case card carries no lock', (tester) async {
    await pump(
      tester,
      allowance: lapsedPro(),
      child: const CaseCard(caseNumber: 'Civil 12/2026', title: 'A Vs B'),
    );

    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('a lapsed plan names its tier instead of reading Free', (
    tester,
  ) async {
    late AppLocalizations l;
    await pump(
      tester,
      allowance: const WriteAllowance.unlimited(liveCases: 0),
      child: Builder(
        builder: (context) {
          l = AppLocalizations.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    const plan = (known: true, premium: false, planKey: null);
    expect(
      currentPlanLabel(l, plan, tier: SubscriptionTier.firm),
      'Firm [Limited Access]',
    );
    expect(currentPlanLabel(l, plan), 'Free');
    expect(
      currentPlanLabel(
        l,
        (known: true, premium: true, planKey: null),
        tier: SubscriptionTier.pro,
      ),
      'Premium',
    );
  });
}
