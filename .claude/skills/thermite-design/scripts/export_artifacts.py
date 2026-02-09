#!/usr/bin/env python3
"""
Thermite Artifact Exporter
Bundles all design artifacts into a single review document or archive.
"""

import argparse
import os
from datetime import datetime
from pathlib import Path
import zipfile


ARTIFACT_FILES = [
    "system_prompt.md",
    "decision_log.md",
    "open_questions.md",
    "core_loop.md",
    "gear_registry.md",
    "map_templates.md",
    "economy_model.md",
    "visual_language.md",
    "tech_spec.md",
    "mvd_checklist.md",
]


def export_markdown(docs_dir: Path, output: Path) -> None:
    """Export all artifacts as a single combined markdown file."""
    content = []
    content.append("# Thermite Design Artifacts Export")
    content.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    content.append(f"**Source:** {docs_dir.absolute()}")
    content.append("\n---\n")

    # Table of contents
    content.append("## Table of Contents\n")
    for filename in ARTIFACT_FILES:
        anchor = filename.replace(".md", "").replace("_", "-")
        content.append(f"- [{filename}](#{anchor})")
    content.append("\n---\n")

    # Each artifact
    for filename in ARTIFACT_FILES:
        filepath = docs_dir / filename
        content.append(f"\n# {filename}\n")

        if filepath.exists():
            file_content = filepath.read_text()
            content.append(file_content)
        else:
            content.append(f"*File not found: {filename}*\n")

        content.append("\n---\n")

    output.write_text("\n".join(content))
    print(f"Exported markdown: {output}")


def export_archive(docs_dir: Path, output: Path) -> None:
    """Export all artifacts as a zip archive."""
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zf:
        # Add main artifacts
        for filename in ARTIFACT_FILES:
            filepath = docs_dir / filename
            if filepath.exists():
                zf.write(filepath, filename)

        # Add session files if they exist
        sessions_dir = docs_dir / "sessions"
        if sessions_dir.exists():
            for session_file in sessions_dir.glob("session_*.md"):
                zf.write(session_file, f"sessions/{session_file.name}")

        # Add a manifest
        manifest = [
            "Thermite Design Artifact Archive",
            f"Generated: {datetime.now().isoformat()}",
            "",
            "Contents:",
        ]
        for name in zf.namelist():
            manifest.append(f"  - {name}")

        zf.writestr("MANIFEST.txt", "\n".join(manifest))

    print(f"Exported archive: {output}")


def main():
    parser = argparse.ArgumentParser(description="Export thermite design artifacts")
    parser.add_argument(
        "--docs", "-d", default=".", help="Directory containing design documents"
    )
    parser.add_argument(
        "--output", "-o", help="Output file path (auto-generated if not specified)"
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["markdown", "zip"],
        default="markdown",
        help="Export format",
    )

    args = parser.parse_args()
    docs_dir = Path(args.docs)

    # Generate output filename if not specified
    if args.output:
        output = Path(args.output)
    else:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M")
        ext = "md" if args.format == "markdown" else "zip"
        output = docs_dir / f"thermite_export_{timestamp}.{ext}"

    if args.format == "markdown":
        export_markdown(docs_dir, output)
    else:
        export_archive(docs_dir, output)

    print(f"\nExport complete!")
    print(f"Artifacts from: {docs_dir.absolute()}")
    print(f"Output: {output.absolute()}")


if __name__ == "__main__":
    main()
