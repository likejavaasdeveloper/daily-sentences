#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


def _json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: JSON root must be an object")
    return value


def verify_artifact(artifact: Path, base_href: str) -> list[str]:
    errors: list[str] = []
    if not artifact.is_dir():
        return [f"{artifact}: deployment artifact directory does not exist"]

    required = (
        "index.html",
        "manifest.json",
        "flutter_bootstrap.js",
        "flutter_service_worker.js",
        "icons/Icon-192.png",
        "icons/Icon-512.png",
        "icons/Icon-maskable-192.png",
        "icons/Icon-maskable-512.png",
        "favicon.png",
        "generated/catalog.json",
    )
    for relative in required:
        if not (artifact / relative).is_file():
            errors.append(f"{relative}: required deployment file is missing")

    forbidden_names = (
        "assets/content",
        "tools",
        ".content-builder-state",
        ".git",
        ".dart_tool",
        ".venv",
        "test",
        "tests",
        "fixtures",
    )
    for relative in forbidden_names:
        if (artifact / relative).exists():
            errors.append(f"{relative}: development or authoring path is present")
    for path in artifact.rglob("*"):
        if path.is_file() and path.suffix.lower() == ".json":
            relative = path.relative_to(artifact).as_posix()
            allowed_json_prefixes = ("assets/", "generated/")
            if (
                relative not in {"manifest.json", "version.json"}
                and not relative.startswith(allowed_json_prefixes)
            ):
                errors.append(
                    f"{relative}: unexpected JSON file in deployment artifact"
                )
        if path.is_file() and path.name in {"state.json", "pubspec.yaml", "pubspec.lock"}:
            errors.append(f"{path.relative_to(artifact).as_posix()}: forbidden file")

    index_path = artifact / "index.html"
    if index_path.is_file():
        index = index_path.read_text(encoding="utf-8")
        if f'<base href="{base_href}">' not in index:
            errors.append(
                f"index.html: base href does not match {base_href}"
            )
        if '<link rel="manifest" href="manifest.json">' not in index:
            errors.append("index.html: manifest link is missing")
        if "<title>Daily Sentences</title>" not in index:
            errors.append("index.html: application title is not Daily Sentences")

    worker_path = artifact / "flutter_service_worker.js"
    if worker_path.is_file():
        worker = worker_path.read_text(encoding="utf-8")
        if "key == 'generated/catalog.json'" not in worker:
            errors.append(
                "flutter_service_worker.js: catalog network-only routing is missing"
            )
        if "key.startsWith('generated/sentences/')" not in worker:
            errors.append(
                "flutter_service_worker.js: package network-only routing is missing"
            )

    manifest_path = artifact / "manifest.json"
    if manifest_path.is_file():
        try:
            manifest = _json(manifest_path)
            if manifest.get("name") != "Daily Sentences":
                errors.append("manifest.json: name must be Daily Sentences")
            if manifest.get("short_name") != "Daily Sentences":
                errors.append("manifest.json: short_name must be Daily Sentences")
            if manifest.get("start_url") != ".":
                errors.append("manifest.json: start_url must be relative")
            if manifest.get("scope") != ".":
                errors.append("manifest.json: scope must be relative")
            icons = manifest.get("icons")
            if not isinstance(icons, list) or len(icons) != 4:
                errors.append("manifest.json: exactly four application icons are required")
        except (json.JSONDecodeError, ValueError) as error:
            errors.append(f"manifest.json: invalid JSON: {error}")

    catalog_path = artifact / "generated" / "catalog.json"
    if catalog_path.is_file():
        try:
            catalog = _json(catalog_path)
            if catalog.get("schemaVersion") != 1:
                errors.append("generated/catalog.json: schemaVersion must be 1")
            content_version = catalog.get("contentVersion")
            if not isinstance(content_version, str) or len(content_version) != 64:
                errors.append("generated/catalog.json: contentVersion must be a SHA-256 value")
            languages = catalog.get("languages")
            if not isinstance(languages, list):
                errors.append("generated/catalog.json: languages must be an array")
            else:
                for language_index, language in enumerate(languages):
                    if not isinstance(language, dict):
                        errors.append(
                            f"generated/catalog.json: languages[{language_index}] must be an object"
                        )
                        continue
                    categories = language.get("categories")
                    if not isinstance(categories, list):
                        errors.append(
                            f"generated/catalog.json: languages[{language_index}].categories "
                            "must be an array"
                        )
                        continue
                    for category_index, category in enumerate(categories):
                        if not isinstance(category, dict):
                            continue
                        packages = category.get("packages")
                        if not isinstance(packages, list):
                            continue
                        for package in packages:
                            if not isinstance(package, dict):
                                continue
                            path_value = package.get("path")
                            checksum = package.get("checksum")
                            sentence_count = package.get("sentenceCount")
                            if not isinstance(path_value, str) or not isinstance(checksum, str):
                                continue
                            package_path = artifact / "generated" / path_value
                            if not package_path.is_file():
                                errors.append(
                                    f"{path_value}: catalog package is missing"
                                )
                                continue
                            actual = hashlib.sha256(package_path.read_bytes()).hexdigest()
                            if actual != checksum:
                                errors.append(
                                    f"{path_value}: package checksum mismatch"
                                )
                            try:
                                package_json = _json(package_path)
                            except (json.JSONDecodeError, ValueError) as error:
                                errors.append(f"{path_value}: invalid JSON: {error}")
                                continue
                            sentences = package_json.get("sentences")
                            if (
                                not isinstance(sentences, list)
                                or len(sentences) != sentence_count
                                or len(sentences) > 500
                            ):
                                errors.append(
                                    f"{path_value}: sentence count or package limit is invalid"
                                )
        except (json.JSONDecodeError, ValueError) as error:
            errors.append(f"generated/catalog.json: invalid JSON: {error}")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--base-href", default="/")
    arguments = parser.parse_args()
    errors = verify_artifact(arguments.artifact, arguments.base_href)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(f"Verified deployment artifact: {arguments.artifact}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
