#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def configure(worker: Path) -> None:
    source = worker.read_text(encoding="utf-8")
    marker = "  if (!RESOURCES[key]) {\n    return;\n  }\n"
    network_only = (
        "  if (key == 'generated/catalog.json' || "
        "key.startsWith('generated/sentences/')) {\n"
        "    return event.respondWith(fetch(event.request, "
        "{cache: 'reload'}));\n"
        "  }\n"
    )
    if network_only not in source:
        if marker not in source:
            raise ValueError(
                "Flutter service worker fetch guard was not found"
            )
        source = source.replace(marker, marker + network_only, 1)
    worker.write_text(source, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--worker", type=Path, required=True)
    arguments = parser.parse_args()
    try:
        configure(arguments.worker)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Configured network-only generated content: {arguments.worker}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
