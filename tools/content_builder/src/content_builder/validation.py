from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REQUIRED_SENTENCE_FIELDS = frozenset(
    {"language", "category", "sentence", "translation"}
)
OPTIONAL_SENTENCE_FIELDS = frozenset({"usage"})
SENTENCE_FIELDS = REQUIRED_SENTENCE_FIELDS | OPTIONAL_SENTENCE_FIELDS
GRANDFATHERED_LANGUAGE_TAGS = frozenset(
    {
        "art-lojban",
        "cel-gaulish",
        "en-gb-oed",
        "i-ami",
        "i-bnn",
        "i-default",
        "i-enochian",
        "i-hak",
        "i-klingon",
        "i-lux",
        "i-mingo",
        "i-navajo",
        "i-pwn",
        "i-tao",
        "i-tay",
        "i-tsu",
        "no-bok",
        "no-nyn",
        "sgn-be-fr",
        "sgn-be-nl",
        "sgn-ch-de",
        "zh-guoyu",
        "zh-hakka",
        "zh-min",
        "zh-min-nan",
        "zh-xiang",
    }
)
ALPHA_PATTERN = re.compile(r"^[A-Za-z]+$")
ALPHANUMERIC_PATTERN = re.compile(r"^[A-Za-z0-9]+$")


@dataclass(frozen=True)
class ValidationIssue:
    source: Path
    message: str
    sentence_index: int | None = None

    def render(self) -> str:
        if self.sentence_index is None:
            return f"{self.source}: {self.message}"
        return f"{self.source}: sentences[{self.sentence_index}]: {self.message}"


class ContentValidationError(Exception):
    def __init__(self, issues: list[ValidationIssue]) -> None:
        self.issues = tuple(issues)
        super().__init__("\n".join(issue.render() for issue in self.issues))


@dataclass(frozen=True)
class ValidationResult:
    source_file_count: int
    sentence_count: int


def discover_source_files(source_directory: Path) -> tuple[Path, ...]:
    if not source_directory.exists():
        return ()
    return tuple(sorted(source_directory.glob("*.json")))


def validate_source_directory(source_directory: Path) -> ValidationResult:
    source_files = discover_source_files(source_directory)
    issues: list[ValidationIssue] = []
    sentence_count = 0

    for source_file in source_files:
        sentence_count += _validate_source_file(source_file, issues)

    if issues:
        raise ContentValidationError(issues)

    return ValidationResult(
        source_file_count=len(source_files),
        sentence_count=sentence_count,
    )


def _validate_source_file(source_file: Path, issues: list[ValidationIssue]) -> int:
    try:
        decoded = json.loads(source_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        issues.append(
            ValidationIssue(
                source=source_file,
                message=(
                    f"invalid JSON at line {error.lineno}, "
                    f"column {error.colno}: {error.msg}"
                ),
            )
        )
        return 0

    if not isinstance(decoded, dict):
        issues.append(ValidationIssue(source_file, "root value must be an object"))
        return 0

    _validate_root_fields(source_file, decoded, issues)
    sentences = decoded.get("sentences")
    if not isinstance(sentences, list) or not sentences:
        issues.append(
            ValidationIssue(source_file, 'field "sentences" must be a nonempty array')
        )
        return 0

    for index, sentence in enumerate(sentences):
        _validate_sentence(source_file, index, sentence, issues)

    return len(sentences)


def _validate_root_fields(
    source_file: Path,
    decoded: dict[str, Any],
    issues: list[ValidationIssue],
) -> None:
    unknown_fields = sorted(set(decoded) - {"sentences"})
    for field in unknown_fields:
        issues.append(ValidationIssue(source_file, f'unknown field "{field}"'))


def _validate_sentence(
    source_file: Path,
    sentence_index: int,
    sentence: Any,
    issues: list[ValidationIssue],
) -> None:
    if not isinstance(sentence, dict):
        issues.append(
            ValidationIssue(
                source_file,
                "sentence must be an object",
                sentence_index,
            )
        )
        return

    unknown_fields = sorted(set(sentence) - SENTENCE_FIELDS)
    for field in unknown_fields:
        issues.append(
            ValidationIssue(
                source_file,
                f'unknown field "{field}"',
                sentence_index,
            )
        )

    for field in sorted(REQUIRED_SENTENCE_FIELDS):
        if not _is_nonempty_string(sentence.get(field)):
            issues.append(
                ValidationIssue(
                    source_file,
                    f'required field "{field}" must be a nonempty string',
                    sentence_index,
                )
            )

    language = sentence.get("language")
    if _is_nonempty_string(language) and not is_valid_bcp47_language_tag(language):
        issues.append(
            ValidationIssue(
                source_file,
                'field "language" must be a valid BCP 47 language tag',
                sentence_index,
            )
        )

    if "usage" in sentence and not _is_nonempty_string(sentence["usage"]):
        issues.append(
            ValidationIssue(
                source_file,
                'optional field "usage" must be a nonempty string when provided',
                sentence_index,
            )
        )


def _is_nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def is_valid_bcp47_language_tag(value: str) -> bool:
    if value != value.strip() or "_" in value:
        return False
    normalized = value.lower()
    if normalized in GRANDFATHERED_LANGUAGE_TAGS:
        return True
    parts = value.split("-")
    if any(not part or not ALPHANUMERIC_PATTERN.fullmatch(part) for part in parts):
        return False
    if parts[0].lower() == "x":
        return len(parts) > 1 and all(1 <= len(part) <= 8 for part in parts[1:])
    index = _consume_language(parts)
    if index is None:
        return False
    if index < len(parts) and _is_alpha_part(parts[index], 4):
        index += 1
    if index < len(parts) and (
        _is_alpha_part(parts[index], 2) or _is_numeric_part(parts[index], 3)
    ):
        index += 1
    variants: set[str] = set()
    while index < len(parts) and _is_variant(parts[index]):
        variant = parts[index].lower()
        if variant in variants:
            return False
        variants.add(variant)
        index += 1
    extensions: set[str] = set()
    while index < len(parts) and _is_extension_singleton(parts[index]):
        singleton = parts[index].lower()
        if singleton in extensions:
            return False
        extensions.add(singleton)
        index += 1
        start = index
        while index < len(parts) and 2 <= len(parts[index]) <= 8:
            index += 1
        if index == start:
            return False
    if index < len(parts) and parts[index].lower() == "x":
        index += 1
        start = index
        while index < len(parts) and 1 <= len(parts[index]) <= 8:
            index += 1
        if index == start:
            return False
    return index == len(parts)


def _consume_language(parts: list[str]) -> int | None:
    language = parts[0]
    if not ALPHA_PATTERN.fullmatch(language):
        return None
    if 2 <= len(language) <= 3:
        index = 1
        extlang_count = 0
        while (
            index < len(parts) and extlang_count < 3 and _is_alpha_part(parts[index], 3)
        ):
            index += 1
            extlang_count += 1
        return index
    return None


def _is_alpha_part(value: str, length: int) -> bool:
    return len(value) == length and bool(ALPHA_PATTERN.fullmatch(value))


def _is_numeric_part(value: str, length: int) -> bool:
    return len(value) == length and value.isascii() and value.isdigit()


def _is_variant(value: str) -> bool:
    return (5 <= len(value) <= 8) or (
        len(value) == 4 and value[0].isascii() and value[0].isdigit()
    )


def _is_extension_singleton(value: str) -> bool:
    return len(value) == 1 and value.lower() != "x"
