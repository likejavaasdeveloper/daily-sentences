from __future__ import annotations

import json
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

from content_builder.validation import discover_source_files, validate_source_directory


@dataclass(frozen=True)
class SourceLocation:
    source: Path
    sentence_index: int

    def render(self) -> str:
        return f"{self.source}: sentences[{self.sentence_index}]"


@dataclass(frozen=True)
class SourceSentence:
    location: SourceLocation
    language: str
    category: str
    sentence: str
    translation: str
    usage: str | None


@dataclass(frozen=True)
class MergedSentence:
    language: str
    category: str
    sentence: str
    translation: str
    usages: tuple[str, ...]


@dataclass(frozen=True)
class ConflictIssue:
    source: SourceLocation
    original: SourceLocation
    field: str

    def render(self) -> str:
        return (
            f"{self.source.render()}: conflicting {self.field} for duplicate sentence; "
            f"first defined at {self.original.render()}"
        )


class ContentConflictError(Exception):
    def __init__(self, issues: list[ConflictIssue]) -> None:
        self.issues = tuple(issues)
        super().__init__("\n".join(issue.render() for issue in self.issues))


@dataclass(frozen=True)
class MergeResult:
    source_file_count: int
    source_sentence_count: int
    sentences: tuple[MergedSentence, ...]


@dataclass
class _MergeCandidate:
    source_sentence: SourceSentence
    usages: list[str] = field(default_factory=list)


def merge_source_directory(source_directory: Path) -> MergeResult:
    validation_result = validate_source_directory(source_directory)
    return merge_source_sentences(
        load_source_sentences(discover_source_files(source_directory)),
        validation_result.source_file_count,
        validation_result.sentence_count,
    )


def merge_source_sentences(
    source_sentences: tuple[SourceSentence, ...],
    source_file_count: int,
    source_sentence_count: int,
) -> MergeResult:
    candidates: dict[tuple[str, str], _MergeCandidate] = {}
    conflicts: list[ConflictIssue] = []

    for source_sentence in source_sentences:
        key = (
            normalize_for_matching(source_sentence.language),
            normalize_for_matching(source_sentence.sentence),
        )
        candidate = candidates.get(key)
        if candidate is None:
            candidate = _MergeCandidate(source_sentence)
            candidates[key] = candidate
            _add_usage(candidate, source_sentence.usage)
            continue

        _collect_conflicts(candidate.source_sentence, source_sentence, conflicts)
        _add_usage(candidate, source_sentence.usage)

    if conflicts:
        raise ContentConflictError(conflicts)

    return MergeResult(
        source_file_count=source_file_count,
        source_sentence_count=source_sentence_count,
        sentences=tuple(
            _to_merged_sentence(candidates[key]) for key in sorted(candidates)
        ),
    )


def normalize_for_matching(value: str) -> str:
    normalized = unicodedata.normalize("NFC", value)
    return " ".join(normalized.split()).casefold()


def load_source_sentences(source_files: tuple[Path, ...]) -> tuple[SourceSentence, ...]:
    source_sentences: list[SourceSentence] = []
    for source_file in source_files:
        decoded = json.loads(source_file.read_text(encoding="utf-8"))
        for sentence_index, value in enumerate(decoded["sentences"]):
            source_sentences.append(
                SourceSentence(
                    location=SourceLocation(source_file, sentence_index),
                    language=value["language"],
                    category=value["category"],
                    sentence=value["sentence"],
                    translation=value["translation"],
                    usage=value.get("usage"),
                )
            )
    return tuple(source_sentences)


def _collect_conflicts(
    original: SourceSentence,
    duplicate: SourceSentence,
    conflicts: list[ConflictIssue],
) -> None:
    if original.translation != duplicate.translation:
        conflicts.append(
            ConflictIssue(duplicate.location, original.location, "translation")
        )
    if original.category != duplicate.category:
        conflicts.append(
            ConflictIssue(duplicate.location, original.location, "category")
        )


def _add_usage(candidate: _MergeCandidate, usage: str | None) -> None:
    if usage is not None and usage not in candidate.usages:
        candidate.usages.append(usage)


def _to_merged_sentence(candidate: _MergeCandidate) -> MergedSentence:
    source_sentence = candidate.source_sentence
    return MergedSentence(
        language=source_sentence.language,
        category=source_sentence.category,
        sentence=source_sentence.sentence,
        translation=source_sentence.translation,
        usages=tuple(candidate.usages),
    )
