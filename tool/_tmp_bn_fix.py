"""One-off: use the list's own Bengali spelling of "ya" in the renamed judge courts.

The renamed labels were written with the precomposed letter (U+09DF); the rest of the court list
writes the same letter decomposed (U+09AF U+09BC). Both read identically, so this only keeps the
file's spelling uniform, and it touches nothing but the 86 labels this change created.
"""
import io
import re

PATH = "lib/core/constants/pre_seeded_data.dart"
BN_LINE = re.compile(r"(courtNameBn:\s*')((?:\\.|[^'\\])*)(')")
DAR = "\u09a6\u09df\u09b0\u09be"  # "দায়রা"
ATIRIKTO_DAR = "\u0985\u09a4\u09bf\u09b0\u09bf\u0995\u09cd\u09a4 " + DAR
DECOMPOSED = "\u09af\u09bc"
changed = 0


def fix(match):
    global changed
    value = match.group(2)
    if value.startswith(DAR) or value.startswith(ATIRIKTO_DAR):
        if "\u09df" in value:
            changed += 1
            return match.group(1) + value.replace("\u09df", DECOMPOSED) + match.group(3)
    return match.group(0)


raw = io.open(PATH, encoding="utf-8", newline="").read()
crlf = "\r\n" in raw
text = raw.replace("\r\n", "\n")
blocks = re.split(r"\n  SeedCourt\(\n", text)
patched = [blocks[0]] + [BN_LINE.sub(fix, block) for block in blocks[1:]]
new_text = "\n  SeedCourt(\n".join(patched)
print("normalised", changed)
assert changed == 86, changed
if crlf:
    new_text = new_text.replace("\n", "\r\n")
io.open(PATH, "w", encoding="utf-8", newline="").write(new_text)
