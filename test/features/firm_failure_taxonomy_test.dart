/// The firm domain's own failure vocabulary.
///
/// A firm RPC can fail for reasons a sign-in never can — the owner is off the
/// network, the invite is spent, the account is not a member yet — so it used
/// to reach for `AuthFailureKind` and borrow words that were wrong for it. What
/// is pinned here is that the classification is the domain's own, that the
/// sentence shown to a user is the firm one rather than the sign-in one, and
/// above all that a firm failure is never recorded wearing an auth failure's
/// name: a report saying `AuthFailure(emailNotConfirmed)` about an invite is
/// worse than no report at all, because it sends the reader looking in the
/// wrong place.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_case_diary/core/errors/error_log.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/features/accounts_and_profile/data/firm_repository.dart';
import 'package:legal_case_diary/features/auth/data/auth_repository.dart';
import 'package:legal_case_diary/features/auth/presentation/auth_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l;
  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('classifying what a firm RPC threw', () {
    test('a request that never left the device is a network failure', () {
      // The SDK raises `AuthRetryableFetchException` for a dead socket and for
      // every 5xx alike, and only the absent status tells them apart.
      expect(
        mapFirmFailure(
          AuthRetryableFetchException(message: 'SocketException: host lookup'),
        ).kind,
        FirmFailureKind.network,
      );
      expect(
        mapFirmFailure(const SocketException('No connection')).kind,
        FirmFailureKind.network,
      );
      expect(mapFirmFailure(TimeoutException('took too long')).kind,
          FirmFailureKind.network);
    });

    test('a 5xx is the server at fault, never the connection', () {
      // A mail relay refusing its own credentials is not a network problem,
      // and telling a user on a perfect connection to check their internet
      // sends them to the wrong place.
      expect(
        mapFirmFailure(
          AuthRetryableFetchException(message: 'Error', statusCode: '500'),
        ).kind,
        FirmFailureKind.server,
      );
      expect(
        mapFirmFailure(const PostgrestException(message: 'boom', code: '503'))
            .kind,
        FirmFailureKind.server,
      );
      // No status at all from PostgREST means the request never completed.
      expect(
        mapFirmFailure(const PostgrestException(message: 'boom')).kind,
        FirmFailureKind.server,
      );
    });

    test('a 401 or 403 is the account, not the connection', () {
      for (final status in ['401', '403', '425']) {
        expect(
          mapFirmFailure(
            PostgrestException(message: 'refused', code: status),
          ).kind,
          FirmFailureKind.unauthorized,
        );
      }
    });

    test('the rate limiter is its own kind, however the SDK names it', () {
      expect(
        mapFirmFailure(
          const AuthException('Too many attempts', statusCode: '429'),
        ).kind,
        FirmFailureKind.tooManyAttempts,
      );
      expect(
        mapFirmFailure(
          const AuthException('retry later', code: 'rate_limit_exceeded'),
        ).kind,
        FirmFailureKind.tooManyAttempts,
      );
    });

    test('anything unrecognised is unknown and keeps its cause', () {
      // The cause is kept for debugging and never shown and never logged; the
      // label carries the kind alone.
      final failure = mapFirmFailure(StateError('unexpected'));
      expect(failure.kind, FirmFailureKind.unknown);
      expect(failure.cause, isA<StateError>());
      expect(failure.diagnosticLabel, 'FirmFailure(unknown)');
    });

    test('a failure that is already a firm failure passes through', () {
      // Wrapping must not re-label: the screen caught an invite refusal and
      // asked the mapper again, and the answer has to stay the same kind.
      const original = FirmFailure(FirmFailureKind.alreadyMember);
      expect(mapFirmFailure(original).kind, FirmFailureKind.alreadyMember);
    });
  });

  group('wording a firm failure', () {
    test('the firm sentence is used, never the sign-in one', () {
      // "Sign-In Is Not Available In This Build" is a true sentence about a
      // sign-in and a useless one about firm management; each of these kinds
      // has a word of its own where the auth wording would mislead.
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.server)),
        l.firm_errorServer,
      );
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.unauthorized)),
        l.firm_errorUnauthorized,
      );
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.unavailable)),
        l.firm_errorUnavailable,
      );
      expect(l.firm_errorUnavailable, isNot(l.auth_errorUnavailable));
    });

    test('the shared sentences are still shared', () {
      // No connection, too many attempts, the premium gate and the owner being
      // offline mean exactly one thing in either domain, so they are not
      // reworded twice.
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.network)),
        l.auth_errorNetwork,
      );
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.tooManyAttempts)),
        l.auth_errorTooManyAttempts,
      );
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.premiumRequired)),
        l.auth_errorPremiumRequired,
      );
    });

    test('the creation gate names the Firm plan, not the premium gate', () {
      // Pro is paid, so "Firm Mode requires an active premium subscription"
      // would be untrue for a Pro owner refused at the gate. The server answers
      // `firm_tier_required` and the app says which plan is missing instead of
      // falling back to the generic retry sentence.
      expect(
        failureText(l, const FirmFailure(FirmFailureKind.firmTierRequired)),
        l.firm_errorTierRequired,
      );
      expect(l.firm_errorTierRequired, isNot(l.auth_errorPremiumRequired));
    });

    test('an auth failure still reads as one, and a stranger as unknown', () {
      expect(
        failureText(l, const AuthFailure(AuthFailureKind.invalidCode)),
        l.auth_errorInvalidCode,
      );
      expect(failureText(l, null), isNull);
      expect(failureText(l, StateError('unexpected')), l.auth_errorUnknown);
    });

    test('a seat refusal is worded with its count, not as a system error', () {
      // §2.1 and §5.4 both quote a number, and the number is the whole point of
      // the sentence: "its own diary (12 cases)" tells the lawyer what the app
      // found, where "join failed" leaves them stuck with no way forward.
      expect(
        failureText(l, const InviteRefusal(InviteRefusalKind.ownDiary, count: 12)),
        l.auth_errorOwnDiary(12),
      );
      expect(
        failureText(l, const InviteRefusal(InviteRefusalKind.seatsFull, count: 5)),
        l.auth_errorSeatsFull(5),
      );
      // The count is interpolated, never appended: nothing generic may leak in.
      expect(
        failureText(l, const InviteRefusal(InviteRefusalKind.ownDiary, count: 12)),
        contains('12'),
      );
    });

    test('a seat refusal with no count keeps a full sentence', () {
      expect(
        failureText(l, const InviteRefusal(InviteRefusalKind.ownDiary)),
        l.auth_errorOwnDiaryNoCount,
      );
      expect(
        failureText(l, const InviteRefusal(InviteRefusalKind.seatsFull)),
        l.auth_errorSeatsFullNoCount,
      );
    });

    test('a firm failure is never logged as an auth failure', () {
      // The one property the report depends on: the label a user hands over
      // names the domain the fault is in.
      for (final kind in FirmFailureKind.values) {
        expect(
          describeErrorForLog(FirmFailure(kind)),
          'FirmFailure(${kind.name})',
        );
        expect(
          describeErrorForLog(FirmFailure(kind)),
          isNot(contains('AuthFailure')),
        );
      }
    });
  });
}
