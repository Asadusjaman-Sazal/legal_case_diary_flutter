#!/usr/bin/env python
"""Record one version entry - the only supported way to write the version log.

Why this script exists: the log was hand-edited, and hand-editing went wrong the
same way twice - the new entry was *inserted above* the previous one under
`## Current Version` instead of replacing it, and a long entry was written after
a blank line at the end of `## Version History Log` instead of one short line
appended to the last entry. Both are structural mistakes a human eye misses and
a program cannot. So the rules live here, in one place:

    python tool/record_version.py --summary "One short, precise sentence."

It reads the version under `## Current Version`, bumps it (patch by default),
replaces that section's single entry with the new line, appends the *identical*
line directly under the last line of `## Version History Log` (never after a
blank line), and writes the same version into `pubspec.yaml` and
`lib/core/constants/app_version.dart`.

    python tool/record_version.py --check

reports the same rules without writing anything, and
`test/core/version_history_test.dart` fails the suite when one of these files
was edited by hand instead.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HISTORY_PATH = ROOT / "docs" / "version_history.md"
PUBSPEC_PATH = ROOT / "pubspec.yaml"
APP_VERSION_PATH = ROOT / "lib" / "core" / "constants" / "app_version.dart"

CURRENT_HEADINGS = ("## Current Version:", "## Current Version")
HISTORY_HEADINGS = (
    "## Version History Log:",
    "## Version History Log",
    "## Version History:",
)

# "Short but precise": the newest entry is one sentence, not a phase report -
# the long-form account belongs in `docs/currentlyWorking.md`.
MAX_SUMMARY = 300

ENTRY_RE = re.compile(r"^Version: (\d+)\.(\d+)\.(\d+) - (\S.*)$")
PUBSPEC_RE = re.compile(r"^version:\s*(\S+)\s*$")
APP_VERSION_RE = re.compile(r"appVersion\s*=\s*'([^']+)'")


def read_lines(path: Path) -> list[str]:
    """Reads a file keeping its original line endings."""
    with open(path, "r", encoding="utf-8", newline="") as handle:
        return handle.readlines()


def write_lines(path: Path, lines: list[str]) -> None:
    """Writes a file back with the line endings it was read with."""
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.writelines(lines)


def _heading_index(lines: list[str], names: tuple[str, ...]) -> int:
    for index, line in enumerate(lines):
        if line.strip() in names:
            return index
    raise SystemExit(
        f"error: {HISTORY_PATH.name} has no '{names[0]}' heading; "
        "the file's layout is fixed by AGENTS.md"
    )


def _version_of(entry: str) -> tuple[int, int, int]:
    match = ENTRY_RE.match(entry)
    if match is None:
        raise SystemExit(f"error: not a version entry: {entry!r}")
    return (int(match.group(1)), int(match.group(2)), int(match.group(3)))


class VersionLog:
    """The version log as one value: the four regions the protocol names."""

    def __init__(self, lines: list[str]) -> None:
        self.lines = lines
        self.eol = "\r\n" if any(line.endswith("\r\n") for line in lines) else "\n"
        self.current_heading = _heading_index(lines, CURRENT_HEADINGS)
        self.history_heading = _heading_index(lines, HISTORY_HEADINGS)
        if self.history_heading <= self.current_heading:
            raise SystemExit(
                f"error: in {HISTORY_PATH.name} the history section must come "
                "after the current-version section"
            )

        # The Current Version section: which lines inside it are entries.
        self.current_entries: list[tuple[int, str]] = [
            (index, lines[index].rstrip("\r\n"))
            for index in range(self.current_heading + 1, self.history_heading)
            if ENTRY_RE.match(lines[index].rstrip("\r\n"))
        ]
        # The history section: every entry, in file order.
        self.history_entries: list[tuple[int, str]] = [
            (index, lines[index].rstrip("\r\n"))
            for index in range(self.history_heading + 1, len(lines))
            if ENTRY_RE.match(lines[index].rstrip("\r\n"))
        ]

    @property
    def current_entry(self) -> str | None:
        return self.current_entries[0][1] if self.current_entries else None

    @property
    def version(self) -> str:
        entry = self.current_entry or (
            self.history_entries[-1][1] if self.history_entries else None
        )
        if entry is None:
            raise SystemExit(f"error: {HISTORY_PATH.name} holds no version entry")
        return ".".join(str(part) for part in _version_of(entry))

    def problems(self) -> list[str]:
        """Every rule the file breaks, in the order the protocol states them."""
        found: list[str] = []

        if not self.current_entries:
            found.append("`## Current Version` holds no version entry")
        elif len(self.current_entries) > 1:
            found.append(
                "`## Current Version` holds "
                f"{len(self.current_entries)} entries; the new entry must "
                "*replace* the previous one, never be inserted above it"
            )

        entry = self.current_entry
        if entry is not None:
            summary = entry.split(" - ", 1)[1] if " - " in entry else ""
            if len(entry) > MAX_SUMMARY:
                found.append(
                    f"the current entry is {len(entry)} characters; it must be "
                    f"one short, precise line of at most {MAX_SUMMARY} "
                    "(the long account belongs in docs/currentlyWorking.md)"
                )
            if "\n" in entry or not summary:
                found.append("the current entry must be a single non-empty line")

        if not self.history_entries:
            found.append("`## Version History Log` holds no version entry")
        elif entry is not None and self.history_entries[-1][1] != entry:
            found.append(
                "the current entry is not the last line of "
                "`## Version History Log`; the same line must be appended there"
            )
        elif entry is not None and len(self.history_entries) > 1:
            previous = _version_of(self.history_entries[-2][1])
            if _version_of(entry) <= previous:
                found.append(
                    "the current entry's version is not greater than the entry "
                    "above it"
                )

        # Anything that is not an entry inside the log is the reported mistake:
        # the new entry must sit directly under the last one, so a blank line (or
        # a fragment left behind by an edit) between entries is a fault.
        for (before, _), (after, _) in zip(
            self.history_entries, self.history_entries[1:]
        ):
            if after != before + 1:
                stray = self.lines[before + 1].rstrip("\r\n")
                kind = "A blank" if not stray.strip() else "A stray"
                found.append(
                    f"{kind} line ({stray[:40]!r}) sits between the entries on "
                    f"lines {before + 1} and {after + 1}; entries must be "
                    "consecutive lines, with the newest appended directly under "
                    "the last one"
                )
                break

        found.extend(self._version_file_problems())
        return found

    def _version_file_problems(self) -> list[str]:
        wanted = self.version
        found: list[str] = []

        declared = None
        for line in read_lines(PUBSPEC_PATH):
            match = PUBSPEC_RE.match(line.rstrip("\r\n"))
            if match:
                declared = match.group(1).split("+")[0]
                break
        if declared != wanted:
            found.append(f"pubspec.yaml says {declared}, not {wanted}")

        bundled = None
        for line in read_lines(APP_VERSION_PATH):
            match = APP_VERSION_RE.search(line)
            if match:
                bundled = match.group(1)
                break
        if bundled != wanted:
            found.append(
                f"lib/core/constants/app_version.dart says {bundled}, not {wanted}"
            )

        return found

    def next_version(self, bump: str) -> str:
        major, minor, patch = _version_of(
            f"Version: {self.version} - placeholder"
        )
        if bump == "major":
            major, minor, patch = major + 1, 0, 0
        elif bump == "minor":
            minor, patch = minor + 1, 0
        else:
            patch += 1
        return f"{major}.{minor}.{patch}"

    def rewritten(self, summary: str, bump: str) -> tuple[list[str], str]:
        """Returns the new file lines and the entry that was recorded."""
        new_version = self.next_version(bump)
        entry = f"Version: {new_version} - {summary}"

        # The old current entry, which the history must end with. When it is
        # missing there (a hand-edit that appended nothing), it is appended
        # here so the two sections agree again.
        entries = [text for _, text in self.history_entries]
        old = self.current_entry
        if old is not None and (not entries or entries[-1] != old):
            entries.append(old)
        if entries and _version_of(entries[-1]) >= _version_of(entry):
            entries[-1] = entry
        else:
            entries.append(entry)

        # The head of the file and whatever separates the current section from
        # the history heading (the rule and blank lines) are kept verbatim; only
        # version lines are rebuilt, so a stray entry above the new one goes.
        head = self.lines[: self.current_heading + 1]
        separators = [
            line
            for line in self.lines[self.current_heading + 1 : self.history_heading]
            if not ENTRY_RE.match(line.rstrip("\r\n"))
        ]
        lines = (
            head
            + [entry + self.eol]
            + separators
            + [self.lines[self.history_heading]]
            + [text + self.eol for text in entries]
        )
        return lines, entry


def _write_version_files(version: str) -> None:
    """Puts [version] in `pubspec.yaml` and the bundled constant."""
    lines = read_lines(PUBSPEC_PATH)
    for index, line in enumerate(lines):
        if PUBSPEC_RE.match(line.rstrip("\r\n")):
            ending = "\r\n" if line.endswith("\r\n") else "\n"
            lines[index] = f"version: {version}{ending}"
            break
    write_lines(PUBSPEC_PATH, lines)

    lines = read_lines(APP_VERSION_PATH)
    for index, line in enumerate(lines):
        if APP_VERSION_RE.search(line):
            lines[index] = APP_VERSION_RE.sub(f"appVersion = '{version}'", line, count=1)
            break
    write_lines(APP_VERSION_PATH, lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--summary", help="one short, precise line")
    parser.add_argument(
        "--bump", choices=("patch", "minor", "major"), default="patch"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="report the rules the log breaks and write nothing",
    )
    parser.add_argument("--dry-run", action="store_true", help="print, write nothing")
    args = parser.parse_args(argv)

    log = VersionLog(read_lines(HISTORY_PATH))

    if args.check:
        problems = log.problems()
        for problem in problems:
            print(f"FAIL: {problem}")
        if problems:
            return 1
        print(f"OK: {HISTORY_PATH.name} follows the version-log rules")
        return 0

    if not args.summary:
        parser.error("--summary is required (or use --check)")
    summary = " ".join(args.summary.split())
    if not summary:
        parser.error("--summary must not be empty")
    if len(summary) > MAX_SUMMARY:
        parser.error(
            f"--summary is {len(summary)} characters; keep it to one short, "
            f"precise sentence of at most {MAX_SUMMARY}"
        )

    lines, entry = log.rewritten(summary, args.bump)
    version = ".".join(str(part) for part in _version_of(entry))
    print(entry)
    if args.dry_run:
        print("(dry run - nothing written)")
        return 0

    write_lines(HISTORY_PATH, lines)
    _write_version_files(version)
    print(f"recorded {version} in {HISTORY_PATH.name}, pubspec.yaml and "
          f"{APP_VERSION_PATH.name}")

    problems = VersionLog(read_lines(HISTORY_PATH)).problems()
    for problem in problems:
        print(f"WARNING (still to fix): {problem}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
