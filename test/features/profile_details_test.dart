/// Tests for the account's copy of the lawyer's own profile details.
///
/// Settings > Accounts & Profile > Profile has always written its five fields to
/// the device. The migration `20260929130000_profiles_personal_details.sql`
/// made the four of them that `profiles` now holds client-writable on the
/// caller's own row, so the same record follows the account: this file pins the
/// mapping, the push, the blanks-only pull, and the retry that keeps an offline
/// save from being silently left behind.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/account_mode.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_name_store.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/profile_repository.dart';
import 'package:legal_case_diary/features/accounts_and_profile/presentation/profile_screen.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';

import 'account_mode_test.dart' show FakeProfileRepository;
import 'auth_test_support.dart';

/// The record the Profile screen saves in these tests.
const ProfileFields _deviceRecord = ProfileFields(
  fullName: 'Adv. Rahim Uddin',
  barAssociation: 'Dhaka Bar Association',
  membershipNo: '1557',
  officeAddress: 'Chamber 402, High Court Annex',
  mobile: '1812332721',
);

void main() {
  group('The account payload', () {
    test('names the five columns, and never the e-mail', () {
      final payload = profileDetailsUpdate(_deviceRecord);

      expect(payload, <String, Object?>{
        'full_name': 'Adv. Rahim Uddin',
        'bar_association': 'Dhaka Bar Association',
        'membership_no': '1557',
        'office_address': 'Chamber 402, High Court Annex',
        'mobile_no': '1812332721',
      });
      // The account's address has its own owner: the e-mail comes from
      // auth.users and a client that could write it could lie about who it is.
      // The display name, by contrast, is the holder's own — it is part of the
      // same PATCH, or an edited name would sit on the device and never reach
      // the account.
      expect(payload.keys, isNot(contains('email')));
    });

    test('reads the four columns back, and leaves the name alone', () {
      final details = profileDetailsFromRow(<String, Object?>{
        'full_name': 'Server Name',
        'bar_association': 'Dhaka Bar Association',
        'membership_no': '1557',
        'office_address': 'Chamber 402',
        'mobile_no': '1812332721',
      });

      expect(details.barAssociation, 'Dhaka Bar Association');
      expect(details.membershipNo, '1557');
      expect(details.officeAddress, 'Chamber 402');
      expect(details.mobile, '1812332721');
      expect(details.fullName, isEmpty);
    });

    test('a row that is missing or malformed reads as blank, not as a guess', () {
      final details = profileDetailsFromRow(<String, Object?>{
        'bar_association': null,
        'membership_no': 1557,
        'office_address': 'Chamber 402',
      });

      expect(details.hasDetails, isTrue);
      expect(details.barAssociation, isEmpty);
      expect(details.membershipNo, isEmpty, reason: 'a number is not a string');
      expect(details.officeAddress, 'Chamber 402');
      expect(details.mobile, isEmpty);
    });

    test('the account fills the blanks a fresh install has', () {
      const device = ProfileFields(
        fullName: 'Adv. Rahim Uddin',
        barAssociation: 'Dhaka Bar Association',
      );
      final merged = fillBlankDetails(
        local: device,
        server: const ProfileFields(
          barAssociation: 'Other Bar',
          membershipNo: '1557',
          officeAddress: 'Chamber 402',
          mobile: '1812332721',
        ),
      );

      // Untouched where the device has something of its own, filled where it
      // does not — the rule the user chose.
      expect(merged.barAssociation, 'Dhaka Bar Association');
      expect(merged.membershipNo, '1557');
      expect(merged.officeAddress, 'Chamber 402');
      expect(merged.mobile, '1812332721');
      expect(merged.fullName, 'Adv. Rahim Uddin');
    });

    test('nothing to fill leaves the record exactly as it was', () {
      const local = ProfileFields(barAssociation: 'Dhaka Bar Association');

      expect(fillBlankDetails(local: local, server: local), local);
      expect(
        fillBlankDetails(local: local, server: ProfileFields.blank),
        local,
        reason: 'an account with no details cannot erase anything',
      );
    });

    test('hasDetails and hasBlankDetails describe the four account columns', () {
      expect(ProfileFields.blank.hasDetails, isFalse);
      expect(ProfileFields.blank.hasBlankDetails, isTrue);
      expect(const ProfileFields(mobile: '1812332721').hasDetails, isTrue);
      expect(
        const ProfileFields(
          barAssociation: 'Dhaka Bar Association',
          membershipNo: '1557',
          officeAddress: 'Chamber 402',
          mobile: '1812332721',
        ).hasBlankDetails,
        isFalse,
      );
      // The name is not one of them: a record with only a name has nothing to
      // mirror and every blank to fill.
      expect(const ProfileFields(fullName: 'Adv. Rahim').hasDetails, isFalse);
    });
  });

  group('Saving from Profile', () {
    late AuthTestHarness harness;
    late FakeProfileRepository repository;

    setUp(() {
      repository = FakeProfileRepository();
      harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
    });

    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Pumps the real Profile screen over the fakes.
    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpAuthScreen(
        tester,
        const ProfileScreen(),
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
    }

    /// Fills the editor and taps Save, as a user would.
    Future<void> saveProfile(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Edit profile'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your full name'),
        'Adv. Rahim Uddin',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter bar association name'),
        'Dhaka Bar Association',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter registration number'),
        '1557',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your office address'),
        'Chamber 402, High Court Annex',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '01XXXXXXXXX'),
        '1812332721',
      );
      await tester.tap(find.text('Save Profile'));
      await tester.pumpAndSettle();
    }

    testWidgets('Save mirrors the record onto the account', (tester) async {
      await pumpScreen(tester);
      await saveProfile(tester);

      expect(repository.savedDetails, <ProfileFields>[_deviceRecord]);
      expect(
        ProfileStore(harness.prefs).detailsPushPending,
        isFalse,
        reason: 'the account has it: nothing is owed',
      );
      expect(
        find.text('Profile saved'),
        findsOneWidget,
        reason: 'the push landed, so the toast is not the offline wording',
      );
      expect(find.text('Profile saved (offline)'), findsNothing);
    });

    testWidgets('a save the account never saw is still saved, and owed', (
      tester,
    ) async {
      repository.saveDetailsResult = false;
      await pumpScreen(tester);
      await saveProfile(tester);

      // The local record is the one the user sees and the one that survives the
      // flight mode — the account's copy is what waits.
      expect(ProfileStore(harness.prefs).read(), _deviceRecord);
      expect(repository.savedDetails, hasLength(1));
      expect(ProfileStore(harness.prefs).detailsPushPending, isTrue);
      expect(
        find.text('Profile saved (offline)'),
        findsOneWidget,
        reason: 'a push the account has not seen is the one offline case',
      );
      expect(find.text('Profile saved'), findsNothing);
    });
  });

  group('The account\'s copy', () {
    late AuthTestHarness harness;
    late FakeProfileRepository repository;

    setUp(() {
      repository = FakeProfileRepository()..refreshResult = true;
      harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
    });

    tearDown(() async {
      await harness.tearDown();
      await harness.auth.dispose();
    });

    /// Builds a container over the fakes, with the session already restored.
    Future<ProviderContainer> container() async {
      final container = ProviderContainer(
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authViewModelProvider.future);
      return container;
    }

    ProfileStore store() => ProfileStore(harness.prefs);

    test('a fresh install is filled from the account, all four at once', () async {
      repository.detailsToPull = const ProfileFields(
        barAssociation: 'Dhaka Bar Association',
        membershipNo: '1557',
        officeAddress: 'Chamber 402, High Court Annex',
        mobile: '1812332721',
      );
      final c = await container();

      expect(await c.read(accountRefreshProvider)(), isTrue);

      final saved = c.read(profileFieldsProvider);
      expect(saved.barAssociation, 'Dhaka Bar Association');
      expect(saved.membershipNo, '1557');
      expect(saved.officeAddress, 'Chamber 402, High Court Annex');
      expect(saved.mobile, '1812332721');
      expect(repository.savedDetails, isEmpty, reason: 'nothing to hand over');
    });

    test('a detail the user typed here is never overwritten', () async {
      repository.detailsToPull = const ProfileFields(
        barAssociation: 'Other Bar',
        membershipNo: '1557',
      );
      final c = await container();
      await c
          .read(profileFieldsProvider.notifier)
          .save(const ProfileFields(barAssociation: 'Dhaka Bar Association'));

      await c.read(accountRefreshProvider)();

      expect(c.read(profileFieldsProvider).barAssociation, 'Dhaka Bar Association');
      expect(c.read(profileFieldsProvider).membershipNo, '1557');
    });

    test('an account that holds nothing is given what the device has', () async {
      repository.detailsToPull = ProfileFields.blank;
      final c = await container();
      await c.read(profileFieldsProvider.notifier).save(_deviceRecord);

      await c.read(accountRefreshProvider)();

      expect(repository.savedDetails, <ProfileFields>[_deviceRecord]);
      expect(store().detailsPushPending, isFalse);
    });

    test('a device that holds only a name still hands it to the account', () async {
      repository.detailsToPull = ProfileFields.blank;
      final c = await container();
      await c
          .read(profileFieldsProvider.notifier)
          .save(const ProfileFields(fullName: 'Adv. Rahim Uddin'));

      await c.read(accountRefreshProvider)();

      expect(repository.savedDetails, hasLength(1));
      expect(repository.savedDetails.single.fullName, 'Adv. Rahim Uddin');
      expect(store().detailsPushPending, isFalse);
    });

    test('a push the account refused is retried on the next refresh', () async {
      repository.detailsToPull = ProfileFields.blank;
      final c = await container();
      await c.read(profileFieldsProvider.notifier).save(_deviceRecord);
      await store().setDetailsPushPending(true);

      await c.read(accountRefreshProvider)();

      expect(repository.savedDetails, <ProfileFields>[_deviceRecord]);
      expect(store().detailsPushPending, isFalse, reason: 'it landed this time');
      // The record is unchanged, so the pull had nothing to write.
      expect(c.read(profileFieldsProvider), _deviceRecord);
    });

    test('a retried push carries the account\'s own values with it', () async {
      // The one way this could lose a lawyer's data: a push sends the whole
      // record, so a blank field on this device must never clear a filled one on
      // the account. The merge runs first for exactly this case.
      repository.detailsToPull = const ProfileFields(membershipNo: '1557');
      final c = await container();
      await c
          .read(profileFieldsProvider.notifier)
          .save(const ProfileFields(barAssociation: 'Dhaka Bar Association'));
      await store().setDetailsPushPending(true);

      await c.read(accountRefreshProvider)();

      expect(repository.savedDetails.single.membershipNo, '1557');
      expect(
        repository.savedDetails.single.barAssociation,
        'Dhaka Bar Association',
      );
      expect(c.read(profileFieldsProvider).membershipNo, '1557');
    });

    test('an unreachable account changes nothing and stays owed', () async {
      repository.detailsToPull = null;
      final c = await container();
      await c.read(profileFieldsProvider.notifier).save(_deviceRecord);
      await store().setDetailsPushPending(true);
      repository.saveDetailsResult = false;

      await c.read(accountRefreshProvider)();

      expect(c.read(profileFieldsProvider), _deviceRecord);
      expect(store().detailsPushPending, isTrue);
    });
  });

  group('The push itself', () {
    test('a signed-in save that lands leaves nothing owed', () async {
      final repository = FakeProfileRepository();
      final harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
      addTearDown(() async {
        await harness.tearDown();
        await harness.auth.dispose();
      });
      final c = ProviderContainer(
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(c.dispose);

      expect(await c.read(pushProfileDetailsProvider)(_deviceRecord), isTrue);
      expect(repository.savedDetails, <ProfileFields>[_deviceRecord]);
      expect(ProfileStore(harness.prefs).detailsPushPending, isFalse);
    });

    test('a signed-in save that fails is recorded as owed', () async {
      final repository = FakeProfileRepository()..saveDetailsResult = false;
      final harness = AuthTestHarness(
        auth: FakeAuthRepository(identity: const AuthIdentity(userId: 'user-1')),
      );
      addTearDown(() async {
        await harness.tearDown();
        await harness.auth.dispose();
      });
      final c = ProviderContainer(
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(c.dispose);

      expect(await c.read(pushProfileDetailsProvider)(_deviceRecord), isFalse);
      expect(ProfileStore(harness.prefs).detailsPushPending, isTrue);
    });

    test('with nobody signed in there is nothing to mirror to', () async {
      final repository = FakeProfileRepository();
      final harness = AuthTestHarness();
      addTearDown(() async {
        await harness.tearDown();
        await harness.auth.dispose();
      });
      final c = ProviderContainer(
        overrides: [
          ...await harness.setUp(),
          profileRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(c.dispose);

      expect(await c.read(pushProfileDetailsProvider)(_deviceRecord), isFalse);
      expect(repository.savedDetails, isEmpty);
      expect(
        ProfileStore(harness.prefs).detailsPushPending,
        isFalse,
        reason: 'a Part A install keeps the record locally and owes nobody',
      );
    });
  });
}
