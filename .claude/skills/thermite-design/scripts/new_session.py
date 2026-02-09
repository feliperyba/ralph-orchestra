#!/usr/bin/env python3
"""
Thermite Design Session Initializer
Creates a new session output file with proper template.
"""

import argparse
import os
from datetime import datetime
from pathlib import Path


SESSION_TEMPLATE = """# Session {number}: {topic}
**Date:** {date}
**Type:** {session_type}
**Participants:** {participants}

## Summary
[To be filled after session]

## Decisions Made
| ID | Title | Status | Pillars |
|----|-------|--------|---------|

## Open Questions Surfaced
- [ ] [Question] (Tags: #tag)

## Artifacts Updated
- [artifact.md] - [What changed]

## Action Items
- [ ] **[Owner]:** [Task]

## Tensions Explored
| Axis | Position A | Position B | Resolution |
|------|------------|------------|------------|

## Next Session Recommendation
[Topic] - [Why]

---
*Session notes below this line*

"""


def get_next_session_number(sessions_dir: Path) -> int:
    """Find the next session number by scanning existing files."""
    existing = list(sessions_dir.glob("session_*.md"))
    if not existing:
        return 1
    numbers = []
    for f in existing:
        try:
            num = int(f.stem.split("_")[1])
            numbers.append(num)
        except (IndexError, ValueError):
            continue
    return max(numbers, default=0) + 1


def main():
    parser = argparse.ArgumentParser(description="Initialize a thermite design session")
    parser.add_argument("topic", help="Session topic/title")
    parser.add_argument(
        "--type",
        "-t",
        choices=["boardroom", "deep-dive", "decision-review"],
        default="boardroom",
        help="Session type",
    )
    parser.add_argument(
        "--participants",
        "-p",
        nargs="+",
        default=["All"],
        help="Participating personas",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="./sessions",
        help="Output directory for session files",
    )

    args = parser.parse_args()

    sessions_dir = Path(args.output)
    sessions_dir.mkdir(parents=True, exist_ok=True)

    session_num = get_next_session_number(sessions_dir)

    type_map = {
        "boardroom": "Boardroom",
        "deep-dive": "Deep Dive",
        "decision-review": "Decision Review",
    }

    content = SESSION_TEMPLATE.format(
        number=session_num,
        topic=args.topic,
        date=datetime.now().strftime("%Y-%m-%d"),
        session_type=type_map[args.type],
        participants=", ".join(args.participants),
    )

    filename = f"session_{session_num:03d}_{args.topic.lower().replace(' ', '_')}.md"
    filepath = sessions_dir / filename

    filepath.write_text(content)
    print(f"Created: {filepath}")
    print(f"Session {session_num}: {args.topic}")


if __name__ == "__main__":
    main()
