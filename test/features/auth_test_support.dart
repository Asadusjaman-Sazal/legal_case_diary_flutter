/// Shared harness for the Task 17 auth tests.
///
/// Everything the auth screens touch sits behind a provider, so these suites
/// drive the real view model, the real adoption service and the real router
/// against fakes only at the network boundary: [FakeAuthRepository] and
/// [FakeFirmRepository]. No Supabase instance is ever initialized, and the
/// encrypted database is an in-memory Drift database.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';

/// An [AuthRepository] whose every outcome the test decides.
class FakeAuthRepository implements AuthRepository {
  /// Creates a fake, optionally already signed in as [identity].
  FakeAuthRepository({this.identity});

  /// The identity the fake currently holds; also the constructor argument.
  AuthIdentity? identity;
  final StreamController<AuthSessionEvent> _events =
      StreamController<AuthSessionEvent>.broadcast();

  /// Error to throw from [signInWithPassword]; null to succeed.
  Object? signInError;

  /// Error to throw from [signUpIndividual]; null to succeed.
  Object? signUpError;

  /// Error to throw from [signInWithGoogle]; null to succeed.
  Object? googleError;

  /// Error to throw from [sendPasswordRecoveryCode]; null to succeed.
  Object? recoveryError;

  /// Error to throw from [verifyRecoveryCode] or [updatePassword].
  Object? verifyError;

  /// What sign-up returns when it does not throw. Defaults to a signed-in
  /// account, which is the project's behaviour with e-mail confirmation off.
  SignUpOutcome? signUpOutcome;

  /// Emails and passwords the repository was asked to sign in with.
  final List<String> signInEmails = <String>[];
  final List<String> signInPasswords = <String>[];

  /// Sign-up arguments the repository received.
  final List<String> signUpNames = <String>[];
  final List<String> signUpEmails = <String>[];

  /// Recovery addresses and codes the repository received.
  final List<String> recoveryEmails = <String>[];
  final List<String> verifiedCodes = <String>[];

  /// Passwords set through [updatePassword].
  final List<String> updatedPasswords = <String>[];

  /// Number of Google sign-in attempts.
  int googleCalls = 0;

  /// Number of sign-outs.
  int signOutCalls = 0;

  /// Pushes a session event, as the SDK would.
  void emit(AuthSessionEvent event) => _events.add(event);

  /// Closes the event stream.
  Future<void> dispose() => _events.close();

  @override
  bool get isAvailable => true;

  @override
  AuthIdentity? get currentIdentity => identity;

  @override
  Stream<AuthSessionEvent> get sessionEvents => _events.stream;

  @override
  Future<AuthIdentity?> restoreSession() async => identity;

  @override
  Future<AuthIdentity> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInEmails.add(email);
    signInPasswords.add(password);
    final failure = signInError;
    if (failure != null) throw failure;
    return identity = AuthIdentity(userId: 'user-1', email: email.trim());
  }

  @override
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
  }) async {
    signUpNames.add(fullName);
    signUpEmails.add(email);
    final failure = signUpError;
    if (failure != null) throw failure;
    final configured = signUpOutcome;
    if (configured != null) return configured;
    return SignUpSignedIn(
      identity = AuthIdentity(
        userId: 'user-1',
        email: email.trim(),
        fullName: fullName.trim(),
      ),
    );
  }

  @override
  Future<AuthIdentity> signInWithGoogle() async {
    googleCalls++;
    final failure = googleError;
    if (failure != null) throw failure;
    return identity = const AuthIdentity(
      userId: 'google-1',
      email: 'counsel@gmail.com',
      signedInWithGoogle: true,
    );
  }

  @override
  Future<void> sendPasswordRecoveryCode(String email) async {
    recoveryEmails.add(email);
    final failure = recoveryError;
    if (failure != null) throw failure;
  }

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async {
    verifiedCodes.add(code);
    final failure = verifyError;
    if (failure != null) throw failure;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPasswords.add(newPassword);
    final failure = verifyError;
    if (failure != null) throw failure;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    identity = null;
    _events.add(const AuthSessionEvent());
  }
}

/// A [FirmRepository] whose redemption and owner-side primitives the test
/// decides.
class FakeFirmRepository implements FirmRepository {
  /// Codes handed to [redeemInvite].
  final List<String> redeemedCodes = <String>[];

  /// Error to throw from [redeemInvite]; null to succeed.
  Object? redeemError;

  /// What a successful redemption returns.
  InviteRedemption redemption = const InviteRedemption(
    status: InviteRedemptionStatus.joined,
    firmId: 'firm-1',
  );

  /// Error to throw from [createInvite] / [revokeInvite] / [ensureFirm].
  Object? adminError;

  /// The invite [createInvite] returns.
  GeneratedInvite invite = const GeneratedInvite(
    code: 'ABCDE12345',
    inviteId: 'invite-1',
    firmId: 'firm-1',
  );

  /// Firm ids handed to [revokeInvite].
  final List<String> revokedInviteIds = <String>[];

  /// Names handed to [ensureFirm].
  final List<String> ensuredFirmNames = <String>[];

  /// Number of [createInvite] calls.
  int createInviteCalls = 0;

  /// Error to throw from [abandonOnboarding]; null to succeed.
  Object? abandonError;

  /// What [abandonOnboarding] returns.
  bool abandonRemoved = true;

  /// Number of [abandonOnboarding] calls.
  int abandonCalls = 0;

  @override
  Future<InviteRedemption> redeemInvite(String code) async {
    redeemedCodes.add(code);
    final failure = redeemError;
    if (failure != null) throw failure;
    return redemption;
  }

  @override
  Future<GeneratedInvite> createInvite() async {
    createInviteCalls++;
    final failure = adminError;
    if (failure != null) throw failure;
    return invite;
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    revokedInviteIds.add(inviteId);
    final failure = adminError;
    if (failure != null) throw failure;
  }

  @override
  Future<String> ensureFirm(String name) async {
    ensuredFirmNames.add(name);
    final failure = adminError;
    if (failure != null) throw failure;
    return invite.firmId;
  }

  @override
  Future<bool> abandonOnboarding() async {
    abandonCalls++;
    final failure = abandonError;
    if (failure != null) throw failure;
    return abandonRemoved;
  }
}

/// Everything a screen test needs: preferences, a database, and the fakes.
class AuthTestHarness {
  /// Creates the harness; [auth] defaults to an empty fake.
  AuthTestHarness({
    FakeAuthRepository? auth,
    this.preferences = const <String, Object>{},
  }) : auth = auth ?? FakeAuthRepository();

  /// The fake auth repository, configured by each test.
  final FakeAuthRepository auth;

  /// The fake firm repository.
  final FakeFirmRepository firm = FakeFirmRepository();

  /// The preferences the app starts with, before Drift is ready.
  final Map<String, Object> preferences;

  /// The database the adoption service writes to.
  late final AppDatabase db;

  /// The preferences the app reads.
  late final SharedPreferences prefs;

  /// Creates the database and preferences, and returns the provider overrides.
  Future<List<Override>> setUp() async {
    SharedPreferences.setMockInitialValues(preferences);
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    return <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWith((_) async => db),
      authRepositoryProvider.overrideWithValue(auth),
      firmRepositoryProvider.overrideWithValue(firm),
    ];
  }

  /// Closes the database.
  Future<void> tearDown() => db.close();
}

/// Pumps [screen] with the app's theme, localizations and [overrides].
Future<void> pumpAuthScreen(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Where a screen that leaves the auth routes lands, in [pumpAuthRouter].
const String authLandingMarker = 'The Diary Opened';

/// Marker for the bundled Terms of Service screen.
const String authTermsMarker = 'Terms Of Service Document';

/// Marker for the bundled Privacy Policy screen.
const String authPrivacyMarker = 'Privacy Policy Document';

/// Pumps [screen] inside a minimal GoRouter.
///
/// Sign-up navigates on success (`context.go`), which a bare `home:` tree cannot
/// do, so the screen under test sits at `/under-test` and every route it can
/// leave for exists as a marker the test asserts on. Both legal documents are
/// real routes because the sign-up card links to them in-line.
Future<void> pumpAuthRouter(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: '/under-test',
    routes: <RouteBase>[
      GoRoute(path: '/under-test', builder: (_, _) => screen),
      GoRoute(
        path: AppRoutes.dailyCauseList,
        builder: (_, _) => const Scaffold(body: Text(authLandingMarker)),
      ),
      GoRoute(
        path: AppRoutes.settingsTermsOfService,
        builder: (_, _) => const Scaffold(body: Text(authTermsMarker)),
      ),
      GoRoute(
        path: AppRoutes.settingsPrivacyPolicy,
        builder: (_, _) => const Scaffold(body: Text(authPrivacyMarker)),
      ),
      for (final route in <String>[
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
      ])
        GoRoute(
          path: route,
          builder: (_, _) => const Scaffold(body: Text('auth-route')),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Unmounts the tree so live Drift streams stop before teardown.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// The persisted invite code, read straight from the local auth cache.
String? pendingInviteCode(SharedPreferences prefs) =>
    LocalAuthService(prefs).pendingInviteCode;
