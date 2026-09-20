/// Sharing the app itself (Task 14 Phase 3, plan §9 / Resolved Clarifications)
/// and sharing a file (Task 15's Backup to Google Drive).
///
/// Print and Share stay separate: Print produces a PDF of the current screen,
/// Share hands the *app* to someone else. This file is the only place in the app
/// that may import `share_plus`, so screens and tests never touch the plugin.
///
/// The Addendum asks for a platform service with a user-visible failure
/// fallback; the payload chosen by the user is a text invite, so the service
/// sends `ACTION_SEND` with `text/plain` and copies the invite to the clipboard
/// when no share target answers — the invite is never silently lost.
///
/// [AppShareService.shareFile] reuses the very same sheet — the one Google Drive
/// appears in — for an attached file. There is no clipboard fallback for a file
/// (a clipboard holds text), so a share the platform cannot perform is reported
/// as a failure and the caller says so.
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

  /// Opens the OS share sheet carrying the file at [path] as an attachment.
  ///
  /// [path] must be a real file the platform can read; a `content://` URI is
  /// not attachable, so callers hand over a filesystem path. The sheet is the
  /// same one [shareApp] opens, which is where the user picks Google Drive.
  Future<AppShareOutcome> shareFile({
    required String path,
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

  @override
  Future<AppShareOutcome> shareFile({
    required String path,
    String subject = '',
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          // The diary's container is not a registered type, so the generic
          // binary type keeps Android from renaming or refusing it.
          files: [XFile(path, mimeType: 'application/octet-stream')],
          subject: subject.isEmpty ? null : subject,
          title: subject.isEmpty ? null : subject,
        ),
      );
      return switch (result.status) {
        ShareResultStatus.success => AppShareOutcome.shared,
        ShareResultStatus.dismissed => AppShareOutcome.dismissed,
        // No clipboard fallback: a file cannot be pasted.
        ShareResultStatus.unavailable => AppShareOutcome.failed,
      };
    } catch (_) {
      return AppShareOutcome.failed;
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
