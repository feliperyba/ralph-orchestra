#!/usr/bin/env python3
"""
Thermite MVD (Minimum Viable Design) Checklist Checker
Reports status of design readiness for prototype development.
"""

import argparse
import re
from pathlib import Path
from dataclasses import dataclass
from typing import Optional


@dataclass
class CheckItem:
    name: str
    document: str
    pattern: str
    required: bool = True  # True = must have, False = should have


MUST_HAVE = [
    CheckItem("Core loop documented", "core_loop.md", r"## (Raid Phase|Loop Overview)"),
    CheckItem("Grid contract defined", "core_loop.md", r"## Grid Contract"),
    CheckItem("Loadout system scoped", "gear_registry.md", r"\*\*Slot:\*\*"),
    CheckItem("Death rules codified", "core_loop.md", r"### On Death"),
    CheckItem("Map template exists", "map_templates.md", r"## Map:"),
    CheckItem("Extraction mechanic specified", "core_loop.md", r"(extraction|extract)"),
    CheckItem(
        "AI presence decided",
        "decision_log.md",
        r"(AI|NPC|enemy|scav).*(v1|version 1|decided)",
    ),
]

SHOULD_HAVE = [
    CheckItem(
        "Bomb types (6-8) defined",
        "gear_registry.md",
        r"\*\*Slot:\*\* Bomb Type",
        required=False,
    ),
    CheckItem(
        "Economy curves modeled",
        "economy_model.md",
        r"## (Rebuild Curves|Value Hierarchy)",
        required=False,
    ),
    CheckItem(
        "Visual language guide started",
        "visual_language.md",
        r"(shape|color|visual)",
        required=False,
    ),
    CheckItem(
        "Netcode architecture specified", "tech_spec.md", r"## Netcode", required=False
    ),
]


def check_item(item: CheckItem, docs_dir: Path) -> tuple[bool, str]:
    """Check if an item is complete. Returns (complete, reason)."""
    doc_path = docs_dir / item.document

    if not doc_path.exists():
        return False, f"Document not found: {item.document}"

    content = doc_path.read_text()
    if re.search(item.pattern, content, re.IGNORECASE):
        return True, "Found"

    return False, f"Pattern not found in {item.document}"


def main():
    parser = argparse.ArgumentParser(description="Check thermite MVD readiness")
    parser.add_argument(
        "--docs", "-d", default=".", help="Directory containing design documents"
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show detailed status for each item",
    )

    args = parser.parse_args()
    docs_dir = Path(args.docs)

print("=" * 60)
print("Thermite Minimum Viable Design Checklist")
print("=" * 60)

    # Check must-haves
    print("\n## MUST HAVE (Blocks Development)")
    must_complete = 0
    for item in MUST_HAVE:
        complete, reason = check_item(item, docs_dir)
        status = "✅" if complete else "❌"
        print(f"  {status} {item.name}")
        if args.verbose and not complete:
            print(f"      → {reason}")
        if complete:
            must_complete += 1

    # Check should-haves
    print("\n## SHOULD HAVE (Blocks Polish)")
    should_complete = 0
    for item in SHOULD_HAVE:
        complete, reason = check_item(item, docs_dir)
        status = "✅" if complete else "⚠️"
        print(f"  {status} {item.name}")
        if args.verbose and not complete:
            print(f"      → {reason}")
        if complete:
            should_complete += 1

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)

    must_total = len(MUST_HAVE)
    should_total = len(SHOULD_HAVE)

    print(f"\nMust Have:   {must_complete}/{must_total}")
    print(f"Should Have: {should_complete}/{should_total}")

    if must_complete == must_total:
        print("\n🟢 PROTOTYPE READY: All must-have items complete!")
        print("   You may begin implementation.")
    else:
        remaining = must_total - must_complete
        print(f"\n🔴 NOT READY: {remaining} blocking item(s) remain.")
        print("   Schedule design sessions to resolve before coding.")

    # Return exit code for scripting
    return 0 if must_complete == must_total else 1


if __name__ == "__main__":
    exit(main())
