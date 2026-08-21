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
    this.caseCategoryId,
  });

  final String id;
  final String labelEn;
  final String labelBn;
  final int orderIndex;

  /// Case-category scope for AD/HCD case-type options; null for other seed
  /// options and lower-court case types.
  final String? caseCategoryId;
}

/// A case category nested under a canonical court category.
class SeedCaseCategory {
  const SeedCaseCategory({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.orderIndex,
    required this.caseTypes,
  });

  final String id;
  final String labelEn;
  final String labelBn;
  final int orderIndex;
  final List<SeedOption> caseTypes;
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
    this.caseTypes = const <SeedOption>[],
    this.caseCategories = const <SeedCaseCategory>[],
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

  /// Flat case types for lower-court categories, scoped by court category.
  final List<SeedOption> caseTypes;

  /// AD/HCD case categories and their nested case types.
  final List<SeedCaseCategory> caseCategories;
  final List<SeedOption> onBehalfs;

  /// All case types for this court category, preserving seed order.
  List<SeedOption> get allCaseTypes => <SeedOption>[
    ...caseTypes,
    ...caseCategories.expand((category) => category.caseTypes),
  ];
}

/// A pre-seeded court (supreme court or lower court).
class SeedCourt {
  const SeedCourt({
    required this.id,
    required this.courtNameEn,
    required this.courtNameBn,
    required this.higherLowerCourts,
    required this.courtCategoryId,
    this.orderIndex = 0,
    this.division,
    this.district,
  });

  final String id;
  final String courtNameEn;
  final String courtNameBn;
  final String higherLowerCourts;
  final String courtCategoryId;
  final int orderIndex;
  final String? division;
  final String? district;
}

// ---------------------------------------------------------------------------
// Helper: make a stable ID for seed items
// ---------------------------------------------------------------------------

String _stepId(String catId, String nameSlug) => 'step-$catId-$nameSlug';
String _caseCategoryId(String catId, String nameSlug) =>
    'casecategory-$catId-$nameSlug';
String _caseTypeId(String catId, String nameSlug, {String? caseCategorySlug}) =>
    caseCategorySlug == null
    ? 'casetype-$catId-$nameSlug'
    : 'casetype-$catId-$caseCategorySlug-$nameSlug';
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
  'jhalokathi': 'ঝালকাঠি',
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
  // -- Appellate Division -----------------------------------------------
  SeedCategory(
    id: appellateDivisionId,
    nameKey: 'courtCategory_appellateDivision',
    courtLevel: 'appellate',
    orderIndex: 0,
    steps: const <SeedOption>[],
    caseCategories: <SeedCaseCategory>[
      SeedCaseCategory(
        id: _caseCategoryId(appellateDivisionId, 'civil_cases'),
        labelEn: 'Civil Cases',
        labelBn: 'দেওয়ানি মোকদ্দমা',
        orderIndex: 0,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'civil_appeal',
              caseCategorySlug: 'civil_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'civil_cases'),
            labelEn: 'Civil Appeal',
            labelBn: 'দেওয়ানি আপিল',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'civil_petition',
              caseCategorySlug: 'civil_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'civil_cases'),
            labelEn: 'Civil Petition',
            labelBn: 'দেওয়ানি পিটিশন',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'civil_misc_petition',
              caseCategorySlug: 'civil_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'civil_cases'),
            labelEn: 'Civil Misc Petition',
            labelBn: 'দেওয়ানি মিছ পিটিশন',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'civil_review_petition',
              caseCategorySlug: 'civil_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'civil_cases'),
            labelEn: 'Civil Review Petition',
            labelBn: 'দেওয়ানি রিভিউ পিটিশন',
            orderIndex: 3,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(appellateDivisionId, 'contempt_cases'),
        labelEn: 'Contempt Cases',
        labelBn: 'কন্টেম্পট মোকদ্দমা',
        orderIndex: 1,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'contempt_petition_a',
              caseCategorySlug: 'contempt_cases',
            ),
            caseCategoryId: _caseCategoryId(
              appellateDivisionId,
              'contempt_cases',
            ),
            labelEn: 'Contempt Petition(A)',
            labelBn: 'কন্টেম্পট পিটিশন(A)',
            orderIndex: 0,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(appellateDivisionId, 'criminal_cases_ad'),
        labelEn: 'Criminal Cases(AD)',
        labelBn: 'ফৌজদারি মামলা (আপিল বিভাগ)',
        orderIndex: 2,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'criminal_appeal_a',
              caseCategorySlug: 'criminal_cases_ad',
            ),
            caseCategoryId: _caseCategoryId(
              appellateDivisionId,
              'criminal_cases_ad',
            ),
            labelEn: 'Criminal Appeal(A)',
            labelBn: 'ফৌজদারি আপিল(A)',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'criminal_petition',
              caseCategorySlug: 'criminal_cases_ad',
            ),
            caseCategoryId: _caseCategoryId(
              appellateDivisionId,
              'criminal_cases_ad',
            ),
            labelEn: 'Criminal Petition',
            labelBn: 'ফৌজদারি পিটিশন',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'criminal_misc_petition',
              caseCategorySlug: 'criminal_cases_ad',
            ),
            caseCategoryId: _caseCategoryId(
              appellateDivisionId,
              'criminal_cases_ad',
            ),
            labelEn: 'Criminal Misc Petition',
            labelBn: 'ফৌজদারি মিছ পিটিশন',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'criminal_review_petition',
              caseCategorySlug: 'criminal_cases_ad',
            ),
            caseCategoryId: _caseCategoryId(
              appellateDivisionId,
              'criminal_cases_ad',
            ),
            labelEn: 'Criminal Review Petition',
            labelBn: 'ফৌজদারি রিভিউ পিটিশন',
            orderIndex: 3,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(appellateDivisionId, 'jail_cases'),
        labelEn: 'Jail Cases',
        labelBn: 'জেল মামলা',
        orderIndex: 3,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'jail_petition',
              caseCategorySlug: 'jail_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'jail_cases'),
            labelEn: 'Jail Petition',
            labelBn: 'জেল পিটশন',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              appellateDivisionId,
              'jail_appeal_a',
              caseCategorySlug: 'jail_cases',
            ),
            caseCategoryId: _caseCategoryId(appellateDivisionId, 'jail_cases'),
            labelEn: 'Jail Appeal(A)',
            labelBn: 'জেল আপিল(A)',
            orderIndex: 1,
          ),
        ],
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(appellateDivisionId, 'petitioner'),
        labelEn: 'Petitioner',
        labelBn: 'দরখাস্তকারী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(appellateDivisionId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'প্রতিপক্ষ',
        orderIndex: 1,
      ),
    ],
  ),
  // -- High Court Division -----------------------------------------------
  SeedCategory(
    id: highCourtDivisionId,
    nameKey: 'courtCategory_highCourtDivision',
    courtLevel: 'high_court',
    orderIndex: 1,
    steps: const <SeedOption>[],
    caseCategories: <SeedCaseCategory>[
      SeedCaseCategory(
        id: _caseCategoryId(highCourtDivisionId, 'civil_appeal'),
        labelEn: 'Civil Appeal',
        labelBn: 'দেওয়ানি আপিল',
        orderIndex: 0,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'election_petition',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Election Petition',
            labelBn: 'ইলেকশন পিটিশন',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'first_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'First Appeal',
            labelBn: '১ম আপিল',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'second_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Second Appeal',
            labelBn: '২য় আপিল',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'first_misc_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'First Misc Appeal',
            labelBn: '১ম মিছ আপিল',
            orderIndex: 3,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'second_misc_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Second Misc Appeal',
            labelBn: '২য় মিছ আপিল',
            orderIndex: 4,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'cross_objection',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Cross Objection',
            labelBn: 'ক্রস অবজেকশন',
            orderIndex: 5,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'transfer_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Transfer Appeal',
            labelBn: 'বদলী আপিল',
            orderIndex: 6,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'first_appeal_tender',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'First Appeal Tender',
            labelBn: '১ম আপিল টেন্ডার',
            orderIndex: 7,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'first_misc_appeal_tender',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'First Misc Appeal Tender',
            labelBn: '১ম মিছ আপিল টেন্ডার',
            orderIndex: 8,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_civil_rule',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'VC Civil Rule',
            labelBn: 'ভিসি সিভিল রুল',
            orderIndex: 9,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc_f_m_a',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'In re: VC F M A',
            labelBn: 'ইন রেঃ ভিসি এফ এম এ',
            orderIndex: 10,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc_f_a',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'In re: VC F A',
            labelBn: 'ইন রেঃ ভিসি এফ এ',
            orderIndex: 11,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_first_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'VC First Appeal',
            labelBn: 'ভিসি ১ম আপিল',
            orderIndex: 12,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'title_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Title Appeal',
            labelBn: 'টাইটেল আপিল',
            orderIndex: 13,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'bankruptcy_appeal',
              caseCategorySlug: 'civil_appeal',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_appeal',
            ),
            labelEn: 'Bankruptcy Appeal',
            labelBn: 'ব্যাংক্রাপ্সি আপিল',
            orderIndex: 14,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(highCourtDivisionId, 'civil_revision'),
        labelEn: 'Civil Revision',
        labelBn: 'দেওয়ানি রিভিশন',
        orderIndex: 1,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_rule',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Rule',
            labelBn: 'দেওয়ানি রুল',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_revision',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Revision',
            labelBn: 'দেওয়ানি রিভিশন',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_misc',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Misc',
            labelBn: 'দেওয়ানি মিছ',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_order',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Order',
            labelBn: 'দেওয়ানি আদেশ',
            orderIndex: 3,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'contempt',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Contempt',
            labelBn: 'কন্টেম্পট',
            orderIndex: 4,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_review',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Review',
            labelBn: 'দেওয়ানি রিভিউ',
            orderIndex: 5,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'violation_misc',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Violation Misc',
            labelBn: 'ভায়োলেশন মিছ',
            orderIndex: 6,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc_violation_misc',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'In-re VC Violation Misc',
            labelBn: 'ইন রেঃ ভিসি ভায়োলেশন মিছ',
            orderIndex: 7,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'violation_case',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Violation Case',
            labelBn: 'ভায়োলেশন মোকদ্দমা',
            orderIndex: 8,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'violation_misc_rule',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Violation Misc Rule',
            labelBn: 'ভায়োলেশন মিছ রুল',
            orderIndex: 9,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_contempt_petition_h',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'VC Contempt Petition (H)',
            labelBn: 'ভিসি কন্টেম্পট পিটিশন (H)',
            orderIndex: 10,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc_civil_revision',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'In re: VC Civil Revision',
            labelBn: 'ইন রেঃ ভিসি দেওয়ানি রিভিশন',
            orderIndex: 11,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_civil_revision',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'VC Civil Revision',
            labelBn: 'ভিসি দেওয়ানি রিভিশন',
            orderIndex: 12,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_reference_case',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Reference Case',
            labelBn: 'দেওয়ানি রেফারেন্স মোকদ্দমা',
            orderIndex: 13,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_case',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Case',
            labelBn: 'দেওয়ানি মোকদ্দমা',
            orderIndex: 14,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'civil_rule_contempt',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Civil Rule (Contempt)',
            labelBn: 'দেওয়ানি রুল (কন্টেম্পট)',
            orderIndex: 15,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'transfer_miscellaneous_case',
              caseCategorySlug: 'civil_revision',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'civil_revision',
            ),
            labelEn: 'Transfer Miscellaneous Case',
            labelBn: 'বদলি মিছ মোকদ্দমা',
            orderIndex: 16,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(highCourtDivisionId, 'criminal_cases_hd'),
        labelEn: 'Criminal Cases(HD)',
        labelBn: 'ফৌজদারি মামলা (হাইকোর্ট বিভাগ)',
        orderIndex: 2,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_rule_con_a',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Rule(Con A)',
            labelBn: 'ফৌজদারি রুল(Con A)',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_misc_suo_muto_rule',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Misc (Suo-Muto) Rule',
            labelBn: 'ফৌজদারি মিছ (সু-মোটো) রুল',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'death_reference',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Death Reference',
            labelBn: 'ডেথ রেফারেন্স',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_appeal_h',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Appeal(H)',
            labelBn: 'ফৌজদারি আপিল(H)',
            orderIndex: 3,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_revision',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Revision',
            labelBn: 'ফৌজদারি রিভিশন',
            orderIndex: 4,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_misc',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Misc',
            labelBn: 'ফৌজদারি মিছ',
            orderIndex: 5,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'jail_appeal_h',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Jail Appeal(H)',
            labelBn: 'জেল আপিল(H)',
            orderIndex: 6,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_rule',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Rule',
            labelBn: 'ফৌজদারি রুল',
            orderIndex: 7,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'jail_appeal_admission',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Jail Appeal Admission',
            labelBn: 'জেল আপিল এডমিশন',
            orderIndex: 8,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'suo_muto',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Suo Muto',
            labelBn: 'সু-মোটো',
            orderIndex: 9,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'govt_appeal',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Govt. Appeal',
            labelBn: 'সরকারি আপিল',
            orderIndex: 10,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'In re',
            labelBn: 'ইন রে',
            orderIndex: 11,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_rule_con',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Rule(Con)',
            labelBn: 'ফৌজদারি রুল(Con)',
            orderIndex: 12,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'transfer_misc_case',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Transfer Misc Case',
            labelBn: 'বদলি মিছ মামলা',
            orderIndex: 13,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'suo_muto_contempt_rule',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Suo-Muto Contempt Rule',
            labelBn: 'সু-মোটো কন্টেম্পট',
            orderIndex: 14,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_revision_suo_muto',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Revision (Suo-Muto)',
            labelBn: 'ফৌজদারি রিভিশন (সু-মোটো)',
            orderIndex: 15,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'govt_criminal_appeal',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Govt. Criminal Appeal',
            labelBn: 'ফৌজদারি সরকারি আপিল',
            orderIndex: 16,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'criminal_review_rule',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Criminal Review Rule',
            labelBn: 'ফৌজদারি রিভিউ রুল',
            orderIndex: 17,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_criminal_misc_case',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'VC Criminal Misc Case',
            labelBn: 'ভিসি ফৌজদারি মিছ মামলা',
            orderIndex: 18,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_criminal_appeal',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'VC Criminal Appeal',
            labelBn: 'ভিসি ফৌজদারি আপিল',
            orderIndex: 19,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'In re: VC',
            labelBn: 'ইন রেঃ ভিসি',
            orderIndex: 20,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_criminal_revision',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'VC Criminal Revision',
            labelBn: 'ভিসি ফৌজদারি রিভিশন',
            orderIndex: 21,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'departmental_case',
              caseCategorySlug: 'criminal_cases_hd',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'criminal_cases_hd',
            ),
            labelEn: 'Departmental Case',
            labelBn: 'বিভাগীয় মামলা',
            orderIndex: 22,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(highCourtDivisionId, 'original_cases'),
        labelEn: 'Original Cases',
        labelBn: 'আদি মামলা',
        orderIndex: 3,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'letter_of_administration_suit',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Letter of Administration Suit',
            labelBn: 'লেটার অফ এডমিনিস্ট্রেশন স্যুট',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'violation_misc',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Violation Misc',
            labelBn: 'ভায়োলেশন মিছ',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'review_petition',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Review Petition',
            labelBn: 'রিভিউ পিটিশন',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'suo_muto_original',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Suo-Muto (Original)',
            labelBn: 'সু-মোটো (আদি)',
            orderIndex: 3,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'execution_case',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Execution Case',
            labelBn: 'জারি মামলা',
            orderIndex: 4,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'company_matter',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Company Matter',
            labelBn: 'কোম্পানি ম্যাটার',
            orderIndex: 5,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'contempt_matter',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Contempt Matter',
            labelBn: 'কন্টেম্পট ম্যাটার',
            orderIndex: 6,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'customs_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Customs Appeal',
            labelBn: 'কাস্টমস আপিল',
            orderIndex: 7,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'divorce_suit',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Divorce Suit',
            labelBn: 'ডিভোর্স মামলা',
            orderIndex: 8,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'income_tax_reference',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Income Tax Reference',
            labelBn: 'ইনকাম ট্যাক্স রেফারেন্স',
            orderIndex: 9,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'merchant_shipping',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Merchant Shipping',
            labelBn: 'মার্চেন্ট শিপিং',
            orderIndex: 10,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'trademark_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Trademark Appeal',
            labelBn: 'ট্রেডমার্ক আপিল',
            orderIndex: 11,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'trademark_application',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Trademark Application',
            labelBn: 'ট্রেডমার্ক এপ্লিকেশন',
            orderIndex: 12,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vat_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'VAT Appeal',
            labelBn: 'ভ্যাট আপিল',
            orderIndex: 13,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'admiralty_suit',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Admiralty Suit',
            labelBn: 'এডমিরালটি মামলা',
            orderIndex: 14,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'admiralty_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Admiralty Appeal',
            labelBn: 'এডমিরালটি আপিল',
            orderIndex: 15,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'arbitration_application',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Arbitration Application',
            labelBn: 'আরবিট্রেশন এপ্লিকেশন',
            orderIndex: 16,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'cancellation_of_design_petition',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Cancellation of Design Petition',
            labelBn: 'ডিজাইন পিটিশন বাতিলের দরখাস্ত',
            orderIndex: 17,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'contempt_petition',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Contempt Petition',
            labelBn: 'কন্টেম্পট পিটিশন',
            orderIndex: 18,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'contempt_rule',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Contempt Rule',
            labelBn: 'কন্টেম্পট রুল',
            orderIndex: 19,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'summary_suit',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Summary Suit',
            labelBn: 'সামারি স্যুট',
            orderIndex: 20,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'arbitration_rule',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Arbitration Rule',
            labelBn: 'আরবিট্রেশন রুল',
            orderIndex: 21,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'bank_company_application',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Bank Company Application',
            labelBn: 'ব্যাংক কোম্পানি এপ্লিকেশন',
            orderIndex: 22,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'family_matter',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Family Matter',
            labelBn: 'ফ্যামিলি ম্যাটার',
            orderIndex: 23,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vat_revision',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'VAT Revision',
            labelBn: 'ভ্যাট রিভিশন',
            orderIndex: 24,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'bank_company_matter',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Bank Company Matter',
            labelBn: 'ব্যাংক কোম্পানি ম্যাটার',
            orderIndex: 25,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'industrial_design_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Industrial Design Appeal',
            labelBn: 'ইন্ডাস্ট্রিয়াল ডিজাইন আপিল',
            orderIndex: 26,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'cancellation_of_trademark_petition',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Cancellation of Trademark Petition',
            labelBn: 'ট্রেডমার্ক বাতিলের দরখাস্ত',
            orderIndex: 27,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'financial_institution',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Financial Institution',
            labelBn: 'ফাইনান্সিয়াল ইন্সটিটিউশন',
            orderIndex: 28,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'insurance_appeal',
              caseCategorySlug: 'original_cases',
            ),
            caseCategoryId: _caseCategoryId(
              highCourtDivisionId,
              'original_cases',
            ),
            labelEn: 'Insurance Appeal',
            labelBn: 'ইনসিউরেন্স আপিল',
            orderIndex: 29,
          ),
        ],
      ),
      SeedCaseCategory(
        id: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
        labelEn: 'Writ Cases',
        labelBn: 'রিট মামলা',
        orderIndex: 4,
        caseTypes: <SeedOption>[
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_writ_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'In re: Writ Petition',
            labelBn: 'ইন রেঃ রিট পিটিশন',
            orderIndex: 0,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'writ_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Writ Petition',
            labelBn: 'রিট পিটিশন',
            orderIndex: 1,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'contempt_petition_h',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Contempt Petition(H)',
            labelBn: 'কন্টেম্পট পিটিশন(H)',
            orderIndex: 2,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'review_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Review Petition',
            labelBn: 'রিভিউ পিটিশন',
            orderIndex: 3,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'suo_muto_rule',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Suo-Muto Rule',
            labelBn: 'সু-মোটো রুল',
            orderIndex: 4,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'transfer_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Transfer Petition',
            labelBn: 'বদলি পিটিশন',
            orderIndex: 5,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'reference_application',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Reference Application',
            labelBn: 'রেফারেন্স এপ্লিকেশন',
            orderIndex: 6,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'i_t_r',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'I.T.R',
            labelBn: 'আই টি আর',
            orderIndex: 7,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'rule',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Rule',
            labelBn: 'রুল',
            orderIndex: 8,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'in_re_vc_writ_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'In re: VC Writ Petition',
            labelBn: 'ইন রেঃ ভিসি রিট পিটিশন',
            orderIndex: 9,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'copy_right_appeal',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Copy Right Appeal',
            labelBn: 'কপি রাইট আপিল',
            orderIndex: 10,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'vc_writ_petition',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'VC Writ Petition',
            labelBn: 'ভিসি রিট পিটিশন',
            orderIndex: 11,
          ),
          SeedOption(
            id: _caseTypeId(
              highCourtDivisionId,
              'suo_muto_rule_contempt',
              caseCategorySlug: 'writ_cases',
            ),
            caseCategoryId: _caseCategoryId(highCourtDivisionId, 'writ_cases'),
            labelEn: 'Suo-Muto Rule Contempt',
            labelBn: 'সু-মোটো রুল কন্টেম্পট',
            orderIndex: 12,
          ),
        ],
      ),
    ],
    onBehalfs: <SeedOption>[
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'petitioner'),
        labelEn: 'Petitioner',
        labelBn: 'দরখাস্তকারী',
        orderIndex: 0,
      ),
      SeedOption(
        id: _onBehalfId(highCourtDivisionId, 'respondent'),
        labelEn: 'Respondent',
        labelBn: 'প্রতিপক্ষ',
        orderIndex: 1,
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

/// Map: court-category stable ID → list of case-category stable IDs.
final Map<String, List<String>> caseCategoryIdsByCategory = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.map(
      (c) => MapEntry(c.id, c.caseCategories.map((cc) => cc.id).toList()),
    ),
  ),
);

/// Map: case-category stable ID → case category definition.
final Map<String, SeedCaseCategory> seedCaseCategoryById = Map.unmodifiable(
  Map.fromEntries(
    seedCategories
        .expand((c) => c.caseCategories)
        .map((cc) => MapEntry(cc.id, cc)),
  ),
);

/// Map: court-category stable ID → list of case type stable IDs.
final Map<String, List<String>> caseTypeIdsByCategory = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.map(
      (c) => MapEntry(c.id, c.allCaseTypes.map((ct) => ct.id).toList()),
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

/// Pre-seeded supreme court names in the source-file order.
final List<SeedCourt> supremeCourtNames = <SeedCourt>[
  SeedCourt(
    id: _supremeCourtId(appellateDivisionId, _slug('COURT NO. 1')),
    courtNameEn: 'COURT NO. 1',
    courtNameBn: 'কোর্ট নং- ১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: appellateDivisionId,
    orderIndex: 0,
  ),
  SeedCourt(
    id: _supremeCourtId(appellateDivisionId, _slug('JUDGE-IN-CHAMBER')),
    courtNameEn: 'JUDGE-IN-CHAMBER',
    courtNameBn: 'চেম্বার জজ',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: appellateDivisionId,
    orderIndex: 1,
  ),
  SeedCourt(
    id: _supremeCourtId(appellateDivisionId, _slug('JUDGE-IN-CHAMBER 2')),
    courtNameEn: 'JUDGE-IN-CHAMBER 2',
    courtNameBn: 'চেম্বার জজ ২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: appellateDivisionId,
    orderIndex: 2,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 1'),
    ),
    courtNameEn: 'Annex Building Court No. 1',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 0,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 2'),
    ),
    courtNameEn: 'Annex Building Court No. 2',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 1,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 3'),
    ),
    courtNameEn: 'Annex Building Court No. 3',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 2,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 4'),
    ),
    courtNameEn: 'Annex Building Court No. 4',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৪',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 3,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 5'),
    ),
    courtNameEn: 'Annex Building Court No. 5',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৫',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 4,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 6'),
    ),
    courtNameEn: 'Annex Building Court No. 6',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৬',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 5,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 7'),
    ),
    courtNameEn: 'Annex Building Court No. 7',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৭',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 6,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 8'),
    ),
    courtNameEn: 'Annex Building Court No. 8',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৮',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 7,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 9'),
    ),
    courtNameEn: 'Annex Building Court No. 9',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৯',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 8,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 10'),
    ),
    courtNameEn: 'Annex Building Court No. 10',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১০',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 9,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 11'),
    ),
    courtNameEn: 'Annex Building Court No. 11',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 10,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 12'),
    ),
    courtNameEn: 'Annex Building Court No. 12',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 11,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 13'),
    ),
    courtNameEn: 'Annex Building Court No. 13',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 12,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 14'),
    ),
    courtNameEn: 'Annex Building Court No. 14',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৪',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 13,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 15'),
    ),
    courtNameEn: 'Annex Building Court No. 15',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৫',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 14,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 16'),
    ),
    courtNameEn: 'Annex Building Court No. 16',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৬',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 15,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 17'),
    ),
    courtNameEn: 'Annex Building Court No. 17',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৭',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 16,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 18'),
    ),
    courtNameEn: 'Annex Building Court No. 18',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৮',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 17,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 19'),
    ),
    courtNameEn: 'Annex Building Court No. 19',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ১৯',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 18,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 20'),
    ),
    courtNameEn: 'Annex Building Court No. 20',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২০',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 19,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 21'),
    ),
    courtNameEn: 'Annex Building Court No. 21',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 20,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 22'),
    ),
    courtNameEn: 'Annex Building Court No. 22',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 21,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 23'),
    ),
    courtNameEn: 'Annex Building Court No. 23',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 22,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 24'),
    ),
    courtNameEn: 'Annex Building Court No. 24',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৪',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 23,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 25'),
    ),
    courtNameEn: 'Annex Building Court No. 25',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৫',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 24,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 26'),
    ),
    courtNameEn: 'Annex Building Court No. 26',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৬',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 25,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 27'),
    ),
    courtNameEn: 'Annex Building Court No. 27',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৭',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 26,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 28'),
    ),
    courtNameEn: 'Annex Building Court No. 28',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৮',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 27,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 29'),
    ),
    courtNameEn: 'Annex Building Court No. 29',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ২৯',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 28,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 30'),
    ),
    courtNameEn: 'Annex Building Court No. 30',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩০',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 29,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 31'),
    ),
    courtNameEn: 'Annex Building Court No. 31',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 30,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 32'),
    ),
    courtNameEn: 'Annex Building Court No. 32',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 31,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 33'),
    ),
    courtNameEn: 'Annex Building Court No. 33',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 32,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Annex Building Court No. 34'),
    ),
    courtNameEn: 'Annex Building Court No. 34',
    courtNameBn: 'এনেক্স বিল্ডিং কোর্ট নং- ৩৪',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 33,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 1 (3rd Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 1 (3rd Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১ (৪র্থ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 34,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 3 (3rd Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 3 (3rd Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ৩ (৪র্থ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 35,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 4 (3rd Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 4 (3rd Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ৪ (৪র্থ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 36,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 5 (4th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 5 (4th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ৫ (৫ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 37,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 6 (4th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 6 (4th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ৬ (৫ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 38,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 7 (4th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 7 (4th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ৭ (৫ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 39,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 10 (5th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 10 (5th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১০ (৬ষ্ঠ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 40,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 11 (5th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 11 (5th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১১ (৬ষ্ঠ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 41,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 12 (5th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 12 (5th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১২ (৬ষ্ঠ তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 42,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 13 (6th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 13 (6th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১৩ (৭ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 43,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 14 (6th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 14 (6th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১৪ (৭ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 44,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 19 (7th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 19 (7th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ১৯ (৮ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 45,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 20 (7th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 20 (7th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ২০ (৮ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 46,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 21 (8th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 21 (8th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ২১ (৯ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 47,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 22 (8th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 22 (8th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ২২ (৯ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 48,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Bijoy 71 Building Court No. 23 (8th Floor)'),
    ),
    courtNameEn: 'Bijoy 71 Building Court No. 23 (8th Floor)',
    courtNameBn: 'বিজয় ৭১ বিল্ডিং কোর্ট নং- ২১ (৯ম তলা)',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 49,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 7'),
    ),
    courtNameEn: 'Main Building Court No. 7',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-৭',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 50,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 8'),
    ),
    courtNameEn: 'Main Building Court No. 8',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-৮',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 51,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 10'),
    ),
    courtNameEn: 'Main Building Court No. 10',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-১০',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 52,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 11'),
    ),
    courtNameEn: 'Main Building Court No. 11',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-১১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 53,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 12'),
    ),
    courtNameEn: 'Main Building Court No. 12',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-১২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 54,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 13'),
    ),
    courtNameEn: 'Main Building Court No. 13',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-১৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 55,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 14'),
    ),
    courtNameEn: 'Main Building Court No. 14',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-১৪',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 56,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 20'),
    ),
    courtNameEn: 'Main Building Court No. 20',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-২০',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 57,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 23'),
    ),
    courtNameEn: 'Main Building Court No. 23',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-২৩',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 58,
  ),
  SeedCourt(
    id: _supremeCourtId(
      highCourtDivisionId,
      _slug('Main Building Court No. 25'),
    ),
    courtNameEn: 'Main Building Court No. 25',
    courtNameBn: 'মেইন বিল্ডিং কোর্ট নং-২৫',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 59,
  ),
  SeedCourt(
    id: _supremeCourtId(highCourtDivisionId, _slug('Blank List 1')),
    courtNameEn: 'Blank List 1',
    courtNameBn: 'ব্লাঙ্ক লিস্ট ১',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 60,
  ),
  SeedCourt(
    id: _supremeCourtId(highCourtDivisionId, _slug('Blank List 2')),
    courtNameEn: 'Blank List 2',
    courtNameBn: 'ব্লাঙ্ক লিস্ট ২',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 61,
  ),
  SeedCourt(
    id: _supremeCourtId(highCourtDivisionId, _slug('Lawazima Court')),
    courtNameEn: 'Lawazima Court',
    courtNameBn: 'লাওয়াজিমা কোর্ট',
    higherLowerCourts: higherCourtsOption,
    courtCategoryId: highCourtDivisionId,
    orderIndex: 62,
  ),
];
// Lower court names by district by category (example data)
// ---------------------------------------------------------------------------

/// Builds a seed court entry for a lower court.
SeedCourt _lc(
  String catId,
  String districtId,
  int orderIndex,
  String nameEn,
  String nameBn,
) {
  final slug = _slug(nameEn);
  return SeedCourt(
    id: _lowerCourtId(catId, districtId, slug),
    courtNameEn: nameEn,
    courtNameBn: nameBn,
    higherLowerCourts: lowerCourtsOption,
    courtCategoryId: catId,
    orderIndex: orderIndex,
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
        (catEntry) => catEntry.value.asMap().entries.map(
          (namePair) => _lc(
            catEntry.key,
            districtEntry.key,
            namePair.key,
            namePair.value.$1,
            namePair.value.$2,
          ),
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
      (c) => c.allCaseTypes.map((ct) => MapEntry(ct.id, ct.labelEn)),
    ),
  ),
);

/// All case type stable IDs → Bengali label.
final Map<String, String> caseTypeLabelBn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.allCaseTypes.map((ct) => MapEntry(ct.id, ct.labelBn)),
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

/// All case-category stable IDs → English label.
final Map<String, String> caseCategoryLabelEn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.caseCategories.map((cc) => MapEntry(cc.id, cc.labelEn)),
    ),
  ),
);

/// All case-category stable IDs → Bengali label.
final Map<String, String> caseCategoryLabelBn = Map.unmodifiable(
  Map.fromEntries(
    seedCategories.expand(
      (c) => c.caseCategories.map((cc) => MapEntry(cc.id, cc.labelBn)),
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
