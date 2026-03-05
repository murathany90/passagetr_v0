from __future__ import annotations

import sys
from pathlib import Path

import ftfy

ROOT = Path(__file__).resolve().parents[1]
TARGET_PATTERNS = (
    "README.md",
    "docs/**/*.md",
    "lib/**/*.dart",
)
EXCLUDED_NAME_SUFFIXES = (
    ".g.dart",
)

# Suspicious fragments typically produced by mojibake.
SUSPICIOUS_FRAGMENTS = (
    "\u00C3",  # Ã
    "\u00C4",  # Ä
    "\u00C5",  # Å
    "\u00C2",  # Â
    "\u00E2\u20AC",  # â€
    "\uFFFD",  # replacement character
)


def scan_file(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return [f"{path}: not valid UTF-8"]

    issues: list[str] = []

    if ftfy.badness.badness(text) > 0:
        issues.append(f"{path}: ftfy detected suspicious mojibake patterns")

    for fragment in SUSPICIOUS_FRAGMENTS:
        if fragment in text:
            issues.append(
                f"{path}: mojibake fragment detected (U+{ord(fragment[0]):04X})"
            )

    return issues


def main() -> int:
    targets: list[Path] = []
    for pattern in TARGET_PATTERNS:
        for candidate in ROOT.glob(pattern):
            if not candidate.is_file():
                continue
            if any(
                str(candidate).lower().endswith(suffix)
                for suffix in EXCLUDED_NAME_SUFFIXES
            ):
                continue
            targets.append(candidate)

    targets = sorted(set(targets))
    issues: list[str] = []
    for target in targets:
        issues.extend(scan_file(target))

    if issues:
        print("Encoding check failed:")
        for issue in issues:
            print(f" - {issue}")
        return 1

    print("Encoding check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
