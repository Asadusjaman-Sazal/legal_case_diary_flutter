/// Local profile store.
///
/// The five fields edited on Settings > Account & Profile > Profile — full name,
/// bar association, membership number, office address and mobile number — are
/// kept as one persisted record, so every screen that shows the user (the
/// navigation drawer header, the printed case sheet, the client message
/// templates) reads the same values and they survive app restarts.
///
/// A new install starts **blank**. Nothing here is seeded, because the values
/// the mockups show (`Asadusjaman`, `Dhaka Bar Association`, `1557`, …) are
/// sample data: seeded, they would show one user's details to every other user.
/// The editor's hints come from the ARB, and empty values render as `—`.
///
/// This record is what the screen edits and what every reader shows. It travels
/// both ways through `ProfileRepository`: the account's copy (`profiles`) fills
/// the fields this device has left blank, never overwriting one the user typed
/// here, and the device's whole record — the name included — is mirrored back
/// onto the account's own row on save.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key holding the saved profile record as JSON.
const String profileFieldsKey = 'profile_fields';

/// Preference key recording that a detail save could not reach the account yet.
///
/// A local operational value, kept on the device only: the account's copy lives
/// on `profiles`, which is never queued through `sync_queue`.
const String profileDetailsPendingKey = 'profile_details_pending';

/// Legacy key that held only the full name (installs before this record).
const String profileFullNameKey = 'profile_full_name';

/// The user's own profile details. Every field is blank until they fill it in;
/// the mobile number is stored exactly as typed — local form, with its leading
/// `0` and no country code (the form's fixed `+88` prefix carries that).
class ProfileFields {
  /// Creates a record; every field defaults to blank.
  const ProfileFields({
    this.fullName = '',
    this.barAssociation = '',
    this.membershipNo = '',
    this.officeAddress = '',
    this.mobile = '',
  });

  /// Reads a record from its stored JSON; missing keys stay blank.
  factory ProfileFields.fromJson(Map<String, dynamic> json) => ProfileFields(
    fullName: json['fullName'] as String? ?? '',
    barAssociation: json['barAssociation'] as String? ?? '',
    membershipNo: json['membershipNo'] as String? ?? '',
    officeAddress: json['officeAddress'] as String? ?? '',
    mobile: json['mobile'] as String? ?? '',
  );

  /// A record with nothing filled in — what a new install reads.
  static const ProfileFields blank = ProfileFields();

  /// The user's full name (drawn in the drawer header and the case messages).
  final String fullName;

  /// The bar association the user is enrolled in.
  final String barAssociation;

  /// The user's bar membership/registration number.
  final String membershipNo;

  /// The user's chamber/office address.
  final String officeAddress;

  /// The user's mobile number as typed locally (leading `0`, no country code).
  final String mobile;

  /// Whether any of the four details the account also holds is filled in.
  bool get hasDetails =>
      barAssociation.isNotEmpty ||
      membershipNo.isNotEmpty ||
      officeAddress.isNotEmpty ||
      mobile.isNotEmpty;

  /// Whether any of those four is still blank — the only state a pull from the
  /// account can improve.
  bool get hasBlankDetails =>
      barAssociation.isEmpty ||
      membershipNo.isEmpty ||
      officeAddress.isEmpty ||
      mobile.isEmpty;

  /// This record with the given fields replaced.
  ProfileFields copyWith({
    String? fullName,
    String? barAssociation,
    String? membershipNo,
    String? officeAddress,
    String? mobile,
  }) => ProfileFields(
    fullName: fullName ?? this.fullName,
    barAssociation: barAssociation ?? this.barAssociation,
    membershipNo: membershipNo ?? this.membershipNo,
    officeAddress: officeAddress ?? this.officeAddress,
    mobile: mobile ?? this.mobile,
  );

  /// This record with every field trimmed (forms may type stray spaces).
  ProfileFields trimmed() => ProfileFields(
    fullName: fullName.trim(),
    barAssociation: barAssociation.trim(),
    membershipNo: membershipNo.trim(),
    officeAddress: officeAddress.trim(),
    mobile: mobile.trim(),
  );

  /// The record as JSON, for [ProfileStore].
  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'barAssociation': barAssociation,
    'membershipNo': membershipNo,
    'officeAddress': officeAddress,
    'mobile': mobile,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfileFields &&
      other.fullName == fullName &&
      other.barAssociation == barAssociation &&
      other.membershipNo == membershipNo &&
      other.officeAddress == officeAddress &&
      other.mobile == mobile;

  @override
  int get hashCode => Object.hash(
    fullName,
    barAssociation,
    membershipNo,
    officeAddress,
    mobile,
  );
}

/// Reads and writes the saved profile record locally.
///
/// It also owns the one flag the account mirror needs: whether a saved record is
/// still owed to the server (set when a push could not reach it, cleared when
/// one lands).
class ProfileStore {
  /// Creates a store backed by [prefs].
  ProfileStore(this._prefs);

  /// Preferences holding the saved record.
  final SharedPreferences _prefs;

  /// The saved record, or [ProfileFields.blank] when the user has not filled
  /// the form in yet. An install that predates the record keeps its saved full
  /// name; an unreadable record falls back the same way rather than breaking
  /// the screen.
  ProfileFields read() {
    final raw = _prefs.getString(profileFieldsKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return ProfileFields.fromJson(decoded);
        }
      } on FormatException {
        // Fall through to the legacy name below.
      }
    }
    return ProfileFields(fullName: _prefs.getString(profileFullNameKey) ?? '');
  }

  /// Persists [fields] and drops the legacy name-only key.
  Future<void> write(ProfileFields fields) async {
    await _prefs.setString(profileFieldsKey, jsonEncode(fields.toJson()));
    await _prefs.remove(profileFullNameKey);
  }

  /// Whether a saved record has not reached the account yet.
  bool get detailsPushPending =>
      _prefs.getBool(profileDetailsPendingKey) ?? false;

  /// Records whether the account is still owed the saved record.
  Future<void> setDetailsPushPending(bool pending) async {
    if (pending) {
      await _prefs.setBool(profileDetailsPendingKey, true);
    } else {
      await _prefs.remove(profileDetailsPendingKey);
    }
  }

  /// Forgets the saved record (logout/account switch), so the next account on
  /// this device never reads the previous holder's personal details.
  Future<void> clear() async {
    await _prefs.remove(profileFieldsKey);
    await _prefs.remove(profileFullNameKey);
    await _prefs.remove(profileDetailsPendingKey);
  }
}

/// Riverpod state for the saved profile record.
///
/// The initial value is read synchronously from [SharedPreferences], so the
/// Profile screen, the drawer header and the case screens agree from the first
/// frame. [save] persists the record and notifies every listener.
class ProfileFieldsNotifier extends Notifier<ProfileFields> {
  late final ProfileStore _store;

  @override
  ProfileFields build() {
    _store = ProfileStore(ref.read(sharedPreferencesProvider));
    return _store.read();
  }

  /// Persists [fields] (trimmed); an unchanged record is not written again.
  Future<void> save(ProfileFields fields) async {
    final value = fields.trimmed();
    if (value == state) return;
    await _store.write(value);
    state = value;
  }

  /// Forgets the saved record and resets the in-memory value (logout/account
  /// switch).
  Future<void> clear() async {
    await _store.clear();
    state = const ProfileFields();
  }
}

/// Public provider to read and update the user's profile record.
final profileFieldsProvider =
    NotifierProvider<ProfileFieldsNotifier, ProfileFields>(
      ProfileFieldsNotifier.new,
    );

/// The saved Full Name alone — what the drawer header and the client message
/// templates show. Empty until the user saves one.
final profileNameProvider = Provider<String>(
  (ref) => ref.watch(profileFieldsProvider).fullName,
);
