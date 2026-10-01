/// Task 20 Phase 2 — the banner that finally renders `SyncService.notice`.
///
/// Two messages have been raised by the engine since Task 18 with nothing in
/// `lib/` to show them: a queued action the server refused because the firm's
/// permissions changed, and a device clock more than ~2 minutes off. Both used to
/// happen invisibly. These tests pin the smallest true thing about the fix — the
/// notice reaches a widget, says the right sentence, and can be acknowledged —
/// and, just as importantly, that an empty notice renders **nothing at all**, so
/// it can sit in the shell beside the conflict banner without either one asking
/// whether it has something to say.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/sync/presentation/sync_notice_banner.dart';
import 'package:legal_case_diary/sync/sync_providers.dart';
import 'package:legal_case_diary/sync/sync_service.dart';

void main() {
  /// Pumps the banner and hands back the container its providers live in.
  Future<ProviderContainer> pumpBanner(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: SyncNoticeBanner()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SyncNoticeBanner)),
    );
  }

  testWidgets('nothing raised renders nothing at all', (tester) async {
    await pumpBanner(tester);

    expect(find.byType(InkWell), findsNothing);

    await unmountBanner(tester);
  });

  testWidgets('a permission refusal is named, and the pending action with it', (
    tester,
  ) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final container = await pumpBanner(tester);

    container.read(syncServiceProvider).notice.value =
        SyncNotice.permissionsChanged;
    await tester.pumpAndSettle();

    expect(find.text(l.syncNotice_permissionsChanged), findsOneWidget);

    await unmountBanner(tester);
  });

  testWidgets('a skewed clock is named', (tester) async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    final container = await pumpBanner(tester);

    container.read(syncServiceProvider).notice.value = SyncNotice.clockSkew;
    await tester.pumpAndSettle();

    expect(find.text(l.syncNotice_clockSkew), findsOneWidget);

    await unmountBanner(tester);
  });

  testWidgets('acknowledging it clears the notice for good', (tester) async {
    final container = await pumpBanner(tester);
    container.read(syncServiceProvider).notice.value =
        SyncNotice.permissionsChanged;
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    // Hidden *and* cleared: a rebuild cannot bring it back, because the notice
    // itself — not a local dismissal flag — is what the banner reads.
    expect(find.byType(InkWell), findsNothing);
    expect(container.read(syncNoticeProvider).value, isNull);

    await unmountBanner(tester);
  });
}

/// Unmounts the banner tree between tests.
Future<void> unmountBanner(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
