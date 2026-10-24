/// The Client Notification section: defaults, persistence and previews.
///
/// The master switch and the Ask switch follow the Admin Panel pair's shape but
/// must also clear a remembered answer, the channel and both template choices
/// persist, the Contact Number dialog saves digits (and clears on an empty
/// save), and each channel's quotation follows its Long/Short choice and the
/// active language.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/settings/data/settings_repository.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_controls.dart';
import 'package:legal_case_diary/features/settings/presentation/settings_notifications/client_notification_section.dart';

import 'settings_test_support.dart';

void main() {
  late FakeSettingsRepository repo;

  Future<void> pumpSection(
    WidgetTester tester, {
    UserSettings settings = const UserSettings(),
    Locale locale = const Locale('en'),
  }) async {
    repo = FakeSettingsRepository(settings);
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpSettingsScreen(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: ClientNotificationSection()),
      ),
      repo: repo,
      locale: locale,
    );
  }

  bool selected(WidgetTester tester, String key) =>
      tester.widget<SettingsChoiceButton>(find.byKey(ValueKey(key))).selected;

  String preview(WidgetTester tester, String key) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('starts off, asking, on WhatsApp, Long and Short, no number', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(selected(tester, 'client-notification-enabled-off'), isTrue);
    expect(selected(tester, 'client-notification-ask-yes'), isTrue);
    expect(
      selected(tester, 'client-notification-channel-whatsapp'),
      isTrue,
    );
    expect(selected(tester, 'client-notification-whatsapp-long'), isTrue);
    expect(selected(tester, 'client-notification-sms-short'), isTrue);
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('turning automation on and off stores the answer and clears memory', (
    tester,
  ) async {
    await pumpSection(
      tester,
      settings: const UserSettings(
        automatedNotificationRememberedAnswer:
            clientNotificationRememberedYes,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('client-notification-enabled-on')),
    );
    await tester.pumpAndSettle();

    expect(repo.settings.automatedNotificationEnabled, isTrue);
    expect(repo.settings.automatedNotificationRememberedAnswer, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('client-notification-enabled-off')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.automatedNotificationEnabled, isFalse);
  });

  testWidgets('Ask clears the remembered answer when it changes', (tester) async {
    await pumpSection(
      tester,
      settings: const UserSettings(
        automatedNotificationRememberedAnswer:
            clientNotificationRememberedNo,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('client-notification-ask-no')));
    await tester.pumpAndSettle();

    expect(repo.settings.automatedNotificationAskBeforeSending, isFalse);
    expect(repo.settings.automatedNotificationRememberedAnswer, isEmpty);
  });

  testWidgets('the channel and both template choices persist', (tester) async {
    await pumpSection(tester);

    await tester.tap(
      find.byKey(const ValueKey('client-notification-channel-sms')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.automatedNotificationChannel, 'sms');

    await tester.tap(
      find.byKey(const ValueKey('client-notification-whatsapp-short')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.automatedNotificationWhatsAppTemplate, 'short');

    await tester.tap(
      find.byKey(const ValueKey('client-notification-sms-long')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.automatedNotificationSmsTemplate, 'long');
  });

  testWidgets('each quotation follows its own Long/Short choice', (tester) async {
    await pumpSection(tester);

    expect(
      preview(tester, 'client-notification-whatsapp-preview'),
      contains('Best regards,'),
    );
    expect(
      preview(tester, 'client-notification-sms-preview'),
      'Civil-123/26 is scheduled on 17/11/2026 for WS/WO at '
      'Senior Civil Judge Court, Sonargaon, Narayanganj',
    );

    await tester.tap(
      find.byKey(const ValueKey('client-notification-whatsapp-short')),
    );
    await tester.pumpAndSettle();
    expect(
      preview(tester, 'client-notification-whatsapp-preview'),
      isNot(contains('Best regards,')),
    );

    await tester.tap(
      find.byKey(const ValueKey('client-notification-sms-long')),
    );
    await tester.pumpAndSettle();
    expect(
      preview(tester, 'client-notification-sms-preview'),
      contains('Best regards,'),
    );
  });

  testWidgets('the quotation follows the language', (tester) async {
    await pumpSection(tester, locale: const Locale('bn'));

    final text = preview(tester, 'client-notification-sms-preview');
    expect(text, contains('এর পরবর্তী তাং'));
    expect(text, contains('১৭/১১/২০২৬'));
    expect(text, contains('জবাব/আপত্তি'));
  });

  testWidgets('the Contact Number dialog saves, cancels and clears', (tester) async {
    await pumpSection(tester);

    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-edit')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('client-notification-contact-input')),
      '01800000000',
    );
    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-save')),
    );
    await tester.pumpAndSettle();

    expect(repo.settings.notificationContactNumber, '01800000000');
    expect(find.text('01800000000'), findsOneWidget);

    // Cancel keeps the saved value.
    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-edit')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('client-notification-contact-input')),
      '01999999999',
    );
    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-cancel')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.notificationContactNumber, '01800000000');

    // An emptied box clears it, so the long message falls back to the Profile.
    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-edit')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('client-notification-contact-input')),
      '',
    );
    await tester.tap(
      find.byKey(const ValueKey('client-notification-contact-save')),
    );
    await tester.pumpAndSettle();
    expect(repo.settings.notificationContactNumber, isEmpty);
    expect(find.text('Not set'), findsOneWidget);
  });
}
