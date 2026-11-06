"""One-off: shorten five Bengali words in the court heading of the three card screens."""
import io

TRANSLATIONS = "lib/core/l10n/app_translations.dart"
HEADINGS = [
    "lib/features/cases/presentation/overdue_dates/overdue_dates_screen.dart",
    "lib/features/cases/presentation/daily_cause_list/daily_cause_list_screen.dart",
    "lib/features/cases/presentation/upcoming_cases/upcoming_cases_screen.dart",
]
CAUSE_LIST_TEST = "test/features/daily_cause_list_test.dart"

TOP_LEVEL = '''/// Words shortened **only** in the court heading above case cards, where a full
/// Bengali court name does not fit on one line: সহকারি→সহঃ, সিনিয়র→সিনিঃ,
/// জুডিসিয়াল→জুডিঃ, ম্যাজিস্ট্রেট→ম্যাজিঃ, অতিরিক্ত→অতিঃ.
///
/// Bengali "ya" is written both precomposed and decomposed in the seed data, so
/// both spellings are listed and a name shortens however it was written.
const Map<String, String> _courtHeadingShortenings = <String, String>{
  'সহকারি': 'সহঃ',
  'সিন\\u09dfর': 'সিনিঃ',
  'সিন\\u09af\\u09bcর': 'সিনিঃ',
  'জুডিস\\u09df\\u09beল': 'জুডিঃ',
  'জুডিস\\u09af\\u09bc\\u09beল': 'জুডিঃ',
  'ম্যাজিস্ট্রেট': 'ম্যাজিঃ',
  'অতিরিক্ত': 'অতিঃ',
};

/// The heading form of a court name: [label] with those five words shortened.
///
/// Used only by the court heading above the case cards. A card's own court
/// field, the court lists, the dropdown, print and exports keep the full name.
String shortenCourtHeading(String label) {
  var shortened = label;
  for (final entry in _courtHeadingShortenings.entries) {
    shortened = shortened.replaceAll(entry.key, entry.value);
  }
  return shortened;
}

'''

METHOD = '''  /// The court label as drawn in the heading above case cards.
  ///
  /// Bengali court names are shortened there ([shortenCourtHeading]); English
  /// ones are left as they are. Only the Overdue Dates, Daily Cause List and
  /// Upcoming Cases headings use this.
  String courtHeadingLabel(String stableId, {String fallbackEn = ''}) {
    final label = seedLabel(stableId, fallbackEn: fallbackEn);
    return _loc.localeName.startsWith('bn') ? shortenCourtHeading(label) : label;
  }

'''

WIDGET_TEST = '''  testWidgets('the court title shortens the five long Bengali words', (
    WidgetTester tester,
  ) async {
    // The heading above the cards abbreviates those five words so a full court
    // name fits one line; every other surface keeps the full name.
    final seed = allSeedCourts.firstWhere(
      (court) =>
          lowerCourtCategoryIds.contains(court.courtCategoryId) &&
          court.courtNameBn.contains('অতিরিক্ত'),
    );
    final category = seedCategoryById[seed.courtCategoryId]!;
    await db
        .into(db.courtCategories)
        .insert(
          CourtCategoriesCompanion(
            id: Value(category.id),
            nameKey: Value(category.nameKey),
            courtLevel: Value(category.courtLevel),
            orderIndex: Value(category.orderIndex),
            updatedAt: const Value(1),
          ),
        );
    await db
        .into(db.courts)
        .insert(
          CourtsCompanion(
            id: Value(seed.id),
            courtName: Value(seed.courtNameEn),
            higherLowerCourts: Value(seed.higherLowerCourts),
            courtCategoryId: Value(seed.courtCategoryId),
            orderIndex: const Value(1),
            updatedAt: const Value(1),
          ),
        );
    await caseRepository.insertCase(
      CasesCompanion(
        caseNumber: const Value('DCL-SHORT'),
        caseType: const Value('Civil Suit'),
        courtId: Value(seed.id),
        onBehalfId: const Value(roleId),
        petitioner: const Value('Md. Rahim Uddin'),
        respondent: const Value('Bangladesh Government'),
        nextDate: Value(AppDateUtils.bangladeshTodayStartOfDay()),
      ),
    );
    await pumpScreen(tester, locale: const Locale('bn'));

    final shortened = seed.courtNameBn.replaceAll('অতিরিক্ত', 'অতিঃ');
    expect(shortened, isNot(seed.courtNameBn));
    expect(find.text(shortened), findsOneWidget);
    expect(find.text(seed.courtNameBn), findsNothing);

    await unmount(tester);
  });

'''


def read(path):
    with io.open(path, encoding="utf-8", newline="") as handle:
        raw = handle.read()
    return raw, ("\r\n" in raw)


def write(path, text, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def insert_before(path, anchor, payload):
    raw, crlf = read(path)
    text = raw.replace("\r\n", "\n")
    assert text.count(anchor) == 1, (path, text.count(anchor))
    write(path, text.replace(anchor, payload + anchor, 1), crlf)
    print("inserted into", path)


raw, crlf = read(TRANSLATIONS)
text = raw.replace("\r\n", "\n")
class_anchor = "/// Central, hierarchical, screen-grouped access"
assert text.count(class_anchor) == 1
text = text.replace(class_anchor, TOP_LEVEL + class_anchor, 1)
method_anchor = "  /// Resolves a law category's stable ID to its heading in the active language."
assert text.count(method_anchor) == 1
text = text.replace(method_anchor, METHOD + method_anchor, 1)
write(TRANSLATIONS, text, crlf)
print("helper added to", TRANSLATIONS)

for path in HEADINGS:
    raw, crlf = read(path)
    text = raw.replace("\r\n", "\n")
    old = (
        "            context.l10n.seedLabel(\n"
        "              group.court.id,\n"
        "              fallbackEn: group.court.courtName,\n"
        "            ),"
    )
    new = (
        "            // The heading shortens the five long Bengali words so the\n"
        "            // court name fits on one line; the card keeps the full name.\n"
        "            context.l10n.courtHeadingLabel(\n"
        "              group.court.id,\n"
        "              fallbackEn: group.court.courtName,\n"
        "            ),"
    )
    assert text.count(old) == 1, (path, text.count(old))
    write(path, text.replace(old, new, 1), crlf)
    print("heading switched in", path)

insert_before(
    CAUSE_LIST_TEST,
    "  testWidgets('court hearing counts use Bengali digits', (",
    WIDGET_TEST,
)
