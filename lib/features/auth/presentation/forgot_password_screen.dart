/// Password reset screen: email → emailed recovery code → new password.
///
/// The login mockup links "Forgot Password?" to this flow, but no mockup exists
/// for the screen itself, so it reuses the same card language as the other two
/// auth screens (see [auth_widgets.dart]) rather than inventing a third style.
///
/// The recovery code — not a deep link — is what brings the user back: the
/// emailed link would need a custom URL scheme, a browser round trip and
/// per-platform configuration, while a code works on every device the app runs
/// on. It requires the project's Reset Password e-mail template to include the
/// token.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../data/auth_repository.dart';
import 'auth_viewmodel.dart';
import 'auth_widgets.dart';

/// Which half of the reset the user is in.
enum _ResetStep { requestCode, enterCode }

/// Reset Password screen.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  _ResetStep _step = _ResetStep.requestCode;
  bool _hidePassword = true;
  bool _submitting = false;
  AuthFailureKind? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Requests the recovery code, then moves to the code step.
  Future<void> _sendCode() async {
    if (_submitting) return;
    if (!(_emailForm.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .sendPasswordRecoveryCode(_email.text);
      if (!mounted) return;
      setState(() => _step = _ResetStep.enterCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).auth_recoverySent)),
      );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.kind);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Verifies the code and sets the new password.
  Future<void> _setPassword() async {
    if (_submitting) return;
    if (!(_codeForm.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final viewModel = ref.read(authViewModelProvider.notifier);
      await viewModel.verifyRecoveryCode(
        email: _email.text,
        code: _code.text,
      );
      await viewModel.updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).auth_passwordUpdated),
        ),
      );
      context.go(AppRoutes.login);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.kind);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return AuthScaffold(
      child: AuthCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.auth_forgotTitle,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMd,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.auth_forgotSubtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_step == _ResetStep.requestCode)
              Form(
                key: _emailForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      controller: _email,
                      label: l.auth_emailLabel,
                      hint: l.auth_emailHint,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendCode(),
                      validator: (value) => authEmailError(l, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthErrorBanner(text: authErrorText(l, _error)),
                    AuthPrimaryButton(
                      label: l.auth_sendCodeButton,
                      busy: _submitting,
                      onPressed: _sendCode,
                    ),
                  ],
                ),
              )
            else
              Form(
                key: _codeForm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthTextField(
                      controller: _code,
                      label: l.auth_recoveryCodeLabel,
                      helper: l.auth_recoveryCodeHelper,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (value) => authRequiredError(
                        value,
                        l.auth_validationPasswordRequired,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthTextField(
                      controller: _password,
                      label: l.auth_newPasswordLabel,
                      helper: l.auth_passwordHelper,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _setPassword(),
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
                        ),
                      ),
                      validator: (value) => authPasswordLengthError(l, value),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AuthErrorBanner(text: authErrorText(l, _error)),
                    AuthPrimaryButton(
                      label: l.auth_setPasswordButton,
                      busy: _submitting,
                      onPressed: _setPassword,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            // Plain bold underlined text, not the black button the shared theme
            // would draw: this is a way back, not the screen's primary action.
            Center(
              child: AuthTextLink(
                label: l.auth_backToLogin,
                underline: true,
                onPressed: () => context.go(AppRoutes.login),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
