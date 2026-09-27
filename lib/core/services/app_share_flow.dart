/// The Share action's user-facing path: hand the app invite to the platform and
/// say what happened.
///
/// The navigation drawer offers Share on every screen that carries one — the
/// case screens and Settings — so the action lives here once instead of at each
/// call site, where one of them did forget it and left a dead tap. It sits
/// beside [AppShareService], which owns the platform call itself, and mirrors
/// `core/print/print_flow.dart`, which does the same job for Print.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/print_providers.dart';
import 'app_share_service.dart';

/// Shares the app itself and reports anything the user must know.
///
/// The invite text and its subject come from the ARB, so what is shared is
/// localized. Only the two outcomes that would otherwise be invisible are said
/// out loud — the clipboard fallback (no share target answered) and a failure —
/// exactly as the case screens' Print flow words its own outcomes.
Future<void> shareAppInvite(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final outcome = await ref
      .read(appShareServiceProvider)
      .shareApp(
        message: l.appShare_invite(appStoreUrl),
        subject: l.appShare_subject,
      );
  if (!context.mounted) return;

  switch (outcome) {
    case AppShareOutcome.copiedToClipboard:
      _say(context, l.appShare_copied);
    case AppShareOutcome.failed:
      _say(context, l.appShare_failed);
    case AppShareOutcome.shared:
    case AppShareOutcome.dismissed:
      break;
  }
}

/// Shows [message] over the current screen.
void _say(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
