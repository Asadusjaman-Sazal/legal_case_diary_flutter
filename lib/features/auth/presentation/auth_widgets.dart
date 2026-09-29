/// Shared building blocks for the auth screens.
///
/// The Login and Sign Up mockups (`settings_onlineSync_login`,
/// `settings_onlineSync_signup`) are two views of the same card language: a
/// light `#F8FAFC` page, one white rounded card with an outline border, an
/// optional brand header, underlined filled text fields, a black full-width
/// primary button, an "Or Continue With" divider and a Google button, and a
/// final line that switches to the other screen.
///
/// Keeping that language in one file means the two screens cannot drift apart,
/// and the password-reset screen reuses the same fields and buttons.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../data/auth_repository.dart';

/// Width the auth card settles on (the mockups' `max-w-[400px]` / `420px`).
const double authCardMaxWidth = 420.0;

/// Height of the auth screens' primary and secondary buttons.
const double authButtonHeight = 48.0;

/// Page shell: the light background, a safe area, and one centred column that
/// scrolls when the keyboard is up.
class AuthScaffold extends StatelessWidget {
  /// Creates the shell.
  const AuthScaffold({required this.child, super.key});

  /// Card contents.
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.edgeMargin),
          child: ConstrainedBox(
            // Centres the card in the available height without ever clipping it
            // when the keyboard shrinks the viewport.
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - 2 * AppSpacing.edgeMargin),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: authCardMaxWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The white bordered card both auth screens are built from.
class AuthCard extends StatelessWidget {
  /// Creates a card around [child].
  const AuthCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.clip = false,
    super.key,
  });

  /// Card contents.
  final Widget child;

  /// Inner padding; the sign-up card sets its own per section.
  final EdgeInsets padding;

  /// Whether to clip the contents to the card's rounded corners (the sign-up
  /// card's footer strip does).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outlineVariant),
    );
    if (clip) {
      return Container(
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );
  }
}

/// The sign-in card's header: round brand mark, app name and subtitle.
class AuthBrandHeader extends StatelessWidget {
  /// Creates the header.
  const AuthBrandHeader({required this.subtitle, super.key});

  /// Line under the app name.
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance,
            color: AppColors.onPrimary,
            size: 24,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.appName,
          textAlign: TextAlign.center,
          style: AppTypography.headlineLg.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The sign-up card's header: a gavel, the app name in a row, then the title.
class AuthSignupHeader extends StatelessWidget {
  /// Creates the header.
  const AuthSignupHeader({
    required this.title,
    required this.subtitle,
    super.key,
  });

  /// Card title.
  final String title;

  /// Line under the title.
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.gavel, size: 28, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            // Flexible so a larger text scale wraps the wordmark instead of
            // overflowing the card.
            Flexible(
              child: Text(
                l.appName,
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTypography.headlineLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One labelled auth field, with optional in-field trailing control, an
/// optional control beside the label, a helper line and validation.
class AuthTextField extends StatelessWidget {
  /// Creates a field.
  const AuthTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.trailing,
    this.labelTrailing,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  /// Field controller.
  final TextEditingController controller;

  /// Label drawn above the field.
  final String label;

  /// Placeholder text.
  final String? hint;

  /// Helper line below the field.
  final String? helper;

  /// Validator for the surrounding [Form].
  final String? Function(String?)? validator;

  /// Whether the text is hidden (password).
  final bool obscureText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Keyboard action.
  final TextInputAction? textInputAction;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Called when the keyboard action is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Control drawn inside the field, at its trailing edge.
  final Widget? trailing;

  /// Control drawn at the trailing edge of the label row.
  final Widget? labelTrailing;

  /// Text capitalization.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ?labelTrailing,
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        onFieldSubmitted: onSubmitted,
        style: AppTypography.bodyMd,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: trailing,
          suffixIconConstraints: const BoxConstraints(minWidth: 40),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          helper!,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

/// The black, full-width primary button the auth mockups use.
class AuthPrimaryButton extends StatelessWidget {
  /// Creates the button.
  const AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  /// Button label.
  final String label;

  /// Action.
  final VoidCallback onPressed;

  /// Whether to replace the label with a spinner.
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: authButtonHeight,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        disabledBackgroundColor: AppColors.secondary,
        disabledForegroundColor: AppColors.onSecondary,
        textStyle: AppTypography.titleMd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.onSecondary,
              ),
            )
          : Text(label),
    ),
  );
}

/// The bordered Google button, with the brand mark and its label.
class AuthGoogleButton extends StatelessWidget {
  /// Creates the button.
  const AuthGoogleButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  /// Button label.
  final String label;

  /// Action.
  final VoidCallback onPressed;

  /// Whether the button is tappable.
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: authButtonHeight,
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: const GoogleMark(size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        backgroundColor: AppColors.surfaceContainerLowest,
        side: const BorderSide(color: AppColors.outlineVariant),
        textStyle: AppTypography.titleMd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
      ),
    ),
  );
}

/// The "Or Continue With" divider.
class AuthDivider extends StatelessWidget {
  /// Creates the divider.
  const AuthDivider({required this.label, super.key});

  /// Divider label.
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.outlineVariant, height: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.outlineVariant, height: 1)),
    ],
  );
}

/// A text action inside an auth card: bold, underlined when asked for, and
/// deliberately **without a background**.
///
/// The shared theme paints every `TextButton` black with a white label, which is
/// right for the Settings surface but wrong here: both auth mockups draw these
/// actions as plain text links (`font-title-md text-secondary`), so the style is
/// overridden at the call sites that mean "link" rather than in the theme every
/// other screen depends on.
class AuthTextLink extends StatelessWidget {
  /// Creates a link reading [label].
  const AuthTextLink({
    required this.label,
    required this.onPressed,
    this.underline = false,
    super.key,
  });

  /// Link text.
  final String label;

  /// Action.
  final VoidCallback onPressed;

  /// Whether the text is underlined. The switch lines are (the mockups underline
  /// them on hover, and the underline is kept permanently here); the inline
  /// "Forgot Password?" action is not.
  final bool underline;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.secondary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: AppTypography.titleMd.copyWith(
        color: AppColors.secondary,
        decoration: underline ? TextDecoration.underline : null,
        decorationColor: AppColors.secondary,
      ),
    ),
  );
}

/// The "Don't have an account? Sign Up" line under the card.
class AuthSwitchLine extends StatelessWidget {
  /// Creates the line.
  const AuthSwitchLine({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  /// Leading sentence.
  final String prompt;

  /// Tappable action label.
  final String action;

  /// Action.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: Text(
          prompt,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      AuthTextLink(label: action, onPressed: onTap, underline: true),
    ],
  );
}

/// An inline, tappable link to one of the bundled legal documents.
///
/// The sign-up card names the Terms of Service and the Privacy Policy inside
/// its checkbox sentence and both open the same screens Settings > About opens,
/// so the text the user consents to is the text the app ships.
class AuthDocumentLink extends StatelessWidget {
  /// Creates a link to [route] reading [label].
  const AuthDocumentLink({
    required this.label,
    required this.route,
    this.style,
    super.key,
  });

  /// Link text.
  final String label;

  /// Route pushed when tapped.
  final String route;

  /// Text style; defaults to the app's secondary link look.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(route),
    child: Text(
      label,
      style:
          style ??
          AppTypography.bodySm.copyWith(
            color: AppColors.secondary,
            decoration: TextDecoration.underline,
          ),
    ),
  );
}

/// The inline error strip: the screen's typed failure, in its own words.
///
/// Renders nothing when [text] is null, so a screen can drop it into a column
/// unconditionally and get no layout hole when there is no error.
class AuthErrorBanner extends StatelessWidget {
  /// Creates a banner.
  const AuthErrorBanner({required this.text, super.key});

  /// Localized message, or null for "no error".
  final String? text;

  @override
  Widget build(BuildContext context) {
    final message = text;
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Google "G", drawn from the mark's own geometry.
///
/// The mockups embed the official four-path SVG; porting those paths keeps the
/// button matching them without shipping a binary asset or adding an SVG
/// renderer for one glyph.
class GoogleMark extends StatelessWidget {
  /// Creates the mark at [size] logical pixels square.
  const GoogleMark({this.size = 20, super.key});

  /// Side length of the square mark.
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GoogleMarkPainter());
}

/// Paints the four Google brand arcs from their SVG paths.
class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  // Colours are the mark's own, not the app palette: it is a third-party brand.
  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    final paint = Paint()..style = PaintingStyle.fill;
    // Paths are the mockup SVG's own coordinates in a 24x24 viewBox.
    canvas
      ..save()
      ..scale(scale);

    canvas.drawPath(_bluePath(), paint..color = _blue);
    canvas.drawPath(_greenPath(), paint..color = _green);
    canvas.drawPath(_yellowPath(), paint..color = _yellow);
    canvas.drawPath(_redPath(), paint..color = _red);

    canvas.restore();
  }

  Path _bluePath() => Path()
    ..moveTo(22.56, 12.25)
    ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10)
    ..lineTo(12, 10)
    ..lineTo(12, 14.26)
    ..lineTo(17.92, 14.26)
    ..cubicTo(17.66, 15.63, 16.88, 16.8, 15.72, 17.58)
    ..lineTo(15.72, 20.34)
    ..lineTo(19.28, 20.34)
    ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
    ..close();

  Path _greenPath() => Path()
    ..moveTo(12, 23)
    ..cubicTo(14.97, 23, 17.46, 22.02, 19.28, 20.34)
    ..lineTo(15.72, 17.58)
    ..cubicTo(14.74, 18.24, 13.48, 18.64, 12, 18.64)
    ..cubicTo(9.14, 18.64, 6.72, 16.71, 5.84, 14.12)
    ..lineTo(2.16, 14.12)
    ..lineTo(2.16, 16.96)
    ..cubicTo(3.98, 20.58, 7.7, 23, 12, 23)
    ..close();

  Path _yellowPath() => Path()
    ..moveTo(5.84, 14.12)
    ..cubicTo(5.61, 13.44, 5.49, 12.73, 5.49, 12)
    ..cubicTo(5.49, 11.27, 5.61, 10.56, 5.84, 9.88)
    ..lineTo(5.84, 7.04)
    ..lineTo(2.16, 7.04)
    ..cubicTo(1.41, 8.53, 1, 10.22, 1, 12)
    ..cubicTo(1, 13.78, 1.41, 15.47, 2.16, 16.96)
    ..lineTo(5.84, 14.12)
    ..close();

  Path _redPath() => Path()
    ..moveTo(12, 5.36)
    ..cubicTo(13.62, 5.36, 15.07, 5.92, 16.22, 7.02)
    ..lineTo(19.36, 3.88)
    ..cubicTo(17.46, 2.1, 14.97, 1, 12, 1)
    ..cubicTo(7.7, 1, 3.98, 3.42, 2.16, 7.04)
    ..lineTo(5.84, 9.88)
    ..cubicTo(6.72, 7.29, 9.14, 5.36, 12, 5.36)
    ..close();

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Form validation and error copy
// ---------------------------------------------------------------------------

/// The localized message for a failure kind, or null when there is nothing to
/// show (a cancelled Google sheet is not an error).
String? authErrorText(AppLocalizations l, AuthFailureKind? kind) => switch (kind) {
  null => null,
  AuthFailureKind.cancelled => null,
  AuthFailureKind.invalidCredentials => l.auth_errorInvalidCredentials,
  AuthFailureKind.emailNotConfirmed => l.auth_errorEmailNotConfirmed,
  AuthFailureKind.emailInUse => l.auth_errorEmailInUse,
  AuthFailureKind.weakPassword => l.auth_errorWeakPassword,
  AuthFailureKind.rateLimited => l.auth_errorRateLimited,
  AuthFailureKind.invalidCode => l.auth_errorInvalidCode,
  AuthFailureKind.tooManyAttempts => l.auth_errorTooManyAttempts,
  AuthFailureKind.firmAdminOffline => l.auth_errorFirmAdminOffline,
  AuthFailureKind.alreadyMember => l.auth_errorAlreadyMember,
  AuthFailureKind.accountMismatch => l.auth_errorAccountMismatch,
  AuthFailureKind.network => l.auth_errorNetwork,
  AuthFailureKind.unavailable => l.auth_errorUnavailable,
  AuthFailureKind.unknown => l.auth_errorUnknown,
};

/// Validates an email field, or returns null when it is usable.
String? authEmailError(AppLocalizations l, String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return l.auth_validationEmailRequired;
  // One '@' with something either side and a dotted domain: the same shape the
  // server accepts, checked before a round trip.
  final looksValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
  return looksValid ? null : l.auth_validationEmailInvalid;
}

/// Validates the sign-in password field (presence only: the server judges it).
String? authPasswordRequiredError(AppLocalizations l, String? value) =>
    (value == null || value.isEmpty) ? l.auth_validationPasswordRequired : null;

/// Validates a new password the user is choosing.
String? authPasswordLengthError(AppLocalizations l, String? value) {
  final text = value ?? '';
  if (text.isEmpty) return l.auth_validationPasswordRequired;
  return text.length < 8 ? l.auth_validationPasswordTooShort : null;
}

/// Validates the confirmation field against the password it repeats.
///
/// The two are compared as typed, with no trimming: a password may legitimately
/// end in a space, and "they match" has to mean exactly that.
String? authConfirmPasswordError(
  AppLocalizations l,
  String password,
  String? value,
) {
  final text = value ?? '';
  if (text.isEmpty) return l.auth_validationPasswordConfirmRequired;
  return text == password ? null : l.auth_validationPasswordMismatch;
}

/// Validates a required free-text field with [message].
String? authRequiredError(String? value, String message) =>
    (value == null || value.trim().isEmpty) ? message : null;
