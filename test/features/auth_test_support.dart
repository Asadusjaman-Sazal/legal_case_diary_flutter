/// Shared harness for the Task 17 auth tests.
///
/// Everything the auth screens touch sits behind a provider, so these suites
/// drive the real view model, the real adoption service and the real router
/// against fakes only at the network boundary: [FakeAuthRepository] and
/// [FakeFirmRepository]. No Supabase instance is ever initialized, and the
/// encrypted database is an in-memory Drift database.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/errors/error_log_provider.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/providers/repository_providers.dart';
import 'package:legal_case_diary/core/router/app_router.dart';
import 'package:legal_case_diary/core/theme/app_theme.dart';
import 'package:legal_case_diary/database/app_database.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/data/local_auth_service.dart';
import 'package:legal_case_diary/features/auth/data/logout_flow.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_viewmodel.dart';
import 'package:legal_case_diary/features/settings/data/backup_repository.dart';
import 'package:legal_case_diary/shared/providers/database_provider.dart';
import 'package:legal_case_diary/shared/providers/shared_preferences_provider.dart';
import 'package:legal_case_diary/sync/sync_service.dart';

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

  /// The account id [signInWithPassword] signs in as.
  ///
  /// `user-1` unless a test is switching accounts on one device, where the
  /// second sign-in has to arrive as somebody else.
  String signInUserId = 'user-1';

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
  final List<String> signUpBarAssociations = <String>[];

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
    return identity = AuthIdentity(
      userId: signInUserId,
      email: email.trim(),
    );
  }

  @override
  Future<SignUpOutcome> signUpIndividual({
    required String fullName,
    required String email,
    required String password,
    String barAssociation = '',
  }) async {
    signUpNames.add(fullName);
    signUpEmails.add(email);
    signUpBarAssociations.add(barAssociation);
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
    // The real SDK signs the user in and reports the recovery event for a typed
    // code exactly as it does for an opened link — `verifyOTP` branches on
    // `OtpType.recovery`, not on how the token arrived — so the fake has to as
    // well. Without it, no test can see what the ViewModel does with the event.
    identity = AuthIdentity(userId: 'user-9', email: email.trim());
    _events.add(AuthSessionEvent(identity: identity!, passwordRecovery: true));
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

/// One `updateMemberPermissions` call, recorded so a test can assert both that
/// it happened and what it wrote.
class MemberPermissionWrite {
  /// Creates a recorded write.
  const MemberPermissionWrite({
    required this.userId,
    required this.role,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
  });

  /// The member the write targeted.
  final String userId;

  /// The role it wrote.
  final String role;

  /// The three flags it wrote.
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
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

  /// The roster [listMembers] returns.
  List<FirmMemberSummary> members = const <FirmMemberSummary>[];

  /// Error to throw from [listMembers]; null to succeed.
  Object? membersError;

  /// The outstanding invites [listInvites] returns.
  List<FirmInviteSummary> invites = const <FirmInviteSummary>[];

  /// Error to throw from [listInvites]; null to succeed.
  Object? invitesError;

  /// Every permission write [updateMemberPermissions] made, in call order.
  final List<MemberPermissionWrite> permissionWrites = <MemberPermissionWrite>[];

  /// Error to throw from [updateMemberPermissions]; null to succeed.
  Object? permissionsError;

  /// User ids handed to [removeMember].
  final List<String> removedMemberIds = <String>[];

  /// Error to throw from [removeMember]; null to succeed.
  Object? removeMemberError;

  @override
  Future<List<FirmInviteSummary>> listInvites() async {
    final failure = invitesError;
    if (failure != null) throw failure;
    return invites;
  }

  @override
  Future<void> updateMemberPermissions({
    required String userId,
    required String role,
    required bool canAdd,
    required bool canEdit,
    required bool canDelete,
  }) async {
    permissionWrites.add(
      MemberPermissionWrite(
        userId: userId,
        role: role,
        canAdd: canAdd,
        canEdit: canEdit,
        canDelete: canDelete,
      ),
    );
    final failure = permissionsError;
    if (failure != null) throw failure;
  }

  @override
  Future<void> removeMember(String userId) async {
    removedMemberIds.add(userId);
    final failure = removeMemberError;
    if (failure != null) throw failure;
  }

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

  @override
  Future<List<FirmMemberSummary>> listMembers() async {
    final failure = membersError;
    if (failure != null) throw failure;
    return members;
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

  /// The error log the app records into; a test reads it to prove a failure it
  /// provoked was remembered.
  final ErrorLog log = ErrorLog();

  /// Creates the database and preferences, and returns the provider overrides.
  ///
  /// [extra] appends the seams a particular test needs — the branched logout,
  /// for instance, which a screen test states its own branch for.
  Future<List<Override>> setUp({
    List<Override> extra = const <Override>[],
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    return <Override>[
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWith((_) async => db),
      authRepositoryProvider.overrideWithValue(auth),
      firmRepositoryProvider.overrideWithValue(firm),
      // main.dart always overrides this, and the view models record into it as
      // they let a failure out; an in-memory log keeps every test file-free.
      errorLogProvider.overrideWithValue(log),
      ...extra,
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

/// A [BackupArchiveSink] that keeps the archive in memory.
///
/// The automatic exports (the logout safety copy, the extended-offline recovery
/// copy) deliberately write without a dialog — they may run when there is nobody
/// to answer a Save-to window — so a widget test stands in for the file system
/// here, never for a dialog.
class RecordingArchiveSink implements BackupArchiveSink {
  /// How many times [write] was called.
  int writes = 0;

  /// The file names the writes used, in order.
  final List<String> fileNames = <String>[];

  /// The bytes of the most recent successful write.
  Uint8List? bytes;

  /// The location the most recent write reported; null while none succeeded.
  String? lastPath;

  /// Refuses every write, as a full disk or a denied permission would.
  bool fail = false;

  @override
  Future<String> write({
    required String fileName,
    required Uint8List bytes,
  }) async {
    writes++;
    fileNames.add(fileName);
    if (fail) throw Exception('the sink refused the write');
    this.bytes = bytes;
    return lastPath = 'C:/tmp/$fileName';
  }
}

/// Overrides the branched logout so a screen test states its own branch, keeps
/// the safety copy in memory, and never pays the production PBKDF2 stretch.
///
/// Everything else mirrors `logoutFlowProvider`: the session is really ended
/// through [AuthViewModel.signOut], so "the logout ended the session and emptied
/// the account caches" is still asserted against the real thing.
Override logoutFlowOverride({
  required bool premium,
  bool online = true,
  RecordingArchiveSink? sink,
}) => logoutFlowProvider.overrideWith((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LogoutFlow(
    db: db,
    premium: premium,
    online: online,
    runBacklogPush: () => ref.read(syncServiceProvider).runBacklogPush(),
    endSession: () => ref.read(authViewModelProvider.notifier).signOut(),
    sink: sink ?? RecordingArchiveSink(),
    kdfIterations: 1,
  );
});

/// Answers the passphrase window every export-before-wipe logout branch opens.
///
/// The window is part of those branches rather than an interruption, so the test
/// asserts it appeared before it fills it in.
Future<void> completeLogoutPassphrase(
  WidgetTester tester,
  AppLocalizations l,
  String passphrase,
) async {
  expect(
    find.text(l.settingsBackupRestore_passphraseTitle),
    findsOneWidget,
    reason: 'the safety copy is written before anything is deleted',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, l.settingsBackupRestore_passphraseLabel),
    passphrase,
  );
  await tester.enterText(
    find.widgetWithText(
      TextFormField,
      l.settingsBackupRestore_passphraseConfirmLabel,
    ),
    passphrase,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(l.settingsBackupRestore_encryptAndSave));
  await tester.pumpAndSettle();
}
