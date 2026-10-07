/// Screens for the app's legal documents — the Privacy Policy and the Terms of
/// Service.
///
/// The documents are authored once, in `docs/legal/`, and bundled from there as
/// assets (see `pubspec.yaml`), so the text the app shows is the text in the
/// repository and cannot drift from it. Two languages ship, one file each, and
/// the screen picks the file from the active locale: `_BN.md` under Bengali and
/// `_EN.md` for everything else.
///
/// Both documents are currently drafts carrying `[TO CONFIRM]` markers — the
/// business decisions listed in them are visible to the reader on purpose, so
/// that nothing is presented as settled while it is not.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/l10n/generated/app_localizations.dart';
import '../settings_sub_page_modal.dart';
import 'markdown_document_view.dart';

/// Which legal document a screen shows.
enum LegalDocument {
  /// `docs/legal/privacy_policy_{LANG}.md`.
  privacyPolicy('privacy_policy'),

  /// `docs/legal/terms_of_service_{LANG}.md`.
  termsOfService('terms_of_service');

  const LegalDocument(this.fileStem);

  /// The shared part of the file name, before `_EN` or `_BN`.
  final String fileStem;

  /// The bundled asset holding this document in [locale]'s language.
  ///
  /// Only two languages exist; anything that is not Bengali reads the English
  /// document, which is a deliberate fallback rather than a missing file.
  String assetPath(Locale locale) =>
      'docs/legal/${fileStem}_${locale.languageCode == 'bn' ? 'BN' : 'EN'}.md';
}

/// Shows one legal document, in the app's current language.
class LegalDocumentScreen extends StatefulWidget {
  /// Which document to show.
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<String>? _document;
  Locale? _loadedLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    // Reload when the language changes, so switching language inside the app
    // swaps the document rather than leaving the old one on screen.
    if (_loadedLocale == locale) return;
    _loadedLocale = locale;
    _document = rootBundle.loadString(widget.document.assetPath(locale));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = switch (widget.document) {
      LegalDocument.privacyPolicy => l.settingsAbout_privacyPolicy,
      LegalDocument.termsOfService => l.settingsAbout_termsOfService,
    };
    // The status bar is the user's own. These documents are top-level routes
    // (they sit outside the shell so Back returns to Sign Up — see the router),
    // so `AppShellRoot`'s own `SafeArea(top: true)` does not reach them and
    // nothing else insets the screen. Without this the Scaffold paints its app
    // bar — white, `AppColors.surface` — up behind the status bar, and the
    // phone's clock and icons sit on that white instead of on the app's own
    // black. Same inset, and same reason, as the paywall's own `SafeArea`.
    return SafeArea(
      top: true,
      bottom: false,
      child: SettingsSubPageModal(
        title: title,
        child: FutureBuilder<String>(
          future: _document,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.edgeMargin),
                child: Text(
                  l.settingsLegal_loadFailed,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }
            final markdown = snapshot.data;
            if (markdown == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return MarkdownDocumentView(markdown: markdown);
          },
        ),
      ),
    );
  }
}
