/// Login screen: the app's single sign-in screen, for everyone.
///
/// Body mirrors `mockup_html_screens/settings_onlineSync_login/code.html`: the
/// centred card with the round brand mark, "Legal Case Diary" and the subtitle,
/// the Email and Password fields (the password with its show/hide toggle and
/// the "Forgot Password?" link beside the label), the Login button, the "Or
/// Continue With" divider and the Google button, and the Sign Up line beneath
/// the card.
///
/// The router decides whether this screen is shown at all: a device whose local
/// database already holds the user's own cases is never redirected here, and a
/// device with nothing on it opens here because there is nothing to lock away
/// (see `auth_gate.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../accounts_and_profile/data/firm_repository.dart';
import '../data/auth_repository.dart';
import '../data/local_auth_service.dart';
import 'auth_viewmodel.dart';
import 'auth_widgets.dart';

/// Unified sign-in screen (Email + Password).
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidePassword = true;
  bool _submitting = false;
  AuthFailureKind? _error;
  String? _pendingInviteNote;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Signs in, then finishes any join-a-firm onboarding left pending.
  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
      _pendingInviteNote = null;
    });

    try {
      await ref
          .read(authViewModelProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
      await _finishPendingJoin();
      if (!mounted) return;
      // Landing on the configured default page is the router's job: the gate
      // redirect fires as soon as the identity changes.
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.kind);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Redeems an invite code left over from an interrupted join-a-firm sign-up.
  ///
  /// Best effort on purpose: a failure here must not fail the sign-in, and it
  /// must not lose the code — the firm screens offer to finish it later.
  Future<void> _finishPendingJoin() async {
    final viewModel = ref.read(authViewModelProvider.notifier);
    if (ref.read(localAuthServiceProvider).pendingInviteCode == null) return;
    try {
      await viewModel.redeemPendingInvite();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _pendingInviteNote = authErrorText(
          AppLocalizations.of(context),
          failure.kind,
        ),
      );
    } on FirmFailure catch (failure) {
      // The redemption is a firm operation, so it answers in firm terms; an
      // uncaught one here would have reached the global capture instead of the
      // note the user is waiting to read.
      if (!mounted) return;
      setState(
        () => _pendingInviteNote = firmErrorText(
          AppLocalizations.of(context),
          failure.kind,
        ),
      );
    }
  }

  /// Signs in with Google.
  Future<void> _submitGoogle() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authViewModelProvider.notifier).signInWithGoogle();
      await _finishPendingJoin();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      // A dismissed sheet is not an error worth shouting about.
      setState(
        () => _error = failure.kind == AuthFailureKind.cancelled
            ? null
            : failure.kind,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthBrandHeader(subtitle: l.auth_loginSubtitle),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _email,
                  label: l.auth_emailLabel,
                  hint: l.auth_emailHint,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: (value) => authEmailError(l, value),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthTextField(
                  controller: _password,
                  label: l.auth_passwordLabel,
                  hint: l.auth_passwordHint,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    tooltip: _hidePassword
                        ? l.auth_showPassword
                        : l.auth_hidePassword,
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  validator: (value) => authPasswordRequiredError(l, value),
                ),
                // The recovery action sits under the password box rather than in
                // the label row, as bold plain text: no background, no underline.
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: AuthTextLink(
                    label: l.auth_forgotPassword,
                    onPressed: () => context.push(AppRoutes.forgotPassword),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AuthErrorBanner(text: authErrorText(l, _error)),
                AuthErrorBanner(text: _pendingInviteNote),
                AuthPrimaryButton(
                  label: l.auth_loginButton,
                  busy: _submitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthDivider(label: l.auth_orContinueWith),
          const SizedBox(height: AppSpacing.md),
          AuthGoogleButton(
            label: l.auth_googleLogin,
            enabled: !_submitting,
            onPressed: _submitGoogle,
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthSwitchLine(
            prompt: l.auth_noAccount,
            action: l.auth_signUpLink,
            onTap: () => context.push(AppRoutes.signup),
          ),
        ],
      ),
    );
  }
}
