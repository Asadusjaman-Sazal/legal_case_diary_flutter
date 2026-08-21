/// Pre-seeded data: all built-in court hierarchy and configuration data
/// with stable deterministic IDs shared across Drift, Supabase, backups,
/// and releases. Implemented in Task 04.
///
/// Table classes (per AGENTS.md rule 4):
///   court_categories — push/pull domain (editable, firm-shared synced ref)
///   courts           — push/pull domain
///   steps            — push/pull domain
///   case_types       — push/pull domain
///   on_behalfs       — push/pull domain
///   seed_migrations  — local operational (migration ledger, never synced)
library;

import 'package:collection/collection.dart';

// ---------------------------------------------------------------------------
// Stable ID constants
// ---------------------------------------------------------------------------

/// Higher court stable IDs.
const appellateDivisionId = 'appellate_division';
const highCourtDivisionId = 'high_court_division';

/// Higher/lower court options (used in add/edit case form).
const higherCourtsOption = 'higher_courts';
const lowerCourtsOption = 'lower_courts';

/// Lower court category stable IDs.
const districtSessionsCriminalId = 'district_sessions_criminal';
const districtCourtsCivilId = 'district_courts_civil';
const chiefJudicialMagistrateId = 'chief_judicial_magistrate';
const chiefMetropolitanMagistrateId = 'chief_metropolitan_magistrate';
const tribunalsId = 'tribunals';
const executiveMagistrateId = 'executive_magistrate';

/// Ordered list of all 8 court-category stable IDs.
const allCategoryIds = <String>[
  appellateDivisionId,
  highCourtDivisionId,
  districtSessionsCriminalId,
  districtCourtsCivilId,
  chiefJudicialMagistrateId,
  chiefMetropolitanMagistrateId,
  tribunalsId,
  executiveMagistrateId,
];

/// Ordered list of 6 lower-court category stable IDs.
const lowerCourtCategoryIds = <String>[
  districtSessionsCriminalId,
  districtCourtsCivilId,
  chiefJudicialMagistrateId,
  chiefMetropolitanMagistrateId,
  executiveMagistrateId,
  tribunalsId,
];

// ---------------------------------------------------------------------------
// Seed data structures
// ---------------------------------------------------------------------------

/// A labeled seed option with a stable ID and display order.
class SeedOption {
  const SeedOption({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.orderIndex,
  });

  final String id;
  final String labelEn;
  final String labelBn;
  final int orderIndex;
}

/// Definition of one court category with its associated steps,
/// case types, and on-behalf options.
class SeedCategory {
  const SeedCategory({
    required this.id,
    required this.nameKey,
    required this.courtLevel,
    required this.orderIndex,
    required this.steps,
    required this.caseTypes,
    required this.onBehalfs,
  });

  /// Stable machine key (e.g. `appellate_division`).
  final String id;

  /// Localization key resolved through AppLocalizations.
  final String nameKey;

  /// `appellate`, `high_court`, or `lower`.
  final String courtLevel;

  /// Canonical display order.
  final int orderIndex;

  final List<SeedOption> steps;
  final List<SeedOption> caseTypes;
  final List<SeedOption> onBehalfs;
}

/// A pre-seeded court (supreme court or lower court).
class SeedCourt {
  const SeedCourt({
    required this.id,
    required this.courtNameEn,
    required this.courtNameBn,
    required this.higherLowerCourts,
    required this.courtCategoryId,
    this.division,
    this.district,
  });

  final String id;
  final String courtNameEn;
  final String courtNameBn;
  final String higherLowerCourts;
  final String courtCategoryId;
  final String? division;
  final String? district;
}

// ---------------------------------------------------------------------------
// Helper: make a stable ID for seed items
// ---------------------------------------------------------------------------

String _stepId(String catId, String nameSlug) => 'step-$catId-$nameSlug';
String _caseTypeId(String catId, String nameSlug) =>
    'casetype-$catId-$nameSlug';
String _onBehalfId(String catId, String nameSlug) =>
    'onbehalf-$catId-$nameSlug';
String _supremeCourtId(String catId, String nameSlug) =>
    'court-higher_courts-$catId-$nameSlug';
String _lowerCourtId(String catId, String district, String nameSlug) =>
    'court-lower_courts-$catId-${district.toLowerCase().replaceAll(' ', '_')}-$nameSlug';

/// Slugify a name: lowercase, replace spaces/special chars with underscores.
String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'_+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

// ---------------------------------------------------------------------------
// Divisions (8)
// ---------------------------------------------------------------------------

const divisionDhakaId = 'dhaka';
const divisionChattogramId = 'chattogram';
const divisionRajshahiId = 'rajshahi';
const divisionKhulnaId = 'khulna';
const divisionBarishalId = 'barishal';
const divisionSylhetId = 'sylhet';
const divisionRangpurId = 'rangpur';
const divisionMymensinghId = 'mymensingh';

/// Ordered list of all 8 division stable IDs.
const allDivisionIds = <String>[
  divisionDhakaId,
  divisionChattogramId,
  divisionRajshahiId,
  divisionKhulnaId,
  divisionBarishalId,
  divisionSylhetId,
  divisionRangpurId,
  divisionMymensinghId,
];

/// Division labels keyed by stable ID.
const Map<String, String> divisionLabelEn = <String, String>{
  divisionDhakaId: 'Dhaka',
  divisionChattogramId: 'Chattogram',
  divisionRajshahiId: 'Rajshahi',
  divisionKhulnaId: 'Khulna',
  divisionBarishalId: 'Barishal',
  divisionSylhetId: 'Sylhet',
  divisionRangpurId: 'Rangpur',
  divisionMymensinghId: 'Mymensingh',
};

const Map<String, String> divisionLabelBn = <String, String>{
  divisionDhakaId: 'ঢাকা',
  divisionChattogramId: 'চট্টগ্রাম',
  divisionRajshahiId: 'রাজশাহী',
  divisionKhulnaId: 'খুলনা',
  divisionBarishalId: 'বরিশাল',
  divisionSylhetId: 'সিলেট',
  divisionRangpurId: 'রংপুর',
  divisionMymensinghId: 'ময়মনসিংহ',
};

// ---------------------------------------------------------------------------
// Districts by division
// ---------------------------------------------------------------------------

/// District stable IDs grouped by division. Each district ID is its
/// lowercase slugified name.
const Map<String, List<String>> districtIdsByDivision = <String, List<String>>{
  divisionDhakaId: <String>[
    'dhaka',
    'faridpur',
    'gazipur',
    'gopalganj',
    'kishoregonj',
    'madaripur',
    'manikganj',
    'munshiganj',
    'narayanganj',
    'narsingdi',
    'rajbari',
    'shariatpur',
    'tangail',
  ],
  divisionChattogramId: <String>[
    'bandarban',
    'brahmanbaria',
    'chandpur',
    'chittagong',
    'cumilla',
    'coxs_bazar',
    'feni',
    'khagrachhari',
    'lakshmipur',
    'noakhali',
    'rangamati',
  ],
  divisionKhulnaId: <String>[
    'bagerhat',
    'chuadanga',
    'jessore',
    'jhenaidah',
    'khulna',
    'kushtia',
    'magura',
    'meherpur',
    'narail',
    'satkhira',
  ],
  divisionRajshahiId: <String>[
    'bogra',
    'joypurhat',
    'naogaon',
    'natore',
    'chapai_nababganj',
    'pabna',
    'rajshahi',
    'sirajganj',
  ],
  divisionBarishalId: <String>[
    'barguna',
    'barishal',
    'bhola',
    'jhalokathi',
    'patuakhali',
    'pirojpur',
  ],
  divisionSylhetId: <String>['habiganj', 'maulvibazar', 'sunamganj', 'sylhet'],
  divisionRangpurId: <String>[
    'dinajpur',
    'gaibandha',
    'kurigram',
    'lalmonirhat',
    'nilphamari',
    'panchagarh',
    'rangpur',
    'thakurgaon',
  ],
  divisionMymensinghId: <String>[
    'jamalpur',
    'mymensingh',
    'netrakona',
    'sherpur',
  ],
};

/// District English labels keyed by district stable ID.
const Map<String, String> districtLabelEn = <String, String>{
  // Dhaka
  'dhaka': 'Dhaka',
  'faridpur': 'Faridpur',
  'gazipur': 'Gazipur',
  'gopalganj': 'Gopalganj',
  'kishoregonj': 'Kishoregonj',
  'madaripur': 'Madaripur',
  'manikganj': 'Manikganj',
  'munshiganj': 'Munshiganj',
  'narayanganj': 'Narayanganj',
  'narsingdi': 'Narsingdi',
  'rajbari': 'Rajbari',
  'shariatpur': 'Shariatpur',
  'tangail': 'Tangail',
  // Chattogram
  'bandarban': 'Bandarban',
  'brahmanbaria': 'Brahmanbaria',
  'chandpur': 'Chandpur',
  'chittagong': 'Chittagong',
  'cumilla': 'Cumilla',
  'coxs_bazar': "Cox's Bazar",
  'feni': 'Feni',
  'khagrachhari': 'Khagrachhari',
  'lakshmipur': 'Lakshmipur',
  'noakhali': 'Noakhali',
  'rangamati': 'Rangamati',
  // Khulna
  'bagerhat': 'Bagerhat',
  'chuadanga': 'Chuadanga',
  'jessore': 'Jessore',
  'jhenaidah': 'Jhenaidah',
  'khulna': 'Khulna',
  'kushtia': 'Kushtia',
  'magura': 'Magura',
  'meherpur': 'Meherpur',
  'narail': 'Narail',
  'satkhira': 'Satkhira',
  // Rajshahi
  'bogra': 'Bogra',
  'joypurhat': 'Joypurhat',
  'naogaon': 'Naogaon',
  'natore': 'Natore',
  'chapai_nababganj': 'Chapai Nababganj',
  'pabna': 'Pabna',
  'rajshahi': 'Rajshahi',
  'sirajganj': 'Sirajganj',
  // Barishal
  'barguna': 'Barguna',
  'barishal': 'Barisal',
  'bhola': 'Bhola',
  'jhalokathi': 'Jhalokathi',
  'patuakhali': 'Patuakhali',
  'pirojpur': 'Pirojpur',
  // Sylhet
  'habiganj': 'Habiganj',
  'maulvibazar': 'Maulvibazar',
  'sunamganj': 'Sunamganj',
  'sylhet': 'Sylhet',
  // Rangpur
  'dinajpur': 'Dinajpur',
  'gaibandha': 'Gaibandha',
  'kurigram': 'Kurigram',
  'lalmonirhat': 'Lalmonirhat',
  'nilphamari': 'Nilphamari',
  'panchagarh': 'Panchagarh',
  'rangpur': 'Rangpur',
  'thakurgaon': 'Thakurgaon',
  // Mymensingh
  'jamalpur': 'Jamalpur',
  'mymensingh': 'Mymensingh',
  'netrakona': 'Netrakona',
  'sherpur': 'Sherpur',
};

/// District Bengali labels keyed by district stable ID.
const Map<String, String> districtLabelBn = <String, String>{
  // Dhaka
  'dhaka': 'ঢাকা',
  'faridpur': 'ফরিদপুর',
  'gazipur': 'গাজীপুর',
  'gopalganj': 'গোপালগঞ্জ',
  'kishoregonj': 'কিশোরগঞ্জ',
  'madaripur': 'মাদারীপুর',
  'manikganj': 'মানিকগঞ্জ',
  'munshiganj': 'মুন্সীগঞ্জ',
  'narayanganj': 'নারায়ণগঞ্জ',
  'narsingdi': 'নরসিংদী',
  'rajbari': 'রাজবাড়ী',
  'shariatpur': 'শরীয়তপুর',
  'tangail': 'টাঙ্গাইল',
  // Chattogram
  'bandarban': 'বান্দরবান',
  'brahmanbaria': 'ব্রাহ্মণবাড়িয়া',
  'chandpur': 'চাঁদপুর',
  'chittagong': 'চট্টগ্রাম',
  'cumilla': 'কুমিল্লা',
  'coxs_bazar': 'কক্সবাজার',
  'feni': 'ফেনী',
  'khagrachhari': 'খাগড়াছড়ি',
  'lakshmipur': 'লক্ষ্মীপুর',
  'noakhali': 'নোয়াখালী',
  'rangamati': 'রাঙ্গামাটি',
  // Khulna
  'bagerhat': 'বাগেরহাট',
  'chuadanga': 'চুয়াডাঙ্গা',
  'jessore': 'যশোর',
  'jhenaidah': 'ঝিনাইদহ',
  'khulna': 'খুলনা',
  'kushtia': 'কুষ্টিয়া',
  'magura': 'মাগুরা',
  'meherpur': 'মেহেরপুর',
  'narail': 'নড়াইল',
  'satkhira': 'সাতক্ষীরা',
  // Rajshahi
  'bogra': 'বগুড়া',
  'joypurhat': 'জয়পুরহাট',
  'naogaon': 'নওগাঁ',
  'natore': 'নাটোর',
  'chapai_nababganj': 'চাঁপাই নবাবগঞ্জ',
  'pabna': 'পাবনা',
  'rajshahi': 'রাজশাহী',
  'sirajganj': 'সিরাজগঞ্জ',
  // Barishal
  'barguna': 'বরগুনা',
  'barishal': 'বরিশাল',
  'bhola': 'ভোলা',
  'jhalokati': 'ঝালকাঠি',
  'patuakhali': 'পটুয়াখালী',
  'pirojpur': 'পিরোজপুর',
  // Sylhet
  'habiganj': 'হবিগঞ্জ',
  'maulvibazar': 'মৌলভীবাজার',
  'sunamganj': 'সুনামগঞ্জ',
  'sylhet': 'সিলেট',
  // Rangpur
  'dinajpur': 'দিনাজপুর',
  'gaibandha': 'গাইবান্ধা',
  'kurigram': 'কুড়িগ্রাম',
  'lalmonirhat': 'লালমনিরহাট',
  'nilphamari': 'নীলফামারী',
  'panchagarh': 'পঞ্চগড়',
  'rangpur': 'রংপুর',
  'thakurgaon': 'ঠাকুরগাঁও',
  // Mymensingh
  'jamalpur': 'জামালপুর',
  'mymensingh': 'ময়মনসিংহ',
  'netrakona': 'নেত্রকোণা',
  'sherpur': 'শেরপুর',
};

// ---------------------------------------------------------------------------
// Court category definitions
// ---------------------------------------------------------------------------

/// All 8 court categories with their steps, case types, and on-behalfs.
// ignore: non_constant_identifier_names
final List<SeedCategory> seedCategories = <SeedCategory>[
  // -- Appellate Division -------------------------------------------------
  SeedCategory(
    id: appellateDivisionId,
    nameKey: 'courtCategory_appellateDivision',
    courtLevel: 'appellate',
    orderIndex: 0,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(appellateDivisionId, 'filed'),
        labelEn: 'Filed',
        labelBn: 'দাখিলকৃত',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(appellateDivisionId, 'admission_hearing'),
        labelEn: 'Admission Hearing',
        labelBn: 'Admission শুনানি',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(appellateDivisionId, 'leave_to_appeal_granted'),
        labelEn: 'Leave to Appeal Granted',
        labelBn: 'আপিলের অনুমতি মঞ্জুর',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(appellateDivisionId, 'hearing'),
        labelEn: 'Hearing',
        labelBn: 'শুনানি',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(appellateDivisionId, 'judgment'),
        labelEn: 'Judgment',
        labelBn: 'রায়',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(appellateDivisionId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 5,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(appellateDivisionId, 'civil_appeal'),
        labelEn: 'Civil Appeal',
        labelBn: 'সিভিল আপিল',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(appellateDivisionId, 'criminal_appeal'),
        labelEn: 'Criminal Appeal',
        labelBn: 'ক্রিমিনাল আপিল',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(appellateDivisionId, 'family_appeal'),
        labelEn: 'Family Appeal',
        labelBn: 'পারিবারিক আপিল',
        orderIndex: 2,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(appellateDivisionId, 'appellant'),
        labelEn: 'Appellant',
        labelBn: 'আপিলকারী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(appellateDivisionId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'বিবাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(appellateDivisionId, 'petitioner'),
        labelEn: 'Petitioner',
        labelBn: 'আবেদনকারী',
        orderIndex: 2,
      ),
    ],
  ),
  // -- High Court Division -------------------------------------------------
  SeedCategory(
    id: highCourtDivisionId,
    nameKey: 'courtCategory_highCourtDivision',
    courtLevel: 'high_court',
    orderIndex: 1,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(highCourtDivisionId, 'filed'),
        labelEn: 'Filed',
        labelBn: 'দাখিলকৃত',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'rule_issued'),
        labelEn: 'Rule Issued',
        labelBn: 'রুল ইস্যু',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'return_of_rule'),
        labelEn: 'Return of Rule',
        labelBn: 'রুলের রিটার্ন',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'rule_made_absolute'),
        labelEn: 'Rule Made Absolute',
        labelBn: 'রুল Absolute',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'rule_discharged'),
        labelEn: 'Rule Discharged',
        labelBn: 'রুল খারিজ',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'hearing'),
        labelEn: 'Hearing',
        labelBn: 'শুনানি',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'judgment'),
        labelEn: 'Judgment',
        labelBn: 'রায়',
        orderIndex: 6,
      ),
      SeedOption(
        id: _stepId(highCourtDivisionId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 7,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(highCourtDivisionId, 'writ_petition'),
        labelEn: 'Writ Petition',
        labelBn: 'রিট পিটিশন',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(highCourtDivisionId, 'civil_revision'),
        labelEn: 'Civil Revision',
        labelBn: 'সিভিল রিভিশন',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(highCourtDivisionId, 'criminal_revision'),
        labelEn: 'Criminal Revision',
        labelBn: 'ক্রিমিনাল রিভিশন',
        orderIndex: 2,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'petitioner'),
        labelEn: 'Petitioner',
        labelBn: 'আবেদনকারী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'বিবাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'writ_petitioner'),
        labelEn: 'Writ Petitioner',
        labelBn: 'রিট আবেদনকারী',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'appellant'),
        labelEn: 'Appellant',
        labelBn: 'আপিলকারী',
        orderIndex: 3,
      ),
    ],
  ),
  // -- District Sessions Courts (Criminal) ---------------------------------
  SeedCategory(
    id: districtSessionsCriminalId,
    nameKey: 'lowerCourtCategory_districtSessionsCriminal',
    courtLevel: 'lower',
    orderIndex: 2,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'charge_sheet_received'),
        labelEn: 'Charge Sheet Received',
        labelBn: 'চার্জশীট গৃহীত',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'framing_of_charge'),
        labelEn: 'Framing of Charge',
        labelBn: 'চার্জ গঠন',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'plea'),
        labelEn: 'Plea',
        labelBn: 'Plea',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'prosecution_evidence'),
        labelEn: 'Prosecution Evidence',
        labelBn: 'রাষ্ট্রপক্ষের সাক্ষ্য',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'defense_evidence'),
        labelEn: 'Defense Evidence',
        labelBn: 'আসামীপক্ষের সাক্ষ্য',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'arguments'),
        labelEn: 'Arguments',
        labelBn: 'যুক্তিতর্ক',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'judgment'),
        labelEn: 'Judgment',
        labelBn: 'রায়',
        orderIndex: 6,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'acquitted'),
        labelEn: 'Acquitted',
        labelBn: 'বেকসুর খালাস',
        orderIndex: 7,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'convicted'),
        labelEn: 'Convicted',
        labelBn: 'সাজাপ্রাপ্ত',
        orderIndex: 8,
      ),
      SeedOption(
        id: _stepId(districtSessionsCriminalId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 9,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(districtSessionsCriminalId, 'sessions_case'),
        labelEn: 'Sessions Case',
        labelBn: 'সেশনস কেস',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(districtSessionsCriminalId, 'criminal_appeal'),
        labelEn: 'Criminal Appeal',
        labelBn: 'ক্রিমিনাল আপিল',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(districtSessionsCriminalId, 'reference'),
        labelEn: 'Reference',
        labelBn: 'রেফারেন্স',
        orderIndex: 2,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(districtSessionsCriminalId, 'accused'),
        labelEn: 'Accused',
        labelBn: 'আসামী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(districtSessionsCriminalId, 'complainant'),
        labelEn: 'Complainant',
        labelBn: 'বাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(districtSessionsCriminalId, 'state'),
        labelEn: 'State',
        labelBn: 'রাষ্ট্র',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(districtSessionsCriminalId, 'victim'),
        labelEn: 'Victim',
        labelBn: 'ভিকটিম',
        orderIndex: 3,
      ),
    ],
  ),
  // -- District Courts (Civil) ---------------------------------------------
  SeedCategory(
    id: districtCourtsCivilId,
    nameKey: 'lowerCourtCategory_districtCourtsCivil',
    courtLevel: 'lower',
    orderIndex: 3,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'plaint_filed'),
        labelEn: 'Plaint Filed',
        labelBn: 'আরজি দাখিল',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'written_statement'),
        labelEn: 'Written Statement',
        labelBn: 'লিখিত জবাব',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'issues_framed'),
        labelEn: 'Issues Framed',
        labelBn: 'বিচার্য বিষয় নির্ধারণ',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'plaintiff_evidence'),
        labelEn: 'Plaintiff Evidence',
        labelBn: 'বাদীর সাক্ষ্য',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'defense_evidence'),
        labelEn: 'Defense Evidence',
        labelBn: 'বিবাদীর সাক্ষ্য',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'arguments'),
        labelEn: 'Arguments',
        labelBn: 'যুক্তিতর্ক',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'decree_passed'),
        labelEn: 'Decree Passed',
        labelBn: 'ডিক্রি প্রদান',
        orderIndex: 6,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'dismissed'),
        labelEn: 'Dismissed',
        labelBn: 'খারিজ',
        orderIndex: 7,
      ),
      SeedOption(
        id: _stepId(districtCourtsCivilId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 8,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(districtCourtsCivilId, 'civil_suit'),
        labelEn: 'Civil Suit',
        labelBn: 'সিভিল মামলা',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(districtCourtsCivilId, 'title_suit'),
        labelEn: 'Title Suit',
        labelBn: 'টাইটেল স্যুট',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(districtCourtsCivilId, 'money_suit'),
        labelEn: 'Money Suit',
        labelBn: 'মানি স্যুট',
        orderIndex: 2,
      ),
      SeedOption(
        id: _caseTypeId(districtCourtsCivilId, 'partition_suit'),
        labelEn: 'Partition Suit',
        labelBn: 'বন্টন মামলা',
        orderIndex: 3,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(districtCourtsCivilId, 'plaintiff'),
        labelEn: 'Plaintiff',
        labelBn: 'বাদী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(districtCourtsCivilId, 'defendant'),
        labelEn: 'Defendant',
        labelBn: 'বিবাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(districtCourtsCivilId, 'petitioner'),
        labelEn: 'Petitioner',
        labelBn: 'আবেদনকারী',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(districtCourtsCivilId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'বিবাদী',
        orderIndex: 3,
      ),
      SeedOption(
        id: _onBehalfId(districtCourtsCivilId, 'applicant'),
        labelEn: 'Applicant',
        labelBn: 'আবেদনকারী',
        orderIndex: 4,
      ),
    ],
  ),
  // -- Chief Judicial Magistrate Courts ------------------------------------
  SeedCategory(
    id: chiefJudicialMagistrateId,
    nameKey: 'lowerCourtCategory_chiefJudicialMagistrate',
    courtLevel: 'lower',
    orderIndex: 4,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'complaint_filed'),
        labelEn: 'Complaint Filed',
        labelBn: 'অভিযোগ দাখিল',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'cognizance'),
        labelEn: 'Cognizance',
        labelBn: 'আমলে গ্রহণ',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'summons_warrant'),
        labelEn: 'Summons/Warrant',
        labelBn: 'সমন/ওয়ারেন্ট',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'appearance'),
        labelEn: 'Appearance',
        labelBn: 'হাজিরা',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'charge'),
        labelEn: 'Charge',
        labelBn: 'অভিযোগ',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'evidence'),
        labelEn: 'Evidence',
        labelBn: 'সাক্ষ্য',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'arguments'),
        labelEn: 'Arguments',
        labelBn: 'যুক্তিতর্ক',
        orderIndex: 6,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'judgment'),
        labelEn: 'Judgment',
        labelBn: 'রায়',
        orderIndex: 7,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'acquitted'),
        labelEn: 'Acquitted',
        labelBn: 'বেকসুর খালাস',
        orderIndex: 8,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'convicted'),
        labelEn: 'Convicted',
        labelBn: 'সাজাপ্রাপ্ত',
        orderIndex: 9,
      ),
      SeedOption(
        id: _stepId(chiefJudicialMagistrateId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 10,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(chiefJudicialMagistrateId, 'gr_case'),
        labelEn: 'GR Case',
        labelBn: 'জিআর কেস',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(chiefJudicialMagistrateId, 'criminal_case'),
        labelEn: 'Criminal Case',
        labelBn: 'ক্রিমিনাল কেস',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(chiefJudicialMagistrateId, 'complaint_case'),
        labelEn: 'Complaint Case',
        labelBn: 'কমপ্লেইন্ট কেস',
        orderIndex: 2,
      ),
      SeedOption(
        id: _caseTypeId(chiefJudicialMagistrateId, 'magistrate_case'),
        labelEn: 'Magistrate Case',
        labelBn: 'ম্যাজিস্ট্রেট কেস',
        orderIndex: 3,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(chiefJudicialMagistrateId, 'accused'),
        labelEn: 'Accused',
        labelBn: 'আসামী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(chiefJudicialMagistrateId, 'complainant'),
        labelEn: 'Complainant',
        labelBn: 'বাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(chiefJudicialMagistrateId, 'state'),
        labelEn: 'State',
        labelBn: 'রাষ্ট্র',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(chiefJudicialMagistrateId, 'informant'),
        labelEn: 'Informant',
        labelBn: 'তথ্যদাতা',
        orderIndex: 3,
      ),
    ],
  ),
  // -- Chief Metropolitan Magistrate Courts --------------------------------
  SeedCategory(
    id: chiefMetropolitanMagistrateId,
    nameKey: 'lowerCourtCategory_chiefMetropolitanMagistrate',
    courtLevel: 'lower',
    orderIndex: 5,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'complaint_filed'),
        labelEn: 'Complaint Filed',
        labelBn: 'অভিযোগ দাখিল',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'cognizance'),
        labelEn: 'Cognizance',
        labelBn: 'আমলে গ্রহণ',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'summons'),
        labelEn: 'Summons',
        labelBn: 'সমন',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'appearance'),
        labelEn: 'Appearance',
        labelBn: 'হাজিরা',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'trial'),
        labelEn: 'Trial',
        labelBn: 'বিচার',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'arguments'),
        labelEn: 'Arguments',
        labelBn: 'যুক্তিতর্ক',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'judgment'),
        labelEn: 'Judgment',
        labelBn: 'রায়',
        orderIndex: 6,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'acquitted'),
        labelEn: 'Acquitted',
        labelBn: 'বেকসুর খালাস',
        orderIndex: 7,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'convicted'),
        labelEn: 'Convicted',
        labelBn: 'সাজাপ্রাপ্ত',
        orderIndex: 8,
      ),
      SeedOption(
        id: _stepId(chiefMetropolitanMagistrateId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 9,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(chiefMetropolitanMagistrateId, 'gr_case'),
        labelEn: 'GR Case',
        labelBn: 'জিআর কেস',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(chiefMetropolitanMagistrateId, 'metropolitan_case'),
        labelEn: 'Metropolitan Case',
        labelBn: 'মেট্রোপলিটন কেস',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(chiefMetropolitanMagistrateId, 'complaint_case'),
        labelEn: 'Complaint Case',
        labelBn: 'কমপ্লেইন্ট কেস',
        orderIndex: 2,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(chiefMetropolitanMagistrateId, 'accused'),
        labelEn: 'Accused',
        labelBn: 'আসামী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(chiefMetropolitanMagistrateId, 'complainant'),
        labelEn: 'Complainant',
        labelBn: 'বাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(chiefMetropolitanMagistrateId, 'state'),
        labelEn: 'State',
        labelBn: 'রাষ্ট্র',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(chiefMetropolitanMagistrateId, 'informant'),
        labelEn: 'Informant',
        labelBn: 'তথ্যদাতা',
        orderIndex: 3,
      ),
    ],
  ),
  // -- Executive Magistrate Courts -----------------------------------------
  SeedCategory(
    id: executiveMagistrateId,
    nameKey: 'lowerCourtCategory_executiveMagistrate',
    courtLevel: 'lower',
    orderIndex: 6,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(executiveMagistrateId, 'filed'),
        labelEn: 'Filed',
        labelBn: 'দাখিলকৃত',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(executiveMagistrateId, 'hearing'),
        labelEn: 'Hearing',
        labelBn: 'শুনানি',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(executiveMagistrateId, 'order'),
        labelEn: 'Order',
        labelBn: 'আদেশ',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(executiveMagistrateId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 3,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(executiveMagistrateId, 'executive_case'),
        labelEn: 'Executive Case',
        labelBn: 'নির্বাহী কেস',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(executiveMagistrateId, 'mobile_court_case'),
        labelEn: 'Mobile Court Case',
        labelBn: 'মোবাইল কোর্ট কেস',
        orderIndex: 1,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(executiveMagistrateId, 'defendant'),
        labelEn: 'Defendant',
        labelBn: 'বিবাদী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(executiveMagistrateId, 'complainant'),
        labelEn: 'Complainant',
        labelBn: 'বাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(executiveMagistrateId, 'applicant'),
        labelEn: 'Applicant',
        labelBn: 'আবেদনকারী',
        orderIndex: 2,
      ),
    ],
  ),
  // -- Tribunals -----------------------------------------------------------
  SeedCategory(
    id: tribunalsId,
    nameKey: 'lowerCourtCategory_tribunals',
    courtLevel: 'lower',
    orderIndex: 7,
    steps: <SeedOption>[
      SeedOption(
        id: _stepId(tribunalsId, 'filed'),
        labelEn: 'Filed',
        labelBn: 'দাখিলকৃত',
        orderIndex: 0,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'notice'),
        labelEn: 'Notice',
        labelBn: 'নোটিশ',
        orderIndex: 1,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'reply'),
        labelEn: 'Reply',
        labelBn: 'জবাব',
        orderIndex: 2,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'hearing'),
        labelEn: 'Hearing',
        labelBn: 'শুনানি',
        orderIndex: 3,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'order'),
        labelEn: 'Order',
        labelBn: 'আদেশ',
        orderIndex: 4,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'award'),
        labelEn: 'Award',
        labelBn: 'Award',
        orderIndex: 5,
      ),
      SeedOption(
        id: _stepId(tribunalsId, 'disposed'),
        labelEn: 'Disposed',
        labelBn: 'নিষ্পত্তি',
        orderIndex: 6,
      ),
    ],
    caseTypes: <SeedOption>[
      SeedOption(
        id: _caseTypeId(tribunalsId, 'money_loan_case'),
        labelEn: 'Money Loan Case',
        labelBn: 'অর্থঋণ মামলা',
        orderIndex: 0,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'artha_rin_case'),
        labelEn: 'Artha Rin Case',
        labelBn: 'অর্থঋণ মামলা',
        orderIndex: 1,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'tribunal_case'),
        labelEn: 'Tribunal Case',
        labelBn: 'ট্রাইব্যুনাল কেস',
        orderIndex: 2,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'nari_o_shishu_case'),
        labelEn: 'Nari O Shishu Case',
        labelBn: 'নারী ও শিশু মামলা',
        orderIndex: 3,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'land_survey_case'),
        labelEn: 'Land Survey Case',
        labelBn: 'ভূমি জরিপ মামলা',
        orderIndex: 4,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'labour_case'),
        labelEn: 'Labour Case',
        labelBn: 'শ্রম মামলা',
        orderIndex: 5,
      ),
      SeedOption(
        id: _caseTypeId(tribunalsId, 'cyber_case'),
        labelEn: 'Cyber Case',
        labelBn: 'সাইবার মামলা',
        orderIndex: 6,
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(tribunalsId, 'applicant'),
        labelEn: 'Applicant',
        labelBn: 'আবেদনকারী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(tribunalsId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'বিবাদী',
        orderIndex: 1,
      ),
      SeedOption(
        id: _onBehalfId(tribunalsId, 'claimant'),
        labelEn: 'Claimant',
        labelBn: 'দাবিদার',
        orderIndex: 2,
      ),
      SeedOption(
        id: _onBehalfId(tribunalsId, 'objector'),
        labelEn: 'Objector',
        labelBn: 'আপত্তিকার',
        orderIndex: 3,
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Category lookup helpers
// ---------------------------------------------------------------------------

/// Map: category stable ID → SeedCategory.
final Map<String, SeedCategory> seedCategoryById = Map.unmodifiable(
  Map.fromEntries(seedCategories.map((c) => MapEntry(c.id, c))),
);

/// Map: category stable ID → list of step stable IDs.
final Map<String, List<String>> stepIdsByCategory = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.map(
      (c) => MapEntry(c.id, c.steps.map((s) => s.id).toList()),
    ),
  ),
);

/// Map: category stable ID → list of case type stable IDs.
final Map<String, List<String>> caseTypeIdsByCategory = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.map(
      (c) => MapEntry(c.id, c.caseTypes.map((ct) => ct.id).toList()),
    ),
  ),
);

/// Map: category stable ID → list of on-behalf stable IDs.
final Map<String, List<String>> onBehalfIdsByCategory = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.map(
      (c) => MapEntry(c.id, c.onBehalfs.map((o) => o.id).toList()),
    ),
  ),
);

// ---------------------------------------------------------------------------
// Supreme court names
// ---------------------------------------------------------------------------

const _annexBuildingLabelEn = 'Annex Building 2, Court No. 5';
const _annexBuildingLabelBn = 'Annex Building 2, Court No. 5';

/// Pre-seeded supreme court names.
// ignore: non_constant_identifier_names
final List<SeedCourt> supremeCourtNames = <SeedCourt>[
  // Appellate Division
  SeedCourt(
    id: _supremeCourtId(appellateDivisionId, 'annex_building_2_court_5'),
    courtNameEn: _annexBuildingLabelEn,
    courtNameBn: _annexBuildingLabelBn,
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: appellateDivisionId,
  ),
  // High Court Division
  SeedCourt(
    id: _supremeCourtId(highCourtDivisionId, 'annex_building_2_court_5'),
    courtNameEn: _annexBuildingLabelEn,
    courtNameBn: _annexBuildingLabelBn,
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
  ),
];

// ---------------------------------------------------------------------------
// Lower court names by district by category (example data)
// ---------------------------------------------------------------------------

/// Builds a seed court entry for a lower court.
SeedCourt _lc(String catId, String districtId, String nameEn, String nameBn) {
  final slug = _slug(nameEn);
  return SeedCourt(
    id: _lowerCourtId(catId, districtId, slug),
    courtNameEn: nameEn,
    courtNameBn: nameBn,
    higherLowerCourts: lowerCourtsOption,
    courtCategoryId: catId,
    district: districtId,
    // division is resolved from districtIdsByDivision lookup
    division: districtIdsByDivision.entries
        .firstWhereOrNull((e) => e.value.contains(districtId))
        ?.key,
  );
}

/// Court name data: district → category → list of (English, Bengali) pairs.
typedef _CourtNamesByCategory = Map<String, List<(String, String)>>;

/// Lower court names keyed by district then by category.
/// Format: {districtId: {categoryId: [(nameEn, nameBn), ...]}}
// ignore: non_constant_identifier_names
final Map<String, _CourtNamesByCategory>
_lowerCourtNamesData = <String, _CourtNamesByCategory>{
  'dhaka': <String, List<(String, String)>>{
    districtSessionsCriminalId: <(String, String)>[
      ('District Judge Court', 'জেলা জজ আদালত'),
      ('Additional District Judge Court-1', 'অতিরিক্ত জেলা জজ আদালত-১'),
      ('Additional District Judge Court-2', 'অতিরিক্ত জেলা জজ আদালত-২'),
      ('Additional District Judge Court-3', 'অতিরিক্ত জেলা জজ আদালত-৩'),
      ('Additional District Judge Court-4', 'অতিরিক্ত জেলা জজ আদালত-৪'),
      ('Additional District Judge Court-5', 'অতিরিক্ত জেলা জজ আদালত-৫'),
      (
        'Joint District & Sessions Judge Court-1',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-১',
      ),
      (
        'Joint District & Sessions Judge Court-2',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-২',
      ),
      (
        'Joint District & Sessions Judge Court-3',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৩',
      ),
      (
        'Joint District & Sessions Judge Court-4',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৪',
      ),
      (
        'Joint District & Sessions Judge Court-5',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৫',
      ),
      (
        'Joint District & Sessions Judge Court-6',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৬',
      ),
      (
        'Joint District & Sessions Judge Court-7',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৭',
      ),
      (
        'Joint District & Sessions Judge Court-8',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৮',
      ),
      (
        'Joint District & Sessions Judge Court-9',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৯',
      ),
      (
        'Joint District & Sessions Judge Court-10',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-১০',
      ),
    ],
    districtCourtsCivilId: <(String, String)>[
      ('Senior Assistant Judge Court-1', 'সিনিয়র সহকারী জজ আদালত-১'),
      ('Senior Assistant Judge Court-2', 'সিনিয়র সহকারী জজ আদালত-২'),
      ('Senior Assistant Judge Court-3', 'সিনিয়র সহকারী জজ আদালত-৩'),
      ('Assistant Judge Court-1', 'সহকারী জজ আদালত-১'),
      ('Assistant Judge Court-2', 'সহকারী জজ আদালত-২'),
      ('Assistant Judge Court-3', 'সহকারী জজ আদালত-৩'),
      ('Assistant Judge Court-4', 'সহকারী জজ আদালত-৪'),
      ('Assistant Judge Court-5', 'সহকারী জজ আদালত-৫'),
      ('Assistant Judge Court-6', 'সহকারী জজ আদালত-৬'),
      ('Assistant Judge Court-7', 'সহকারী জজ আদালত-৭'),
      ('Assistant Judge Court-8', 'সহকারী জজ আদালত-৮'),
      ('Assistant Judge Court-9', 'সহকারী জজ আদালত-৯'),
      ('Assistant Judge Court-10', 'সহকারী জজ আদালত-১০'),
    ],
    chiefJudicialMagistrateId: <(String, String)>[
      ('Chief Judicial Magistrate Court', 'চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত'),
      (
        'Additional Chief Judicial Magistrate Court-1',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-১',
      ),
      (
        'Additional Chief Judicial Magistrate Court-2',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-২',
      ),
      (
        'Additional Chief Judicial Magistrate Court-3',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৩',
      ),
      ('Judicial Magistrate Court-1', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-১'),
      ('Judicial Magistrate Court-2', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-২'),
      ('Judicial Magistrate Court-3', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৩'),
      ('Judicial Magistrate Court-4', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৪'),
      ('Judicial Magistrate Court-5', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৫'),
    ],
    chiefMetropolitanMagistrateId: <(String, String)>[
      (
        'Chief Metropolitan Magistrate Court',
        'চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত',
      ),
      (
        'Additional Chief Metropolitan Magistrate Court-1',
        'অতিরিক্ত চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-১',
      ),
      (
        'Additional Chief Metropolitan Magistrate Court-2',
        'অতিরিক্ত চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-২',
      ),
      ('Metropolitan Magistrate Court-1', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-১'),
      ('Metropolitan Magistrate Court-2', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-২'),
      ('Metropolitan Magistrate Court-3', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৩'),
      ('Metropolitan Magistrate Court-4', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৪'),
      ('Metropolitan Magistrate Court-5', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৫'),
    ],
    executiveMagistrateId: <(String, String)>[
      ('Executive Magistrate Court', 'নির্বাহী ম্যাজিস্ট্রেট আদালত'),
    ],
    tribunalsId: <(String, String)>[
      ('Money Loan Court (Artha Rin Adalat)', 'অর্থঋণ আদালত'),
      (
        'Women & Children Repression Prevention Tribunal',
        'নারী ও শিশু নির্যাতন দমন ট্রাইব্যুনাল',
      ),
      ('Speedy Trial Tribunal', 'দ্রুত বিচার ট্রাইব্যুনাল'),
      ('Land Survey Tribunal', 'ভূমি জরিপ ট্রাইব্যুনাল'),
      ('Cyber Tribunal', 'সাইবার ট্রাইব্যুনাল'),
      ('Labour Court', 'শ্রম আদালত'),
      (
        'Nari O Shishu Nirjatan Daman Tribunal',
        'নারী ও শিশু নির্যাতন দমন ট্রাইব্যুনাল',
      ),
    ],
  },
  'narayanganj': <String, List<(String, String)>>{
    districtSessionsCriminalId: <(String, String)>[
      ('District Judge Court', 'জেলা জজ আদালত'),
      ('Additional District Judge Court-1', 'অতিরিক্ত জেলা জজ আদালত-১'),
      ('Additional District Judge Court-2', 'অতিরিক্ত জেলা জজ আদালত-২'),
      ('Additional District Judge Court-3', 'অতিরিক্ত জেলা জজ আদালত-৩'),
      ('Additional District Judge Court-4', 'অতিরিক্ত জেলা জজ আদালত-৪'),
      ('Additional District Judge Court-5', 'অতিরিক্ত জেলা জজ আদালত-৫'),
      (
        'Joint District & Sessions Judge Court-1',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-১',
      ),
      (
        'Joint District & Sessions Judge Court-2',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-২',
      ),
      (
        'Joint District & Sessions Judge Court-3',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৩',
      ),
      (
        'Joint District & Sessions Judge Court-4',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৪',
      ),
      (
        'Joint District & Sessions Judge Court-5',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৫',
      ),
      (
        'Joint District & Sessions Judge Court-6',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৬',
      ),
      (
        'Joint District & Sessions Judge Court-7',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৭',
      ),
      (
        'Joint District & Sessions Judge Court-8',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৮',
      ),
      (
        'Joint District & Sessions Judge Court-9',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-৯',
      ),
      (
        'Joint District & Sessions Judge Court-10',
        'যুগ্ম জেলা ও দায়রা জজ আদালত-১০',
      ),
    ],
    districtCourtsCivilId: <(String, String)>[
      ('Senior Assistant Judge Court-1', 'সিনিয়র সহকারী জজ আদালত-১'),
      ('Senior Assistant Judge Court-2', 'সিনিয়র সহকারী জজ আদালত-২'),
      ('Senior Assistant Judge Court-3', 'সিনিয়র সহকারী জজ আদালত-৩'),
      ('Assistant Judge Court-1', 'সহকারী জজ আদালত-১'),
      ('Assistant Judge Court-2', 'সহকারী জজ আদালত-২'),
      ('Assistant Judge Court-3', 'সহকারী জজ আদালত-৩'),
      ('Assistant Judge Court-4', 'সহকারী জজ আদালত-৪'),
      ('Assistant Judge Court-5', 'সহকারী জজ আদালত-৫'),
      ('Assistant Judge Court-6', 'সহকারী জজ আদালত-৬'),
      ('Assistant Judge Court-7', 'সহকারী জজ আদালত-৭'),
      ('Assistant Judge Court-8', 'সহকারী জজ আদালত-৮'),
      ('Assistant Judge Court-9', 'সহকারী জজ আদালত-৯'),
      ('Assistant Judge Court-10', 'সহকারী জজ আদালত-১০'),
    ],
    chiefJudicialMagistrateId: <(String, String)>[
      ('Chief Judicial Magistrate Court', 'চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত'),
      (
        'Additional Chief Judicial Magistrate Court-1',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-১',
      ),
      (
        'Additional Chief Judicial Magistrate Court-2',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-২',
      ),
      (
        'Additional Chief Judicial Magistrate Court-3',
        'অতিরিক্ত চীফ জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৩',
      ),
      ('Judicial Magistrate Court-1', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-১'),
      ('Judicial Magistrate Court-2', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-২'),
      ('Judicial Magistrate Court-3', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৩'),
      ('Judicial Magistrate Court-4', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৪'),
      ('Judicial Magistrate Court-5', 'জুডিশিয়াল ম্যাজিস্ট্রেট আদালত-৫'),
    ],
    chiefMetropolitanMagistrateId: <(String, String)>[
      (
        'Chief Metropolitan Magistrate Court',
        'চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত',
      ),
      (
        'Additional Chief Metropolitan Magistrate Court-1',
        'অতিরিক্ত চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-১',
      ),
      (
        'Additional Chief Metropolitan Magistrate Court-2',
        'অতিরিক্ত চীফ মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-২',
      ),
      ('Metropolitan Magistrate Court-1', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-১'),
      ('Metropolitan Magistrate Court-2', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-২'),
      ('Metropolitan Magistrate Court-3', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৩'),
      ('Metropolitan Magistrate Court-4', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৪'),
      ('Metropolitan Magistrate Court-5', 'মেট্রোপলিটন ম্যাজিস্ট্রেট আদালত-৫'),
    ],
    executiveMagistrateId: <(String, String)>[
      ('Executive Magistrate Court', 'নির্বাহী ম্যাজিস্ট্রেট আদালত'),
    ],
    tribunalsId: <(String, String)>[
      ('Money Loan Court (Artha Rin Adalat)', 'অর্থঋণ আদালত'),
      (
        'Women & Children Repression Prevention Tribunal',
        'নারী ও শিশু নির্যাতন দমন ট্রাইব্যুনাল',
      ),
      ('Speedy Trial Tribunal', 'দ্রুত বিচার ট্রাইব্যুনাল'),
      ('Land Survey Tribunal', 'ভূমি জরিপ ট্রাইব্যুনাল'),
      ('Cyber Tribunal', 'সাইবার ট্রাইব্যুনাল'),
      ('Labour Court', 'শ্রম আদালত'),
      (
        'Nari O Shishu Nirjatan Daman Tribunal',
        'নারী ও শিশু নির্যাতন দমন ট্রাইব্যুনাল',
      ),
    ],
  },
};

/// Flattened list of all pre-seeded lower court entries.
final List<SeedCourt> lowerCourtNames = _lowerCourtNamesData.entries
    .expand(
      (districtEntry) => districtEntry.value.entries.expand(
        (catEntry) => catEntry.value.map(
          (namePair) =>
              _lc(catEntry.key, districtEntry.key, namePair.$1, namePair.$2),
        ),
      ),
    )
    .toList();

/// All pre-seeded courts (supreme + lower).
final List<SeedCourt> allSeedCourts = [
  ...supremeCourtNames,
  ...lowerCourtNames,
];

// ---------------------------------------------------------------------------
// Disposed steps
// ---------------------------------------------------------------------------

/// Set of step stable IDs that count as "disposed".
/// Used by Disposed/Active Cases screens — case disposal is derived
/// from `last_step`, not a `status` column.
const Set<String> disposedStepIds = <String>{
  // Appellate Division
  'step-appellate_division-disposed',
  'step-appellate_division-judgment',
  // High Court Division
  'step-high_court_division-disposed',
  'step-high_court_division-judgment',
  'step-high_court_division-rule_discharged',
  // District Sessions Criminal
  'step-district_sessions_criminal-disposed',
  'step-district_sessions_criminal-judgment',
  'step-district_sessions_criminal-acquitted',
  'step-district_sessions_criminal-convicted',
  // District Courts Civil
  'step-district_courts_civil-disposed',
  'step-district_courts_civil-decree_passed',
  'step-district_courts_civil-dismissed',
  // Chief Judicial Magistrate
  'step-chief_judicial_magistrate-disposed',
  'step-chief_judicial_magistrate-judgment',
  'step-chief_judicial_magistrate-acquitted',
  'step-chief_judicial_magistrate-convicted',
  // Chief Metropolitan Magistrate
  'step-chief_metropolitan_magistrate-disposed',
  'step-chief_metropolitan_magistrate-judgment',
  'step-chief_metropolitan_magistrate-acquitted',
  'step-chief_metropolitan_magistrate-convicted',
  // Executive Magistrate
  'step-executive_magistrate-disposed',
  'step-executive_magistrate-order',
  // Tribunals
  'step-tribunals-disposed',
  'step-tribunals-order',
  'step-tribunals-award',
};

// ---------------------------------------------------------------------------
// Comprehensive label maps (stable ID → label, both languages)
// These support runtime label resolution in AppTranslations.
// ---------------------------------------------------------------------------

/// All step stable IDs → English label.
final Map<String, String> stepLabelEn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand((c) => c.steps.map((s) => MapEntry(s.id, s.labelEn))),
  ),
);

/// All step stable IDs → Bengali label.
final Map<String, String> stepLabelBn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand((c) => c.steps.map((s) => MapEntry(s.id, s.labelBn))),
  ),
);

/// All case type stable IDs → English label.
final Map<String, String> caseTypeLabelEn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.caseTypes.map((ct) => MapEntry(ct.id, ct.labelEn)),
    ),
  ),
);

/// All case type stable IDs → Bengali label.
final Map<String, String> caseTypeLabelBn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.caseTypes.map((ct) => MapEntry(ct.id, ct.labelBn)),
    ),
  ),
);

/// All on-behalf stable IDs → English label.
final Map<String, String> onBehalfLabelEn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.onBehalfs.map((o) => MapEntry(o.id, o.labelEn)),
    ),
  ),
);

/// All on-behalf stable IDs → Bengali label.
final Map<String, String> onBehalfLabelBn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.onBehalfs.map((o) => MapEntry(o.id, o.labelBn)),
    ),
  ),
);

/// All court stable IDs → English label.
final Map<String, String> courtLabelEn = Map.unmodifiable(
  Map.fromEntries(allSeedCourts.map((c) => MapEntry(c.id, c.courtNameEn))),
);

/// All court stable IDs → Bengali label.
final Map<String, String> courtLabelBn = Map.unmodifiable(
  Map.fromEntries(allSeedCourts.map((c) => MapEntry(c.id, c.courtNameBn))),
);

// ---------------------------------------------------------------------------
// Higher/lower court options (used in add/edit case form)
// ---------------------------------------------------------------------------

/// The three higher/lower court selection options with stable IDs.
final List<SeedOption> higherLowerCourtOptions = <SeedOption>[
  SeedOption(
    id: 'appellate_division',
    labelEn: 'Appellate Division',
    labelBn: 'আপিল বিভাগ',
    orderIndex: 0,
  ),
  SeedOption(
    id: 'high_court_division',
    labelEn: 'High Court Division',
    labelBn: 'হাই কোর্ট বিভাগ',
    orderIndex: 1,
  ),
  SeedOption(
    id: 'lower_divisional_courts',
    labelEn: 'Lower Divisional Courts',
    labelBn: 'নিম্ন আদালত',
    orderIndex: 2,
  ),
];
