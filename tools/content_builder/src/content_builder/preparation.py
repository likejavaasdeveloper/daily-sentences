from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from uuid import uuid4

from content_builder.merging import (
    MergedSentence,
    MergeResult,
    SourceLocation,
    SourceSentence,
    load_source_sentences,
    merge_source_sentences,
)
from content_builder.validation import discover_source_files, validate_source_directory

SCHEMA_VERSION = 1
STATE_SCHEMA_VERSION = 1
PACKAGE_SIZE_LIMIT = 500


@dataclass(frozen=True)
class PreparationResult:
    mode: str
    content_version: str
    package_count: int
    source_file_count: int
    source_sentence_count: int
    unique_sentence_count: int
    changed_sources: tuple[str, ...]
    removed_sources: tuple[str, ...]


def prepare_content(
    source_directory: Path,
    output_directory: Path,
    state_file: Path,
) -> PreparationResult:
    source_files = discover_source_files(source_directory)
    fingerprints = {
        source_file.relative_to(source_directory).as_posix(): _sha256_file(source_file)
        for source_file in source_files
    }
    previous_state = _load_state(state_file)
    is_incremental = _is_incremental_state(previous_state)
    mode = "incremental" if is_incremental else "full"
    previous_sources = previous_state["sources"] if is_incremental else {}
    changed_sources = tuple(
        sorted(
            relative_path
            for relative_path, fingerprint in fingerprints.items()
            if previous_sources.get(relative_path, {}).get("fingerprint") != fingerprint
        )
    )
    removed_sources = tuple(sorted(set(previous_sources) - set(fingerprints)))

    validation_result = validate_source_directory(source_directory)
    source_sentences = _source_sentences(
        source_directory,
        source_files,
        fingerprints,
        previous_sources,
        is_incremental,
    )
    merge_result = merge_source_sentences(
        source_sentences,
        validation_result.source_file_count,
        validation_result.sentence_count,
    )
    publication = _build_publication(merge_result)
    staging_directory = _write_staging_directory(output_directory, publication)
    try:
        _publish_staging_directory(staging_directory, output_directory)
    except Exception:
        shutil.rmtree(staging_directory, ignore_errors=True)
        raise

    _write_state(
        state_file,
        _state_document(source_directory, fingerprints, source_sentences, publication),
    )
    return PreparationResult(
        mode=mode,
        content_version=publication["contentVersion"],
        package_count=len(publication["packages"]),
        source_file_count=merge_result.source_file_count,
        source_sentence_count=merge_result.source_sentence_count,
        unique_sentence_count=len(merge_result.sentences),
        changed_sources=changed_sources,
        removed_sources=removed_sources,
    )


def _source_sentences(
    source_directory: Path,
    source_files: tuple[Path, ...],
    fingerprints: dict[str, str],
    previous_sources: dict[str, Any],
    is_incremental: bool,
) -> tuple[SourceSentence, ...]:
    source_sentences: list[SourceSentence] = []
    for source_file in source_files:
        relative_path = source_file.relative_to(source_directory).as_posix()
        cached_source = previous_sources.get(relative_path)
        if (
            is_incremental
            and cached_source is not None
            and cached_source.get("fingerprint") == fingerprints[relative_path]
        ):
            source_sentences.extend(
                _deserialize_source_sentences(
                    source_directory, relative_path, cached_source
                )
            )
            continue
        source_sentences.extend(load_source_sentences((source_file,)))
    return tuple(source_sentences)


def _build_publication(merge_result: MergeResult) -> dict[str, Any]:
    groups: dict[tuple[str, str], list[MergedSentence]] = {}
    for sentence in merge_result.sentences:
        groups.setdefault((sentence.language, sentence.category), []).append(sentence)

    packages: dict[str, bytes] = {}
    languages: dict[str, list[dict[str, Any]]] = {}
    for language, category in sorted(groups):
        package_references: list[dict[str, Any]] = []
        sentences = groups[(language, category)]
        for start in range(0, len(sentences), PACKAGE_SIZE_LIMIT):
            package_sentences = sentences[start : start + PACKAGE_SIZE_LIMIT]
            package = {
                "schemaVersion": SCHEMA_VERSION,
                "language": language,
                "category": category,
                "sentences": [
                    {
                        "sentence": item.sentence,
                        "translation": item.translation,
                        "usages": list(item.usages),
                    }
                    for item in package_sentences
                ],
            }
            package_bytes = _json_bytes(package)
            checksum = _sha256_bytes(package_bytes)
            path = f"sentences/{checksum}.json"
            packages[path] = package_bytes
            package_references.append(
                {
                    "path": path,
                    "sentenceCount": len(package_sentences),
                    "checksum": checksum,
                }
            )
        languages.setdefault(language, []).append(
            {
                "code": category,
                "sentenceCount": len(sentences),
                "packages": package_references,
            }
        )

    catalog_without_version = {
        "schemaVersion": SCHEMA_VERSION,
        "languages": [
            {
                "code": language,
                "sentenceCount": sum(
                    category["sentenceCount"] for category in languages[language]
                ),
                "categories": languages[language],
            }
            for language in sorted(languages)
        ],
    }
    content_version = _sha256_bytes(_json_bytes(catalog_without_version))
    catalog = {
        "schemaVersion": SCHEMA_VERSION,
        "contentVersion": content_version,
        "languages": catalog_without_version["languages"],
    }
    return {
        "catalog": catalog,
        "packages": packages,
        "contentVersion": content_version,
    }


def _write_staging_directory(
    output_directory: Path, publication: dict[str, Any]
) -> Path:
    output_directory.parent.mkdir(parents=True, exist_ok=True)
    staging_directory = Path(
        tempfile.mkdtemp(prefix=".generated-stage-", dir=output_directory.parent)
    )
    (staging_directory / "catalog.json").write_bytes(
        _json_bytes(publication["catalog"])
    )
    for path, content in publication["packages"].items():
        package_file = staging_directory / path
        package_file.parent.mkdir(parents=True, exist_ok=True)
        package_file.write_bytes(content)
    return staging_directory


def _publish_staging_directory(staging_directory: Path, output_directory: Path) -> None:
    backup_directory = output_directory.with_name(
        f".{output_directory.name}-backup-{uuid4().hex}"
    )
    replaced_existing = output_directory.exists()
    try:
        if replaced_existing:
            os.replace(output_directory, backup_directory)
        os.replace(staging_directory, output_directory)
    except Exception:
        if backup_directory.exists() and not output_directory.exists():
            os.replace(backup_directory, output_directory)
        raise
    if backup_directory.exists():
        shutil.rmtree(backup_directory)


def _state_document(
    source_directory: Path,
    fingerprints: dict[str, str],
    source_sentences: tuple[SourceSentence, ...],
    publication: dict[str, Any],
) -> dict[str, Any]:
    sources: dict[str, dict[str, Any]] = {}
    for relative_path, fingerprint in sorted(fingerprints.items()):
        sources[relative_path] = {
            "fingerprint": fingerprint,
            "sentences": _serialize_source_sentences(
                source_directory,
                relative_path,
                source_sentences,
            ),
        }
    return {
        "schemaVersion": STATE_SCHEMA_VERSION,
        "contentVersion": publication["contentVersion"],
        "sources": sources,
    }


def _serialize_source_sentences(
    source_directory: Path,
    relative_path: str,
    source_sentences: tuple[SourceSentence, ...],
) -> list[dict[str, Any]]:
    return [
        {
            "sentenceIndex": source_sentence.location.sentence_index,
            "language": source_sentence.language,
            "category": source_sentence.category,
            "sentence": source_sentence.sentence,
            "translation": source_sentence.translation,
            "usage": source_sentence.usage,
        }
        for source_sentence in source_sentences
        if source_sentence.location.source.relative_to(source_directory).as_posix()
        == relative_path
    ]


def _deserialize_source_sentences(
    source_directory: Path,
    relative_path: str,
    cached_source: dict[str, Any],
) -> tuple[SourceSentence, ...]:
    source_file = source_directory / relative_path
    return tuple(
        SourceSentence(
            location=SourceLocation(source_file, item["sentenceIndex"]),
            language=item["language"],
            category=item["category"],
            sentence=item["sentence"],
            translation=item["translation"],
            usage=item["usage"],
        )
        for item in cached_source["sentences"]
    )


def _load_state(state_file: Path) -> dict[str, Any] | None:
    try:
        decoded = json.loads(state_file.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    if not isinstance(decoded, dict):
        return None
    return decoded


def _is_incremental_state(state: dict[str, Any] | None) -> bool:
    return (
        state is not None
        and state.get("schemaVersion") == STATE_SCHEMA_VERSION
        and isinstance(state.get("sources"), dict)
    )


def _write_state(state_file: Path, state: dict[str, Any]) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    temporary_file = state_file.with_name(f".{state_file.name}-{uuid4().hex}")
    temporary_file.write_bytes(_json_bytes(state))
    os.replace(temporary_file, state_file)


def _json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def _sha256_file(source_file: Path) -> str:
    return _sha256_bytes(source_file.read_bytes())


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()
