#!/usr/bin/env python3
"""
Thermite Decision Log Appender
Adds a properly formatted decision to the decision log.
"""

import argparse
import re
from datetime import datetime
from pathlib import Path


DECISION_TEMPLATE = """
## Decision: {title}
**ID:** DEC-{id:03d}
**Date:** {date}
**Session:** {session}
**Status:** {status}
**Pillar(s):** {pillars}

### Context
{context}

### Decision
{decision}

### Alternatives Considered
{alternatives}

### Dissent
{dissent}

### Validation Needed
- [ ] {validation}

---
"""


def get_next_decision_id(log_path: Path) -> int:
    """Find the next decision ID by scanning the log."""
    if not log_path.exists():
        return 1

    content = log_path.read_text()
    matches = re.findall(r"DEC-(\d+)", content)
    if not matches:
        return 1
    return max(int(m) for m in matches) + 1


def main():
    parser = argparse.ArgumentParser(
        description="Add a decision to the thermite decision log"
    )
    parser.add_argument("title", help="Decision title")
    parser.add_argument(
        "--session", "-s", type=int, required=True, help="Session number"
    )
    parser.add_argument(
        "--status",
        choices=["decided", "tentative", "revisit"],
        default="tentative",
        help="Decision status",
    )
    parser.add_argument(
        "--pillars",
        "-p",
        nargs="+",
        choices=["risk", "chaos", "tension", "mastery", "economy"],
        required=True,
        help="Design pillars this serves",
    )
    parser.add_argument("--context", "-c", required=True, help="Why this came up")
    parser.add_argument("--decision", "-d", required=True, help="What was decided")
    parser.add_argument(
        "--alternatives",
        "-a",
        default="None documented",
        help="Alternatives considered",
    )
    parser.add_argument(
        "--dissent", default="None recorded", help="Dissenting opinions"
    )
    parser.add_argument(
        "--validation", "-v", default="Playtest required", help="What needs validation"
    )
    parser.add_argument(
        "--log", "-l", default="./decision_log.md", help="Path to decision log file"
    )

    args = parser.parse_args()

    log_path = Path(args.log)

    # Create log file if it doesn't exist
    if not log_path.exists():
        log_path.write_text("# Thermite Decision Log\n\n")

    decision_id = get_next_decision_id(log_path)

    status_map = {
        "decided": "Decided",
        "tentative": "Tentative",
        "revisit": "Revisit After Playtest",
    }

    pillar_map = {
        "risk": "Meaningful Risk",
        "chaos": "Readable Chaos",
        "tension": "Compressed Tension",
        "mastery": "Earned Mastery",
        "economy": "Sustainable Economy",
    }

    pillars_str = ", ".join(pillar_map[p] for p in args.pillars)

    entry = DECISION_TEMPLATE.format(
        title=args.title,
        id=decision_id,
        date=datetime.now().strftime("%Y-%m-%d"),
        session=args.session,
        status=status_map[args.status],
        pillars=pillars_str,
        context=args.context,
        decision=args.decision,
        alternatives=args.alternatives,
        dissent=args.dissent,
        validation=args.validation,
    )

    with open(log_path, "a") as f:
        f.write(entry)

    print(f"Added: DEC-{decision_id:03d} - {args.title}")
    print(f"Status: {status_map[args.status]}")
    print(f"Pillars: {pillars_str}")


if __name__ == "__main__":
    main()
