/// The automated client notification flow: decide, ask, remember, launch.
///
/// The flow runs after a successful save, so these tests drive it directly and
/// assert what the lawyer would see: the confirmation and its two answers, the
/// remembered answer that skips the next prompt, Ask=No sending silently, the
/// exact WhatsApp/SMS URI with the composed text, the failure snackbar, and the
/// cases that must do nothing (off, no client phone, unchanged day).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/constants/app_spacing.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/contact_providers.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/services/contact_launcher.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/cases/presentation/client_notification_flow.dart';
import 'package:legal_case_diary/features/settings/data/courts_repository.dart';
import 'package:legal_case_diary/features/settings/data/on_behalfs_repository.dart';
import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

import 'settings_test_support.dart';

/// Records the URIs the flow asks to open.
class _RecordingLauncher implements ContactLauncher {
  bool result = true;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }

  @override
  Future<bool> openMailApp() async => result;
}

class _FakeCourts implements CourtsRepository {
  _FakeCourts(this.row);

  final Court row;

  @override
  Future<Court?> getById(String id) async => row;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOnBehalfs implements OnBehalfsRepository {
  _FakeOnBehalfs(this.row);

  final OnBehalf row;

  @override
  Future<OnBehalf?> getById(String id) async => row;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final nextDate = AppDateUtils.bangladeshCivilDateEpoch(2026, 11, 20);
  final previousDate = nextDate - const Duration(days: 1).inMilliseconds;

  const court = Court(
    id: 'court-1',
    courtName: 'Senior Civil Judge Court, Sonargaon, Narayanganj',
    higherLowerCourts: 'lower_courts',
    courtCategoryId: 'district_courts_civil',
    orderIndex: 0,
    isCustom: true,
    isUserModified: false,
    updatedAt: 1,
    isDeleted: false,
  );
  const role = OnBehalf(
    id: 'role-1',
    courtCategoryId: 'district_courts_civil',
    name: 'Petitioner',
    orderIndex: 1,
    isCustom: false,
    isUserModified: false,
    updatedAt: 1,
    isDeleted: false,
  );
  Case caseRow({String? partyPhone = '+8801800000000'}) => Case(
    id: 'case-1',
    userId: 'user-1',
    courtId: 'court-1',
    caseType: 'Custom Suit',
    caseNumber: '123/26',
    petitioner: 'Md. Rahim Uddin',
    respondent: 'Bangladesh Government',
    onBehalfId: 'role-1',
    partyPhone: partyPhone,
    nextDate: nextDate,
    lastStep: 'WS,WO',
    createdAt: 1,
    updatedAt: 1,
    isDeleted: false,
  );

  setUpAll(() async => initializeDateFormatting());

  late FakeSettingsRepository repo;
  late _RecordingLauncher launcher;

  Future<SharedPreferences> prefs() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      profileFieldsKey: jsonEncode(<String, String>{
        'fullName': 'Adv. Shafiullah Sourov',
        'barAssociation': 'Dhaka Bar Association',
        'membershipNo': '1557',
        'officeAddress': '',
        'mobile': '01700000000',
      }),
    });
    return SharedPreferences.getInstance();
  }

  Future<void> pumpFlow(
    WidgetTester tester, {
    UserSettings settings = const UserSettings(
      automatedNotificationEnabled: true,
    ),
    Case? currentCase,
    int? previous,
    Locale locale = const Locale('en'),
  }) async {
    repo = FakeSettingsRepository(settings);
    launcher = _RecordingLauncher();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSettingsScreen(
      tester,
      _Harness(currentCase: currentCase ?? caseRow(), previous: previous),
      repo: repo,
      locale: locale,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await prefs()),
        contactLauncherProvider.overrideWithValue(launcher),
        courtsRepositoryProvider.overrideWith((ref) async => _FakeCourts(court)),
        onBehalfsRepositoryProvider.overrideWith(
          (ref) async => _FakeOnBehalfs(role),
        ),
      ],
    );
  }

  final prompt = find.byKey(const ValueKey('client-notification-prompt'));

  Future<void> run(WidgetTester tester) async {
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
  }

  testWidgets('off, no phone or an unchanged day does nothing', (tester) async {
    await pumpFlow(tester, settings: const UserSettings());
    await run(tester);
    expect(prompt, findsNothing);
    expect(launcher.opened, isEmpty);

    await pumpFlow(tester, currentCase: caseRow(partyPhone: ''));
    await run(tester);
    expect(prompt, findsNothing);

    await pumpFlow(tester, previous: nextDate);
    await run(tester);
    expect(prompt, findsNothing);

    // The same civil day, a couple of hours apart: still no message.
    await pumpFlow(
      tester,
      previous: nextDate + const Duration(hours: 2).inMilliseconds,
    );
    await run(tester);
    expect(prompt, findsNothing);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('Ask shows the prompt; No sends nothing, Yes opens WhatsApp', (
    tester,
  ) async {
    await pumpFlow(tester, previous: previousDate);

    await run(tester);
    expect(prompt, findsOneWidget);

    // The Update window's corner and the Exit App window's action size.
    final dialog = tester.widget<AlertDialog>(prompt);
    expect(
      (dialog.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(AppSpacing.cardRadius * 2),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('client-notification-no'))).height,
      48,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('client-notification-yes'))).width,
      greaterThanOrEqualTo(112),
    );

    await tester.tap(find.byKey(const ValueKey('client-notification-no')));
    await tester.pumpAndSettle();
    expect(prompt, findsNothing);
    expect(launcher.opened, isEmpty);
    // No without Remember changes nothing, so the next change asks again.
    expect(repo.settings.automatedNotificationEnabled, isTrue);
    expect(repo.settings.automatedNotificationAskBeforeSending, isTrue);

    await run(tester);
    await tester.tap(find.byKey(const ValueKey('client-notification-yes')));
    await tester.pumpAndSettle();

    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/8801800000000');
    final body = uri.queryParameters['text']!;
    expect(body, contains('Md. Rahim Uddin'));
    expect(body, contains('Custom Suit 123/26'));
    expect(body, contains('20/11/2026'));
    expect(body, contains('WS/WO'));
    expect(body, contains('Contact: 01700000000'));
  });

  testWidgets('Remember + Yes skips the next prompt and sends', (tester) async {
    await pumpFlow(tester, previous: previousDate);

    await run(tester);
    await tester.tap(
      find.byKey(const ValueKey('client-notification-remember')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('client-notification-yes')));
    await tester.pumpAndSettle();

    expect(repo.settings.automatedNotificationEnabled, isTrue);
    expect(repo.settings.automatedNotificationAskBeforeSending, isFalse);
    expect(launcher.opened, hasLength(1));

    await run(tester);
    expect(prompt, findsNothing);
    expect(launcher.opened, hasLength(2));
  });

  testWidgets('Remember + No turns the feature off, so nothing is sent', (
    tester,
  ) async {
    await pumpFlow(tester, previous: previousDate);

    await run(tester);
    await tester.tap(
      find.byKey(const ValueKey('client-notification-remember')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('client-notification-no')));
    await tester.pumpAndSettle();

    expect(repo.settings.automatedNotificationEnabled, isFalse);
    expect(repo.settings.automatedNotificationAskBeforeSending, isFalse);
    expect(launcher.opened, isEmpty);

    // Off means the next change asks nothing and sends nothing.
    await run(tester);
    expect(prompt, findsNothing);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('manual On + Ask On brings the prompt back', (tester) async {
    // The state Remember + No leaves behind, then changed by hand.
    await pumpFlow(
      tester,
      settings: const UserSettings(
        automatedNotificationEnabled: false,
        automatedNotificationAskBeforeSending: false,
      ),
      previous: previousDate,
    );

    repo.settings = const UserSettings(
      automatedNotificationEnabled: true,
      automatedNotificationAskBeforeSending: true,
    );
    await run(tester);
    expect(prompt, findsOneWidget);
  });

  testWidgets('Ask = No sends without a prompt', (tester) async {
    await pumpFlow(
      tester,
      settings: const UserSettings(
        automatedNotificationEnabled: true,
        automatedNotificationAskBeforeSending: false,
      ),
      previous: previousDate,
    );

    await run(tester);
    expect(prompt, findsNothing);
    expect(launcher.opened, hasLength(1));
  });

  testWidgets('SMS uses the sms: URI with the short template by default', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      settings: const UserSettings(
        automatedNotificationEnabled: true,
        automatedNotificationAskBeforeSending: false,
        automatedNotificationChannel: clientNotificationChannelSms,
      ),
      previous: previousDate,
    );

    await run(tester);
    final uri = launcher.opened.single;
    expect(uri.scheme, 'sms');
    expect(uri.path, '+8801800000000');
    final body = uri.queryParameters['body']!;
    expect(
      body,
      'Custom Suit 123/26 is scheduled on 20/11/2026 for WS/WO at '
      'Senior Civil Judge Court, Sonargaon, Narayanganj',
    );
  });

  testWidgets('a failed launch is reported, not swallowed', (tester) async {
    await pumpFlow(
      tester,
      settings: const UserSettings(
        automatedNotificationEnabled: true,
        automatedNotificationAskBeforeSending: false,
      ),
      previous: previousDate,
    );
    launcher.result = false;

    await run(tester);

    expect(launcher.opened, hasLength(1));
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(Scaffold).last),
        ).casesContact_unableToOpenWhatsApp,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Bengali prompt and message follow the language', (
    tester,
  ) async {
    await pumpFlow(tester, previous: previousDate, locale: const Locale('bn'));

    await run(tester);
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(prompt),
        ).clientNotification_promptTitle,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('client-notification-yes')));
    await tester.pumpAndSettle();

    expect(launcher.opened.single.queryParameters['text'], contains('২০/১১/২০২৬'));
  });
}

/// A button that runs the flow for one case, as a save window would.
class _Harness extends ConsumerWidget {
  const _Harness({required this.currentCase, required this.previous});

  final Case currentCase;
  final int? previous;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => maybeSendAutomatedClientNotification(
          context,
          ref: ref,
          updatedCase: currentCase,
          previousNextDateMs: previous,
        ),
        child: const Text('Run'),
      ),
    ),
  );
}
