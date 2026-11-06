"""One-off: rewrite the court-heading shortening map with complete word spellings."""
import io
import re

PATH = "lib/core/l10n/app_translations.dart"
BLOCK = (
    "const Map<String, String> _courtHeadingShortenings = <String, String>{\n"
    "  '\u09b8\u09b9\u0995\u09be\u09b0\u09bf': '\u09b8\u09b9\u0983',\n"
    "  '\\u09b8\\u09bf\\u09a8\\u09bf\\u09df\\u09b0': '\u09b8\u09bf\u09a8\u09bf\u0983',\n"
    "  '\\u09b8\\u09bf\\u09a8\\u09bf\\u09af\\u09bc\\u09b0': '\u09b8\u09bf\u09a8\u09bf\u0983',\n"
    "  '\\u099c\\u09c1\\u09a1\\u09bf\\u09b8\\u09bf\\u09df\\u09be\\u09b2': '\u099c\u09c1\u09a1\u09bf\u0983',\n"
    "  '\\u099c\\u09c1\\u09a1\\u09bf\\u09b8\\u09bf\\u09af\\u09bc\\u09be\\u09b2': '\u099c\u09c1\u09a1\u09bf\u0983',\n"
    "  '\u09ae\u09cd\u09af\u09be\u099c\u09bf\u09b8\u09cd\u099f\\u09cd\u09b0\u09c7\u099f': '\u09ae\u09cd\u09af\u09be\u099c\u09bf\u0983',\n"
    "  '\u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4': '\u0985\u09a4\u09bf\u0983',\n"
    "};\n"
)

raw = io.open(PATH, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
text = raw.replace("\r\n", "\n")
pattern = re.compile(r"const Map<String, String> _courtHeadingShortenings = <String, String>\{\n(?:.*\n)*?\};\n")
assert len(pattern.findall(text)) == 1
text = pattern.sub(lambda _match: BLOCK, text, count=1)
if crlf:
    text = text.replace("\n", "\r\n")
io.open(PATH, "w", encoding="utf-8", newline="").write(text)
print("map rewritten")
