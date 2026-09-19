/// Which side of a case an On-Behalf role represents — one rule for the app.
///
/// Task 14 Phase 4 requires the Phone/Message actions to resolve the
/// **represented** party through `on_behalf_id` rather than guessing from field
/// order. The Case Detail party card needs the same answer to mark the client,
/// and the scoped case search needs it, so the rule lives here once instead of
/// being copied per screen (two copies drift, and then the message names the
/// opponent).
///
/// The rule is deliberately narrow: only seeded roles with an unambiguous
/// procedural side are mapped, so an unknown or custom role returns `null` and
/// the caller falls back to a documented default rather than mislabelling a
/// stored number.
library;

import '../../database/app_database.dart';

/// The party side a represented client sits on.
enum PartySide {
  /// The plaintiff/petitioner side.
  petitioner,

  /// The defendant/respondent side.
  respondent,
}

/// Role-id slugs that unambiguously represent the petitioner's side.
///
/// A seeded role id ends with its slug (`…-petitioner`), so the mapping is a
/// suffix rule and stays usable from SQL (`on_behalf_id LIKE '%-petitioner'`).
const List<String> petitionerSideSlugs = <String>[
  'petitioner',
  'plaintiff',
  'appellant',
  'revisioner',
  'reviewer',
  'decree-holder',
  'decree_holder',
];

/// Role-id slugs that unambiguously represent the respondent's side.
const List<String> respondentSideSlugs = <String>[
  'respondent',
  'defendant',
  'accused',
  'judgement-debtor',
  'judgement_debtor',
];

/// Every slug a party side maps to, paired with the side it resolves to.
///
/// One table, so `representedSideOfId` cannot answer differently for a role id
/// from the way the party card labels it.
List<(String slug, PartySide side)> get onBehalfSlugSides => <(String, PartySide)>[
  ...petitionerSideSlugs.map((slug) => (slug, PartySide.petitioner)),
  ...respondentSideSlugs.map((slug) => (slug, PartySide.respondent)),
];

/// The trailing slug of a role id, e.g. `…-decree_holder` → `decree_holder`.
String onBehalfSlug(String id) => id.substring(id.lastIndexOf('-') + 1);

/// The side the role with [id] represents, or `null` when it is not a known
/// seeded side.
PartySide? representedSideOfId(String? id) {
  if (id == null || id.isEmpty) return null;
  final slug = onBehalfSlug(id);
  for (final (candidate, side) in onBehalfSlugSides) {
    if (candidate == slug) return side;
  }
  return null;
}

/// The side [role] represents, or `null` when the role is absent, unknown or
/// custom.
PartySide? representedSideOf(OnBehalf? role) =>
    role == null ? null : representedSideOfId(role.id);

/// The party name on [side] of [currentCase].
String partyNameOf(Case currentCase, PartySide side) =>
    side == PartySide.petitioner ? currentCase.petitioner : currentCase.respondent;

/// The **represented client's** name on [currentCase], resolved through the
/// case's on-behalf role.
///
/// This is what the pre-filled SMS/WhatsApp template names, so a firm acting
/// for the respondent sends the respondent's name rather than the petitioner's.
/// An absent or custom role falls back to the petitioner, which is the side the
/// app labels first everywhere else.
String representedClientName(Case currentCase, OnBehalf? role) =>
    partyNameOf(currentCase, representedSideOf(role) ?? PartySide.petitioner);
