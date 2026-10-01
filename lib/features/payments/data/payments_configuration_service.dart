/// The payments configuration service — where a user may send MFS money.
///
/// Task 21 Phase 1 / Addendum (Rev 2.4 §5). A receiving number is
/// **configuration**, not code: it belongs to the firm's MFS account and can
/// rotate at any moment, so a release must never be the unit of change. The
/// service therefore resolves numbers from, in order of authority:
///
///   1. **Authenticated remote configuration** (`payment_configuration`, a
///      read-only server table) — authoritative when it answers, so an admin can
///      rotate a number without a release;
///   2. **Validated build defaults** (`--dart-define`) — enough to bootstrap a
///      build, and what a build with no backend uses.
///
/// Rules this honours, all from the task file and the Addendum:
///
///   * values are **display-only** — they are shown to the user and copied to the
///     clipboard, never used to authorize anything (the server's `approve_payment`
///     and the RLS policies are the boundary);
///   * a missing, malformed or unsupported-method entry is **rejected**, so a bad
///     remote row can never replace a good number with a broken one;
///   * on a transient refresh failure the **last validated configuration is
///     retained** rather than blanked out;
///   * numbers are never hardcoded in a widget and never logged.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/repository_providers.dart';

/// The MFS providers this app supports, in display order.
///
/// The one list every other part reads, so a new provider is added in exactly
/// one place. The server's `payment_configuration` check constraint names the
/// same three.
const List<String> paymentProviders = <String>['bkash', 'nagad', 'rocket'];

/// One resolved receiving channel: a provider and the number to send to.
class PaymentMethodConfig {
  /// Creates a channel.
  const PaymentMethodConfig({
    required this.provider,
    required this.receivingNumber,
  });

  /// One of [paymentProviders].
  final String provider;

  /// The MFS number the user sends money to. Display-only.
  final String receivingNumber;
}

/// Where the numbers in a [PaymentsConfiguration] came from.
enum PaymentsConfigurationSource {
  /// Nothing valid was available — the checkout cannot show a number.
  none,

  /// Only the validated build-time defaults were available.
  buildDefaults,

  /// At least one number came from authenticated remote configuration.
  remote,
}

/// A resolved, validated set of receiving numbers.
class PaymentsConfiguration {
  /// Creates a configuration.
  const PaymentsConfiguration({
    required this.methods,
    required this.source,
    this.isStale = false,
  });

  /// The validated channels, keyed by provider. A provider with no valid number
  /// is simply absent.
  final Map<String, PaymentMethodConfig> methods;

  /// Where the numbers came from.
  final PaymentsConfigurationSource source;

  /// True when the last remote refresh failed and an earlier validated set (or
  /// the build defaults) is being shown instead.
  final bool isStale;

  /// True when at least one channel is displayable.
  bool get hasAnyMethod => methods.isNotEmpty;

  /// The channels in [paymentProviders] order.
  List<PaymentMethodConfig> get orderedMethods => <PaymentMethodConfig>[
    for (final provider in paymentProviders)
      if (methods[provider] != null) methods[provider]!,
  ];

  /// A copy flagged stale, used to retain the last good set on a failure.
  PaymentsConfiguration asStale() => PaymentsConfiguration(
    methods: methods,
    source: source,
    isStale: true,
  );
}

/// A Bangladeshi mobile number: `01` then a 3–9 operator digit, then 8 digits.
///
/// Deliberately narrow: it exists to reject a malformed row, and a wrong number
/// is worse than no number.
final RegExp _bdMobileNumber = RegExp(r'^01[3-9]\d{8}$');

/// Whether [provider] is one this app can display.
bool isSupportedPaymentProvider(String provider) =>
    paymentProviders.contains(provider);

/// Whether [number] is a well-formed Bangladeshi mobile number.
///
/// Used for a receiving number and for the sender's phone on the checkout form,
/// so the one format rule is stated once.
bool isValidBdMobileNumber(String number) =>
    _bdMobileNumber.hasMatch(number.trim());

/// Reads remote configuration rows. Abstract so a test never needs a server.
abstract class PaymentsConfigRemote {
  /// Returns the active rows (`provider`, `receiving_number`).
  Future<List<Map<String, dynamic>>> fetchActiveMethods();
}

/// The remote source: the read-only `payment_configuration` table.
class SupabasePaymentsConfigRemote implements PaymentsConfigRemote {
  /// Creates the remote over [client].
  SupabasePaymentsConfigRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchActiveMethods() async {
    final rows = await _client
        .from('payment_configuration')
        .select('provider, receiving_number')
        .eq('is_active', true);
    return rows.map(Map<String, dynamic>.from).toList(growable: false);
  }
}

/// Resolves, validates and caches the receiving numbers.
class PaymentsConfigurationService {
  /// Creates a service over an optional [remote] and optional [buildDefaults].
  ///
  /// A null [remote] means this build has no backend (every test, and a plain
  /// `flutter run`), and the build defaults are all that exist.
  PaymentsConfigurationService({
    PaymentsConfigRemote? remote,
    Map<String, String>? buildDefaults,
  }) : _buildDefaults = buildDefaults ?? _compileTimeDefaults() {
    _remote = remote;
  }

  late final PaymentsConfigRemote? _remote;
  final Map<String, String> _buildDefaults;

  /// The numbers compiled into this build, validated.
  ///
  /// Empty unless a build passes `--dart-define=PAYMENTS_<PROVIDER>_NUMBER=…`,
  /// which is the intended way to bootstrap a build before the server table has
  /// a row.
  static Map<String, String> _compileTimeDefaults() => _validateMap(<String, String>{
    'bkash': const String.fromEnvironment('PAYMENTS_BKASH_NUMBER'),
    'nagad': const String.fromEnvironment('PAYMENTS_NAGAD_NUMBER'),
    'rocket': const String.fromEnvironment('PAYMENTS_ROCKET_NUMBER'),
  });

  /// Loads the configuration, retaining [previous] on a transient failure.
  ///
  /// Remote answers always win for the providers they name; a provider the
  /// remote does not name (or whose row is malformed) keeps its validated build
  /// default rather than disappearing. A remote failure returns [previous] marked
  /// stale when there is one, else the build defaults marked stale.
  Future<PaymentsConfiguration> load({PaymentsConfiguration? previous}) async {
    final defaults = PaymentsConfiguration(
      methods: _toConfigs(_buildDefaults),
      source: _buildDefaults.isEmpty
          ? PaymentsConfigurationSource.none
          : PaymentsConfigurationSource.buildDefaults,
    );

    final remote = _remote;
    if (remote == null) return previous ?? defaults;

    try {
      final remoteNumbers = _validateMap(_rowsToMap(await remote.fetchActiveMethods()));
      if (remoteNumbers.isEmpty) {
        // A reachable but empty table is not a failure: the build defaults (if
        // any) remain the honest answer, and no staleness is signalled.
        return previous ?? defaults;
      }
      final merged = <String, String>{..._buildDefaults, ...remoteNumbers};
      return PaymentsConfiguration(
        methods: _toConfigs(merged),
        source: PaymentsConfigurationSource.remote,
      );
    } on Object {
      // A transient refresh failure must not blank the checkout: keep what was
      // last validated, else fall back to the build defaults, both flagged.
      return (previous ?? defaults).asStale();
    }
  }

  /// Drops unsupported providers and malformed numbers from [input].
  static Map<String, String> _validateMap(Map<String, String> input) {
    final valid = <String, String>{};
    input.forEach((provider, number) {
      if (!isSupportedPaymentProvider(provider)) return;
      if (number.isEmpty) return;
      if (!isValidBdMobileNumber(number)) return;
      valid[provider] = number.trim();
    });
    return valid;
  }

  static Map<String, String> _rowsToMap(List<Map<String, dynamic>> rows) {
    final map = <String, String>{};
    for (final row in rows) {
      final provider = row['provider'];
      final number = row['receiving_number'];
      if (provider is String && number is String) map[provider] = number;
    }
    return map;
  }

  static Map<String, PaymentMethodConfig> _toConfigs(Map<String, String> map) =>
      <String, PaymentMethodConfig>{
        for (final entry in _validateMap(map).entries)
          entry.key: PaymentMethodConfig(
            provider: entry.key,
            receivingNumber: entry.value,
          ),
      };
}

/// The app-wide payments configuration service.
final paymentsConfigurationServiceProvider =
    Provider<PaymentsConfigurationService>((ref) {
      final client = ref.watch(activeSupabaseClientProvider);
      return PaymentsConfigurationService(
        remote: client == null ? null : SupabasePaymentsConfigRemote(client),
      );
    });

/// The loaded configuration, retaining the last good set across a failure.
///
/// An [AsyncNotifier] rather than a plain `FutureProvider` precisely so the
/// retention rule can be honoured: `refresh()` hands the previous value back to
/// the service, so a transient failure re-states the numbers already on screen
/// instead of emptying them.
class PaymentsConfigurationNotifier
    extends AsyncNotifier<PaymentsConfiguration> {
  @override
  Future<PaymentsConfiguration> build() =>
      ref.read(paymentsConfigurationServiceProvider).load();

  /// Re-reads the configuration, retaining the current one on a failure.
  Future<void> refresh() async {
    final previous = state.value;
    state = await AsyncValue.guard(
      () => ref
          .read(paymentsConfigurationServiceProvider)
          .load(previous: previous),
    );
  }
}

/// The single app-wide payments configuration.
final paymentsConfigurationProvider =
    AsyncNotifierProvider<PaymentsConfigurationNotifier, PaymentsConfiguration>(
      PaymentsConfigurationNotifier.new,
    );
