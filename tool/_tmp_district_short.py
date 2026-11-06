"""One-off: also shorten নারায়ণগঞ্জ to নাঃগঞ্জ in the three court titles."""
import io
import re

TRANSLATIONS = "lib/core/l10n/app_translations.dart"
TEST_PATH = "test/core/court_heading_label_test.dart"

BLOCK = (
    "const Map<String, String> _courtHeadingShortenings = <String, String>{\n"
    "  '\u09b8\u09b9\u0995\u09be\u09b0\u09bf': '\u09b8\u09b9\u0983',\n"
    "  '\\u09b8\\u09bf\\u09a8\\u09bf\\u09df\\u09b0': '\u09b8\u09bf\u09a8\u09bf\u0983',\n"
    "  '\\u09b8\\u09bf\\u09a8\\u09bf\\u09af\\u09bc\\u09b0': '\u09b8\u09bf\u09a8\u09bf\u0983',\n"
    "  '\\u099c\\u09c1\\u09a1\\u09bf\\u09b8\\u09bf\\u09df\\u09be\\u09b2': '\u099c\u09c1\u09a1\u09bf\u0983',\n"
    "  '\\u099c\\u09c1\\u09a1\\u09bf\\u09b8\\u09bf\\u09af\\u09bc\\u09be\\u09b2': '\u099c\u09c1\u09a1\u09bf\u0983',\n"
    "  '\u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\\u09cd\u09b0\u09c7\u099f': '\u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983',\n"
    "  '\u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4': '\u0985\u09a4\u09bf\u0983',\n"
    "  '\\u09a8\\u09be\\u09b0\\u09be\\u09df\\u09a3\\u0997\\u099e\\u09cd\\u099c': '\u09a8\u09be\u0983\u0997\u099e\u09cd\u09c1\u099c',\n"
    "  '\\u09a8\\u09be\\u09b0\\u09be\\u09af\\u09bc\\u09a3\\u0997\\u099e\\u09cd\\u099c': '\u09a8\u09be\u0983\u0997\u099e\u09cd\u099c',\n"
    "};\n"
)

FIRST_TEST_ADD = (
    "      expect(\n"
    "        shortenCourtHeading('\u09a8\u09be\u09b0\u09be\u09df\u09a3\u0997\u099e\u09cd\u099c \u099c\u09c7\u09b2\u09be \u099c\u099c \u0986\u09a6\u09be\u09b2\u09a4'),\n"
    "        '\u09a8\u09be\u0983\u0997\u099e\u09cd\u099c \u099c\u09c7\u09b2\u09be \u099c\u099c \u0986\u09a6\u09be\u09b2\u09a4',\n"
    "      );\n"
)

SECOND_TEST_ADD = (
    "      expect(\n"
    "        shortenCourtHeading('\u09a8\u09be\u09b0\u09be\\u09af\\u09bc\u09a3\u0997\u099e\u09cd\u099c \u099c\u09c7\u09b2\u09be \u099c\u099c \u0986\u09a6\u09be\u09b2\u09a4'),\n"
    "        '\u09a8\u09be\u0983\u0997\u099e\u09cd\u099c \u099c\u09c7\u09b2\u09be \u099c\u099c \u0986\u09a6\u09be\u09b2\u09a4',\n"
    "      );\n"
)


def read(path):
    with io.open(path, encoding="utf-8", newline="") as handle:
        raw = handle.read()
    return raw, ("\r\n" in raw)


def write(path, text, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


raw, crlf = read(TRANSLATIONS)
text = raw.replace("\r\n", "\n")
pattern = re.compile(r"const Map<String, String> _courtHeadingShortenings = <String, String>\{\n(?:.*\n)*?\};\n")
assert len(pattern.findall(text)) == 1
text = pattern.sub(lambda _match: BLOCK, text, count=1)
write(TRANSLATIONS, text, crlf)
print("map extended")

raw, crlf = read(TEST_PATH)
text = raw.replace("\r\n", "\n")
first_anchor = "        '\u0985\u09a4\u09bf\u0983 \u099c\u09c7\u09b2\u09be \u099c\u099c \u09e7\u09ae \u0986\u09a6\u09be\u09b2\u09a4, \u09a2\u09be\u0995\u09be',\n      );\n"
assert text.count(first_anchor) == 1, text.count(first_anchor)
text = text.replace(first_anchor, first_anchor + FIRST_TEST_ADD, 1)
second_anchor = "        '\u099c\u09c1\u09a1\u09bf\u0983 \u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983 \u0986\u09a6\u09be\u09b2\u09a4',\n      );\n"
assert text.count(second_anchor) == 1, text.count(second_anchor)
text = text.replace(second_anchor, second_anchor + SECOND_TEST_ADD, 1)
write(TEST_PATH, text, crlf)
print("tests extended")

REPLACEMENTS = [
    (
        "docs/implementation_plan.md",
        [
            ("Shortens Five Bengali Words (0.0.804", "Shortens Six Bengali Words (0.0.804 and 0.0.805"),
            (
                "abbreviates five long words so a full",
                "abbreviates six long words so a full",
            ),
            (
                "\u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\u09cd\u09b0\u09c7\u099f\u2192**\u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983** and \u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4\u2192**\u0985\u09a4\u09bf\u0983**",
                "\u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\u09cd\u09b0\u09c7\u099f\u2192**\u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983**, \u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4\u2192**\u0985\u09a4\u09bf\u0983** and \u09a8\u09be\u09b0\u09be\u09df\u09a3\u0997\u099e\u09cd\u099c\u2192**\u09a8\u09be\u0983\u0997\u099e\u09cd\u099c**",
            ),
            (
                "(all five words, both spellings",
                "(all six words, both spellings",
            ),
        ],
    ),
    (
        "docs/tasks/08_case_list_screens.md",
        [
            (
                "shortens five Bengali words (user request)",
                "shortens six Bengali words (user request)",
            ),
            (
                "\u09b8\u09b9\u0983 / \u09b8\u09bf\u09a8\u09bf\u0983 / \u099c\u09c1\u09a1\u09bf\u0983 / \u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983 / \u0985\u09a4\u09bf\u0983 for \u09b8\u09b9\u0995\u09be\u09b0\u09bf / \u09b8\u09bf\u09a8\u09bf\u09df\u09b0 / \u099c\u09c1\u09a1\u09bf\u09b8\u09bf\u09df\u09be\u09b2 / \u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\u09cd\u09b0\u09c7\u099f / \u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4",
                "\u09b8\u09b9\u0983 / \u09b8\u09bf\u09a8\u09bf\u0983 / \u099c\u09c1\u09a1\u09bf\u0983 / \u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983 / \u0985\u09a4\u09bf\u0983 / \u09a8\u09be\u0983\u0997\u099e\u09cd\u099c for \u09b8\u09b9\u0995\u09be\u09b0\u09bf / \u09b8\u09bf\u09a8\u09bf\u09df\u09b0 / \u099c\u09c1\u09a1\u09bf\u09b8\u09bf\u09df\u09be\u09b2 / \u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\u09cd\u09b0\u09c7\u099f / \u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4 / \u09a8\u09be\u09b0\u09be\u09df\u09a3\u0997\u099e\u09cd\u099c",
            ),
        ],
    ),
    (
        "docs/currentlyWorking.md",
        [
            (
                "shortens five Bengali words \u2014 COMPLETE (0.0.804)",
                "shortens six Bengali words \u2014 COMPLETE (0.0.805)",
            ),
            (
                "\u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4\u2192\u0985\u09a4\u09bf\u0983 \u2014 and only there",
                "\u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4\u2192\u0985\u09a4\u09bf\u0983, \u09a8\u09be\u09b0\u09be\u09df\u09a3\u0997\u099e\u09cd\u099c\u2192\u09a8\u09be\u0983\u0997\u099e\u09cd\u099c \u2014 and only there",
            ),
            (
                "covers all five words",
                "covers all six words",
            ),
        ],
    ),
]

for path, pairs in REPLACEMENTS:
    raw, crlf = read(path)
    text = raw.replace("\r\n", "\n")
    for old, new in pairs:
        assert text.count(old) >= 1, (path, old[:40])
        text = text.replace(old, new)
    write(path, text, crlf)
    print("records updated in", path)
