"""One-off: record the court-heading shortening in the plan, Task 08 and the working notes."""
import io

PLAN = (
    "- **The Court Title Above the Cards Shortens Five Bengali Words (0.0.804, user request).** "
    "On the three screens that group cards by court — Overdue Dates, Daily Cause List and "
    "Upcoming Cases — the court title above a group now abbreviates five long words so a full "
    "Bengali court name fits one line instead of being clipped: সহকারি→**সহঃ**, সিনিয়র→**সিনিঃ**, "
    "জুডিসিয়াল→**জুডিঃ**, ম্যাজিস্ট্রেট→**ম্যাজিঃ** and অতিরিক্ত→**অতিঃ**, so `অতিরিক্ত জেলা জজ ১ম "
    "আদালত, ঢাকা` heads its cards as `অতিঃ জেলা জজ ১ম আদালত, ঢাকা`. The shortening is display-only "
    "and lives in one place — `shortenCourtHeading()` plus `AppTranslations.courtHeadingLabel()` — "
    "and only those three headings call it: the case card's own court field, the court lists, the "
    "court dropdown, Case Detail, print and exports all keep the full name, and an English name is "
    "never touched. Both spellings of Bengali \"ya\" are listed because the seed data contains "
    "both, so a name shortens however it was written. Pinned by `test/core/"
    "court_heading_label_test.dart` (all five words, both spellings, English and every other "
    "Bengali word unchanged) and by *the court title shortens the five long Bengali words* in "
    "`daily_cause_list_test.dart`, which renders বাংলা over a seeded court and fails if the "
    "heading keeps the full name."
)

TASK = (
    "- **0.0.804 — the court title above the cards shortens five Bengali words (user request).** "
    "On the three grouped screens (Overdue Dates, Daily Cause List, Upcoming Cases) the court "
    "title above a group now reads সহঃ / সিনিঃ / জুডিঃ / ম্যাজিঃ / অতিঃ for সহকারি / সিনিয়র / "
    "জুডিসিয়াল / ম্যাজিস্ট্রেট / অতিরিক্ত, so a full court name fits one line; nothing else on the "
    "screen, and no other surface in the app, is shortened. `shortenCourtHeading()` + "
    "`AppTranslations.courtHeadingLabel()` hold the one rule, and both spellings of Bengali \"ya\" "
    "are mapped. `court_heading_label_test.dart` and the Daily Cause List heading test pin it."
)

CW = """### 2026-11-06 — The court title above the cards shortens five Bengali words — COMPLETE (0.0.804)

- **What was asked.** The court title above the cards on **Overdue Dates**, **Daily Cause List** and **Upcoming Cases** cuts a full Bengali court name off, so it should abbreviate five words — সহকারি→সহঃ, সিনিয়র→সিনিঃ, জুডিসিয়াল→জুডিঃ, ম্যাজিস্ট্রেট→ম্যাজিঃ, অতিরিক্ত→অতিঃ — and only there.
- **What changed.** That title now shows the short words (e.g. `অতিঃ জেলা জজ ১ম আদালত, ঢাকা`); nothing else was shortened. The rule lives in one helper (`shortenCourtHeading()` and `AppTranslations.courtHeadingLabel()`) that only the three headings call, so the card's own court field, the court lists, the dropdown, Case Detail, print and exports keep the full name, and English names are never touched.
- **Bengali spelling.** The seed writes Bengali "ya" two ways, so both spellings are in the map and a name shortens however it was written.
- **Proof.** `court_heading_label_test.dart` covers all five words, both spellings, an English name and an unrelated Bengali name; *the court title shortens the five long Bengali words* in `daily_cause_list_test.dart` renders বাংলা with a seeded `অতিরিক্ত …` court and fails if the title keeps the full name. `flutter analyze` is clean.
- **Not checked.** No device screenshot was taken, so the fit itself was not looked at on a phone.
- **Next.** The user's next request; the backup export-list test remains the only known pre-existing red.

"""


def read(path):
    with io.open(path, encoding="utf-8", newline="") as handle:
        raw = handle.read()
    return raw, ("\r\n" in raw)


def write(path, text, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


raw, crlf = read("docs/implementation_plan.md")
text = raw.replace("\r\n", "\n")
lines = text.split("\n")
hits = [i for i, line in enumerate(lines) if "mockup_html_screens\\dailyCauseList\\code.html" in line]
assert len(hits) == 1, hits
lines.insert(hits[0] + 1, PLAN)
write("docs/implementation_plan.md", "\n".join(lines), crlf)
print("plan bullet after line", hits[0] + 1)

raw, crlf = read("docs/tasks/08_case_list_screens.md")
text = raw.replace("\r\n", "\n")
lines = text.split("\n")
hits = [i for i, line in enumerate(lines) if line.startswith("- **0.0.8")]
assert hits, "no 0.0.8 bullet"
lines.insert(max(hits) + 1, TASK)
write("docs/tasks/08_case_list_screens.md", "\n".join(lines), crlf)
print("task bullet after line", max(hits) + 1)

raw, crlf = read("docs/currentlyWorking.md")
text = raw.replace("\r\n", "\n")
lines = text.split("\n")
hits = [i for i, line in enumerate(lines) if line.startswith("### ")]
assert hits, "no entries"
insert_at = hits[0]
lines.insert(insert_at, CW)
write("docs/currentlyWorking.md", "\n".join(lines), crlf)
print("working notes entry before line", insert_at)
