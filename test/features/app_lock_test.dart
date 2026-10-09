/// App Lock: the store's contract, the screen's visibility rules, and the
/// gate that covers the app.
///
/// Three layers, each tested at its own seam — the store directly, the screen
/// over a store whose digest lives in a plain map, and the root gate wrapped
/// around a marker widget. The fingerprint is a fake ([FakeBiometrics]) that
/// records what it was asked, because the platform prompt itself cannot be
/// driven from a test, and a lock feature whose verification is untested
/// would prove only that buttons render.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/database/encryption_key_manager.dart';
import 'package:legal_case_diary/features/app_lock/data/app_lock_store.dart';
import 'package:legal_case_diary/features/app_lock/data/biometrics.dart';
import 'package:legal_case_diary/features/app_lock/presentation/app_lock_scope.dart';
import 'package:legal_case_diary/features/app_lock/presentation/app_lock_screen.dart';

/// Key storage that keeps its map visible, so a test can prove what the
/// digest does *not* contain.
class _MapKeyStorage implements KeyStorage {
  final Map<String, String> raw = <String, String>{};

  @override
  Future<String?> read({required String key}) async => raw[key];

  @override
  Future<void> write({required String key, required String value}) async {
    raw[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    raw.remove(key);
  }
}

/// The biometric prompt, standing in for the platform.
class FakeBiometrics implements Biometrics {
  /// Creates the fake.
  FakeBiometrics({this.usable = true, this.verifyResult = true});

  /// Whether the device claims to have an enrolled fingerprint.
  bool usable;

  /// What the next verification answers.
  bool verifyResult;

  /// How many times the prompt has been opened.
  int verifyCalls = 0;

  @override
  Future<bool> get isUsable async => usable;

  @override
  Future<bool> verify(String reason) async {
    verifyCalls++;
    return verifyResult;
  }
}

/// Types [pin] on whatever keypad is open.
Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}

void main() {
  late AppLocalizations l;

  setUp(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // -------------------------------------------------------------------------
  // The store
  // -------------------------------------------------------------------------

  group('AppLockStore', () {
    Future<(AppLockStore, _MapKeyStorage)> store() async {
      final prefs = await SharedPreferences.getInstance();
      final storage = _MapKeyStorage();
      return (AppLockStore(storage: storage, prefs: prefs), storage);
    }

    test('setup stores a digest, never the pin, and verifies it', () async {
      final (appLock, storage) = await store();
      await appLock.setupPin('1234');

      expect(await appLock.isSetup, isTrue);
      expect(await appLock.verifyPin('1234'), isTrue);
      expect(await appLock.verifyPin('4321'), isFalse);
      expect(
        storage.raw.values.join(),
        isNot(contains('1234')),
        reason: 'the pin must exist nowhere in the store, only its digest',
      );
      expect(await appLock.verifyPin(''), isFalse);
    });

    test('setup refuses anything that is not four digits', () async {
      final (appLock, _) = await store();
      for (final bad in <String>['12', '12345', 'abcd', '']) {
        await expectLater(
          appLock.setupPin(bad),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
      expect(await appLock.isSetup, isFalse);
    });

    test('changing the pin retires the old one', () async {
      final (appLock, _) = await store();
      await appLock.setupPin('1234');
      await appLock.changePin('5678');

      expect(await appLock.verifyPin('5678'), isTrue);
      expect(await appLock.verifyPin('1234'), isFalse);
    });

    test('a corrupt digest never verifies', () async {
      final (appLock, storage) = await store();
      storage.raw['app_lock_pin'] = 'not-a-record';
      // isSetup comes from the plain flag, but verification must not be
      // fooled by a record it cannot parse.
      await appLock.prefs.setBool('app_lock_enabled', true);

      expect(await appLock.verifyPin('1234'), isFalse);
    });

    test('the switches default to the shipped values and persist', () async {
      final (appLock, _) = await store();

      expect(appLock.fingerprintEnabled, isFalse);
      expect(appLock.timing, AppLockTiming.appOpen);
      expect(
        appLockTimingFromName('something-a-future-build-wrote'),
        AppLockTiming.appOpen,
        reason: 'an unknown stored name falls back to the default',
      );

      await appLock.setFingerprintEnabled(true);
      await appLock.setTiming(AppLockTiming.appOpenAndReturn);

      expect(appLock.fingerprintEnabled, isTrue);
      expect(appLock.timing, AppLockTiming.appOpenAndReturn);
    });
  });

  // -------------------------------------------------------------------------
  // The screen
  // -------------------------------------------------------------------------

  group('the App Lock screen', () {
    /// Pumps the screen over [store]; the fingerprint defaults to a usable,
    /// cooperating device.
    Future<void> pumpScreen(
      WidgetTester tester, {
      required AppLockStore store,
      FakeBiometrics? biometrics,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockStoreProvider.overrideWithValue(store),
            biometricsProvider.overrideWithValue(
              biometrics ?? FakeBiometrics(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const AppLockScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<AppLockStore> plainStore() async => AppLockStore(
      storage: InMemoryKeyStorage(),
      prefs: await SharedPreferences.getInstance(),
    );

    testWidgets('offers only Setup until a pin exists', (tester) async {
      await pumpScreen(tester, store: await plainStore());

      expect(find.byKey(const ValueKey('app-lock-setup')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-lock-change')), findsNothing);
      expect(
        find.byKey(const ValueKey('app-lock-fingerprint')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('app-lock-timing')), findsNothing);
      await unmountScreen(tester);
    });

    testWidgets('setup asks, confirms, and swaps the rows over', (tester) async {
      final store = await plainStore();
      await pumpScreen(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('app-lock-setup')));
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_choosePin('4')), findsOneWidget);

      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_confirmPin), findsOneWidget);

      await enterPin(tester, '1234');
      await tester.pumpAndSettle();

      expect(await store.isSetup, isTrue);
      expect(find.text(l.settingsAppLock_setupDone), findsOneWidget);
      // The requested visibility flip: Setup is gone, everything else appears.
      expect(find.byKey(const ValueKey('app-lock-setup')), findsNothing);
      expect(find.byKey(const ValueKey('app-lock-turn-off')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-lock-change')), findsOneWidget);
      expect(
        find.text(l.settingsAppLock_enableFingerprint),
        findsOneWidget,
      );
      // The timing control is the header button, with its choices closed.
      expect(find.byKey(const ValueKey('app-lock-timing')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-lock-timing-app-starts')),
        findsNothing,
      );
      await unmountScreen(tester);
    });

    testWidgets('a mismatched confirmation starts over instead of storing', (
      tester,
    ) async {
      final store = await plainStore();
      await pumpScreen(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('app-lock-setup')));
      await tester.pumpAndSettle();
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      await enterPin(tester, '9999');
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_pinMismatch), findsOneWidget);
      expect(await store.isSetup, isFalse, reason: 'nothing stored yet');

      // Back at the first step with a cleared pad.
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();

      expect(await store.isSetup, isTrue);
      await unmountScreen(tester);
    });

    testWidgets('changing the pin demands the current one, then the new pair', (
      tester,
    ) async {
      final store = await plainStore();
      await store.setupPin('1234');
      await pumpScreen(tester, store: store);

      await tester.tap(find.byKey(const ValueKey('app-lock-change')));
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_enterCurrentPin), findsOneWidget);

      // Wrong current pin: named, and nothing advances.
      await enterPin(tester, '9999');
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_currentPinWrong), findsOneWidget);
      expect(find.text(l.settingsAppLock_newPin), findsNothing);

      // Right current pin: into the new one.
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_newPin), findsOneWidget);
      await enterPin(tester, '5678');
      await tester.pumpAndSettle();
      await enterPin(tester, '5678');
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_pinChanged), findsOneWidget);
      expect(await store.verifyPin('5678'), isTrue);
      expect(await store.verifyPin('1234'), isFalse);
      await unmountScreen(tester);
    });

    testWidgets('the fingerprint row flips only after a verified prompt', (
      tester,
    ) async {
      final store = await plainStore();
      await store.setupPin('1234');
      final biometrics = FakeBiometrics();
      await pumpScreen(tester, store: store, biometrics: biometrics);

      // On: the prompt runs and says yes.
      await tester.tap(find.byKey(const ValueKey('app-lock-fingerprint')));
      await tester.pumpAndSettle();
      expect(biometrics.verifyCalls, 1);
      expect(find.text(l.settingsAppLock_fingerprintEnabled), findsOneWidget);
      expect(
        find.text(l.settingsAppLock_disableFingerprint),
        findsOneWidget,
      );
      expect(store.fingerprintEnabled, isTrue);

      // Off, refused: the device says no, so the state must not move.
      biometrics.verifyResult = false;
      await tester.tap(find.byKey(const ValueKey('app-lock-fingerprint')));
      await tester.pumpAndSettle();
      expect(
        find.text(l.settingsAppLock_disableFingerprint),
        findsOneWidget,
        reason: 'a prompt the user failed must not disable anything',
      );
      expect(store.fingerprintEnabled, isTrue);

      // Off, proven: now it flips back.
      biometrics.verifyResult = true;
      await tester.tap(find.byKey(const ValueKey('app-lock-fingerprint')));
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_enableFingerprint), findsOneWidget);
      expect(store.fingerprintEnabled, isFalse);
      await unmountScreen(tester);
    });

    testWidgets('a device with no fingerprint says so and changes nothing', (
      tester,
    ) async {
      final store = await plainStore();
      await store.setupPin('1234');
      await pumpScreen(
        tester,
        store: store,
        biometrics: FakeBiometrics(usable: false),
      );

      await tester.tap(find.byKey(const ValueKey('app-lock-fingerprint')));
      await tester.pumpAndSettle();

      expect(
        find.text(l.settingsAppLock_fingerprintUnavailable),
        findsOneWidget,
      );
      expect(find.text(l.settingsAppLock_enableFingerprint), findsOneWidget);
      expect(store.fingerprintEnabled, isFalse);
      await unmountScreen(tester);
    });

    testWidgets('the timing button opens onto its two choices and closes', (
      tester,
    ) async {
      final store = await plainStore();
      await store.setupPin('1234');
      await pumpScreen(tester, store: store);

      // Closed at first: the header is a button, the choices are not shown.
      expect(
        find.byKey(const ValueKey('app-lock-timing-app-starts')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('app-lock-timing')));
      await tester.pumpAndSettle();

      // Both choices, marked for the one in effect (the shipped default).
      expect(
        find.text(l.settingsAppLock_whenAppStarts),
        findsOneWidget,
      );
      expect(
        find.text(l.settingsAppLock_whenAppOpensAndReturns),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('app-lock-timing-app-starts')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );

      // Choosing writes the timing and collapses the section again.
      await tester.tap(find.byKey(const ValueKey('app-lock-timing-every-open')));
      await tester.pumpAndSettle();
      expect(store.timing, AppLockTiming.appOpenAndReturn);
      expect(
        find.byKey(const ValueKey('app-lock-timing-app-starts')),
        findsNothing,
        reason: 'the section closes on a choice',
      );

      // Reopening marks the newly chosen one.
      await tester.tap(find.byKey(const ValueKey('app-lock-timing')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('app-lock-timing-every-open')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      await unmountScreen(tester);
    });

    testWidgets('Turn Off confirms, removes the pin, and returns to Setup', (
      tester,
    ) async {
      final store = await plainStore();
      await store.setupPin('1234');
      await store.setFingerprintEnabled(true);
      await pumpScreen(tester, store: store);

      // Declining the warning changes nothing.
      await tester.tap(find.byKey(const ValueKey('app-lock-turn-off')));
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_turnOffTitle), findsOneWidget);
      await tester.tap(find.text(l.sharedActions_cancel));
      await tester.pumpAndSettle();
      expect(await store.isSetup, isTrue);
      expect(find.byKey(const ValueKey('app-lock-change')), findsOneWidget);

      // Confirming turns it off: the PIN is gone and fingerprint with it.
      await tester.tap(find.byKey(const ValueKey('app-lock-turn-off')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-lock-turn-off-confirm')));
      await tester.pumpAndSettle();

      expect(await store.isSetup, isFalse);
      expect(store.fingerprintEnabled, isFalse);
      expect(await store.verifyPin('1234'), isFalse);
      expect(find.text(l.settingsAppLock_turnedOff), findsOneWidget);
      // The screen is back to its first-run shape.
      expect(find.byKey(const ValueKey('app-lock-setup')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-lock-change')), findsNothing);
      await unmountScreen(tester);
    });
  });

  // -------------------------------------------------------------------------
  // The gate
  // -------------------------------------------------------------------------

  group('AppLockScope', () {
    const marker = ValueKey('under-the-lock');

    Future<AppLockStore> seeded({
      bool withPin = true,
      AppLockTiming timing = AppLockTiming.appOpen,
      bool fingerprint = false,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        if (timing != AppLockTiming.appOpen)
          'app_lock_timing': timing.name,
        if (fingerprint) 'app_lock_fingerprint_enabled': true,
      });
      final store = AppLockStore(
        storage: InMemoryKeyStorage(),
        prefs: await SharedPreferences.getInstance(),
      );
      if (withPin) await store.setupPin('1234');
      return store;
    }

    Future<void> pumpGate(
      WidgetTester tester, {
      required AppLockStore store,
      FakeBiometrics? biometrics,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockStoreProvider.overrideWithValue(store),
            biometricsProvider.overrideWithValue(
              biometrics ?? FakeBiometrics(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: AppLockScope(
              child: const Center(child: Text('App is under here', key: marker)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    /// The production shape (app.dart): the gate wraps what `MaterialApp.builder`
    /// hands back — the navigator itself — so everything the gate draws sits
    /// *outside* the navigator's Overlay. Pumping the gate under `home:` hides
    /// exactly that, which is how a Tooltip in the pad shipped crashing the
    /// lock screen with "No Overlay widget found" while every `home:`-shaped
    /// test stayed green.
    Future<void> pumpGateInShell(
      WidgetTester tester, {
      required AppLockStore store,
      FakeBiometrics? biometrics,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockStoreProvider.overrideWithValue(store),
            biometricsProvider.overrideWithValue(
              biometrics ?? FakeBiometrics(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => AppLockScope(
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Center(child: Text('App is under here', key: marker)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'the lock builds beside the navigator without a framework error',
      (tester) async {
        await pumpGateInShell(
          tester,
          store: await seeded(fingerprint: true),
          biometrics: FakeBiometrics(),
        );

        // The reported defect: a Tooltip in the pad asserted "No Overlay widget
        // found" here — the lock is outside the navigator's overlay — and the
        // throw took the keypad down with it, fingerprint glyph and all.
        expect(tester.takeException(), isNull);
        expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);
        expect(find.byKey(const ValueKey('pin-pad-fingerprint')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('pin-pad-fingerprint')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets(
      'five wrong pins rest the keypad but never the fingerprint',
      (tester) async {
        await pumpGate(
          tester,
          store: await seeded(fingerprint: true),
          biometrics: FakeBiometrics(),
        );
        for (var i = 0; i < 5; i++) {
          await enterPin(tester, '9999');
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('pin-pad-message'))).data,
          contains('Try Again In'),
        );

        // The digits are resting…
        await enterPin(tester, '1234');
        await tester.pump();
        expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);

        // …but the fingerprint is still the way back in: the rest is against
        // guessing, not against the owner.
        final glyph = tester.widget<IconButton>(
          find.byKey(const ValueKey('pin-pad-fingerprint')),
        );
        expect(glyph.onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('pin-pad-fingerprint')));
        await tester.pumpAndSettle();
        expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
        await unmount(tester);
      },
    );

    testWidgets('a phone with a pin starts covered and opens with the pin', (
      tester,
    ) async {
      await pumpGate(tester, store: await seeded());

      expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);

      await enterPin(tester, '1234');
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('a fresh install is never covered', (tester) async {
      await pumpGate(tester, store: await seeded(withPin: false));

      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('five wrong pins rest the keypad, then it counts back in', (
      tester,
    ) async {
      await pumpGate(tester, store: await seeded());

      for (var i = 0; i < 5; i++) {
        await enterPin(tester, '9999');
        await tester.pumpAndSettle();
      }
      final refusal = tester.widget<Text>(
        find.byKey(const ValueKey('pin-pad-message')),
      );
      expect(refusal.data, contains('Try Again In'));
      expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);

      // During the rest, typing does nothing at all.
      await enterPin(tester, '1234');
      await tester.pump();
      expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);

      // The rest runs out (the countdown ticks with the frames), and the pin
      // that was refused a moment ago now opens the app.
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('a wrong pin names itself and tries again without a rest', (
      tester,
    ) async {
      await pumpGate(tester, store: await seeded());

      await enterPin(tester, '9999');
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_wrongPin), findsOneWidget);
      // Under five wrongs the keypad stays live: the correct pin still works.
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('the default never re-locks on return from the background', (
      tester,
    ) async {
      await pumpGate(tester, store: await seeded());
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });

    testWidgets('the background-return choice re-locks on every resume', (
      tester,
    ) async {
      await pumpGate(
        tester,
        store: await seeded(timing: AppLockTiming.appOpenAndReturn),
      );
      await enterPin(tester, '1234');
      await tester.pumpAndSettle();
      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_unlockTitle), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the fingerprint unlocks the lock screen when it is on', (
      tester,
    ) async {
      await pumpGate(
        tester,
        store: await seeded(fingerprint: true),
        biometrics: FakeBiometrics(),
      );

      expect(find.byKey(const ValueKey('pin-pad-fingerprint')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pin-pad-fingerprint')));
      await tester.pumpAndSettle();

      expect(find.text(l.settingsAppLock_unlockTitle), findsNothing);
      await unmount(tester);
    });
  });
}

/// Removes the tree so provider containers and timers stop at the end of a
/// case.
Future<void> unmountScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
