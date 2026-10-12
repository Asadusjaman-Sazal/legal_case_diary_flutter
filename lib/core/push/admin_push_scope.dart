/// Registers this device for admin payment alerts, and keeps that registration
/// true for as long as the account is an administrator's.
///
/// Mounted once per process above the router (the [AccountRefreshScope] shape):
/// a session-scoped piece of server work that no screen should have to trigger.
/// Three moments bring a device into the server's fan-set, and one takes it out:
///
/// * **A cold start** with a session the device already held — after the first
///   frame, so nothing delays the diary.
/// * **A session that arrives while the app runs** — sign-in, sign-up, Google,
///   keyed on the account id, which also covers switching accounts.
/// * **A new FCM token** — a reinstall, a restore, a long-idle refresh. The row
///   has to follow it or the alerts stop silently, which is the failure nobody
///   reports because it looks like nothing happening.
/// * **Signing out** — [AuthViewModel.signOut] deletes the row, while the session
///   still exists and the row is still the device's own to delete.
///
/// Only a **confirmed administrator** registers anything: the server is asked, not
/// guessed at, so a device the fan-set would never be sent to is not in it. The
/// whole registration is best-effort — a build with no Firebase configuration, a
/// dead socket or an offline phone is not a reason for anything to fail.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_viewmodel.dart';
import '../providers/repository_providers.dart';
import 'push_gateway.dart';

/// Registers this device for admin payment alerts.
class AdminPushScope extends ConsumerStatefulWidget {
  /// Creates the scope around [child].
  const AdminPushScope({required this.child, super.key});

  /// The app subtree; returned unchanged.
  final Widget child;

  @override
  ConsumerState<AdminPushScope> createState() => _AdminPushScopeState();
}

class _AdminPushScopeState extends ConsumerState<AdminPushScope> {
  /// The account the device's current `device_tokens` row belongs to, or null
  /// while this device is registered for nobody.
  String? _registeredUserId;

  /// The token-refresh subscription, once the gateway is initialized.
  StreamSubscription<String>? _refreshes;

  /// Whether a registration is already running.
  ///
  /// The post-frame attempt and the identity listener can both want the same
  /// session on a cold start, and a second concurrent registration would only
  /// duplicate the first.
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: a cold start that restored a session is an arrival
    // no listener sees, because the identity was already there.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_register()));
  }

  @override
  void dispose() {
    unawaited(_refreshes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A session that arrives while the app is running is the ordinary way an
    // administrator gets here, and no post-frame hook sees it. Keying on the
    // account id covers signing in, switching accounts and signing back in.
    ref.listen(authIdentityProvider, (previous, next) {
      if (next == null) {
        // Signed out. The row was removed on the way out, so this device is
        // nobody's; forgetting it makes signing back in register again.
        _registeredUserId = null;
        return;
      }
      if (previous?.userId == next.userId) return;
      if (_registeredUserId == next.userId) return;
      unawaited(_register());
    });
    return widget.child;
  }

  /// Asks the server, then registers this device if the answer is yes.
  Future<void> _register() async {
    if (_registering) return;
    _registering = true;
    try {
      final identity = ref.read(authIdentityProvider);
      if (identity == null) return;
      // The server's own answer, so the fan-set never holds a device it would
      // never send to. False while it loads and false on failure, which is the
      // right side to fail on: alerts nobody asked for are worse than none.
      if (!await ref.read(adminRepositoryProvider).isAdmin()) return;

      final gateway = ref.read(pushGatewayProvider);
      await gateway.initialize();
      // Subscribed after the handlers are wired, and once: a token the device is
      // given later replaces the row this registration writes.
      _refreshes ??= gateway.tokenRefreshes().listen(
        (token) => unawaited(_followTokenChange(token)),
        onError: (Object error, StackTrace stackTrace) =>
            _log('push token stream failed', error, stackTrace),
      );

      final token = await gateway.token();
      if (token == null) return;
      await ref.read(deviceTokenRepositoryProvider).register(token);
      _registeredUserId = identity.userId;
    } catch (error, stackTrace) {
      _log('admin push registration failed', error, stackTrace);
    } finally {
      _registering = false;
    }
  }

  /// Keeps the server's row on the token the device now has.
  Future<void> _followTokenChange(String token) async {
    // Only a device that is already registered follows a new token: a
    // non-administrator has no row to update.
    if (_registeredUserId == null) return;
    try {
      await ref.read(deviceTokenRepositoryProvider).register(token);
    } catch (error, stackTrace) {
      _log('admin push token refresh failed', error, stackTrace);
    }
  }
}

/// Logs and swallows a failure on the registration path.
///
/// It runs unattended on every launch, and push is an enhancement: a backend
/// that is unreachable, an FCM token that is not there yet or a build with no
/// Firebase configuration must never surface as an unhandled error over the
/// user's diary.
void _log(String what, Object error, StackTrace stackTrace) {
  dev.log(what, name: 'push', error: error, stackTrace: stackTrace);
}
