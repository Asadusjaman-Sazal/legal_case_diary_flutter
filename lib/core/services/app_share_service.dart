/// Sharing the app itself (Task 14 Phase 3, plan §9 / Resolved Clarifications).
///
/// Print and Share stay separate: Print produces a PDF of the current screen,
/// Share hands the *app* to someone else. This file is the only place in the app
/// that may import `share_plus`, so screens and tests never touch the plugin.
///
/// The Addendum asks for a platform service with a user-visible failure
/// fallback; the payload chosen by the user is a text invite, so the service
/// sends `ACTION_SEND` with `text/plain` and copies the invite to the clipboard
/// when no share target answers — the invite is never silently lost.
library;

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Store listing used by the invite.
///
/// FLAGGED: the app is not published yet (Part A is fully offline and there is
/// no store listing), so this is the placeholder the user chose — the single
/// line to change the day the app goes live.
const String appStoreUrl =
    'https://play.google.com/store/apps/details?id=com.legalcasediary.app';

/// What a Share action did, so the caller can word its message.
enum AppShareOutcome {
  /// The share sheet opened and the user picked a target.
  shared,

  /// The share sheet opened and was dismissed.
  dismissed,

  /// No share target answered, so the invite went to the clipboard instead.
  copiedToClipboard,

  /// Sharing failed outright; the caller shows a recoverable message.
  failed,
}

/// Shares the app through the platform's own sharing utility.
abstract interface class AppShareService {
  /// Opens the OS share sheet carrying [message].
  Future<AppShareOutcome> shareApp({
    required String message,
    String subject = '',
  });
}

/// The Android implementation, backed by `share_plus`.
class PlatformAppShareService implements AppShareService {
  /// Creates the service.
  const PlatformAppShareService();

  @override
  Future<AppShareOutcome> shareApp({
    required String message,
    String subject = '',
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: subject.isEmpty ? null : subject,
          title: subject.isEmpty ? null : subject,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => AppShareOutcome.shared,
        ShareResultStatus.dismissed => AppShareOutcome.dismissed,
        ShareResultStatus.unavailable => _copyInstead(message),
      };
    } catch (_) {
      return _copyInstead(message);
    }
  }

  /// The Addendum's fallback: no share target means the invite is copied and
  /// the caller says so, rather than the tap doing nothing.
  Future<AppShareOutcome> _copyInstead(String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: message));
      return AppShareOutcome.copiedToClipboard;
    } catch (_) {
      return AppShareOutcome.failed;
    }
  }
}
