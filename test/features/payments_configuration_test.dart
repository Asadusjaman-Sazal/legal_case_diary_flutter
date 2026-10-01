/// Tests for [PaymentsConfigurationService] — Task 21 Phase 1 / Addendum.
///
/// The Addendum asks for missing/invalid/rotation coverage, and these are those
/// tests: a malformed or unsupported remote row can never replace a good number,
/// a remote answer rotates a number without a release, and a transient refresh
/// failure retains the last validated configuration instead of blanking it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/payments/data/payments_configuration_service.dart';

/// A remote that returns a fixed set of rows, or throws.
class _FakeRemote implements PaymentsConfigRemote {
  _FakeRemote({this.rows = const <Map<String, dynamic>>[], this.fail = false});

  final List<Map<String, dynamic>> rows;

  /// When true, [fetchActiveMethods] throws to simulate a transient failure.
  final bool fail;

  @override
  Future<List<Map<String, dynamic>>> fetchActiveMethods() async {
    if (fail) throw Exception('network down');
    return rows;
  }
}

void main() {
  group('validation', () {
    test('accepts a well-formed Bangladeshi mobile number', () {
      expect(isValidBdMobileNumber('01712345678'), isTrue);
      expect(isValidBdMobileNumber('01912345678'), isTrue);
      expect(isValidBdMobileNumber(' 01812345678 '), isTrue);
    });

    test('rejects missing, short or non-mobile values', () {
      expect(isValidBdMobileNumber(''), isFalse);
      expect(isValidBdMobileNumber('0171234567'), isFalse);
      expect(isValidBdMobileNumber('01212345678'), isFalse);
      expect(isValidBdMobileNumber('abcdefghijk'), isFalse);
    });

    test('only the three supported providers are accepted', () {
      expect(isSupportedPaymentProvider('bkash'), isTrue);
      expect(isSupportedPaymentProvider('nagad'), isTrue);
      expect(isSupportedPaymentProvider('rocket'), isTrue);
      expect(isSupportedPaymentProvider('paypal'), isFalse);
      expect(isSupportedPaymentProvider(''), isFalse);
    });
  });

  group('resolution', () {
    test('no remote means the validated build defaults', () async {
      final service = PaymentsConfigurationService(
        buildDefaults: {'bkash': '01712345678', 'nagad': 'bad'},
      );

      final config = await service.load();

      expect(config.source, PaymentsConfigurationSource.buildDefaults);
      expect(config.methods.keys, ['bkash']);
      expect(config.methods['bkash']!.receivingNumber, '01712345678');
      expect(config.isStale, isFalse);
    });

    test('a remote answer rotates a number without a release', () async {
      final service = PaymentsConfigurationService(
        remote: _FakeRemote(
          rows: [
            {'provider': 'bkash', 'receiving_number': '01911111111'},
            {'provider': 'nagad', 'receiving_number': '01812345678'},
          ],
        ),
        buildDefaults: {'bkash': '01712345678'},
      );

      final config = await service.load();

      expect(config.source, PaymentsConfigurationSource.remote);
      expect(config.methods['bkash']!.receivingNumber, '01911111111');
      expect(config.methods['nagad']!.receivingNumber, '01812345678');
      // Remote-named providers and build-default-only providers merge.
      expect(config.orderedMethods.map((m) => m.provider), ['bkash', 'nagad']);
    });

    test('a malformed or unsupported remote row is rejected', () async {
      final service = PaymentsConfigurationService(
        remote: _FakeRemote(
          rows: [
            {'provider': 'bkash', 'receiving_number': 'not-a-number'},
            {'provider': 'paypal', 'receiving_number': '01712345678'},
            {'provider': 'rocket', 'receiving_number': '01912345678'},
          ],
        ),
        buildDefaults: {'bkash': '01712345678'},
      );

      final config = await service.load();

      // The bad bkash row did not replace the good default; paypal is dropped.
      expect(config.methods['bkash']!.receivingNumber, '01712345678');
      expect(config.methods.containsKey('paypal'), isFalse);
      expect(config.methods['rocket']!.receivingNumber, '01912345678');
    });

    test('an empty but reachable table keeps the build defaults', () async {
      final service = PaymentsConfigurationService(
        remote: _FakeRemote(),
        buildDefaults: {'bkash': '01712345678'},
      );

      final config = await service.load();

      expect(config.source, PaymentsConfigurationSource.buildDefaults);
      expect(config.methods['bkash']!.receivingNumber, '01712345678');
      expect(config.isStale, isFalse);
    });

    test('a transient failure retains the last validated configuration', () async {
      final service = PaymentsConfigurationService(
        remote: _FakeRemote(
          rows: [
            {'provider': 'bkash', 'receiving_number': '01911111111'},
          ],
        ),
      );
      final first = await service.load();

      final failing = PaymentsConfigurationService(
        remote: _FakeRemote(fail: true),
        buildDefaults: const <String, String>{},
      );
      final retained = await failing.load(previous: first);

      expect(retained.methods['bkash']!.receivingNumber, '01911111111');
      expect(retained.isStale, isTrue);
    });

    test('a transient failure with nothing previous falls back, flagged',
        () async {
      final service = PaymentsConfigurationService(
        remote: _FakeRemote(fail: true),
        buildDefaults: {'bkash': '01712345678'},
      );

      final config = await service.load();

      expect(config.methods['bkash']!.receivingNumber, '01712345678');
      expect(config.isStale, isTrue);
    });

    test('no numbers at all is an honest empty configuration', () async {
      final service = PaymentsConfigurationService(
        buildDefaults: const <String, String>{},
      );

      final config = await service.load();

      expect(config.hasAnyMethod, isFalse);
      expect(config.source, PaymentsConfigurationSource.none);
    });
  });
}
