import json
from pathlib import Path

import pytest

from content_builder.merging import ContentConflictError, merge_source_directory


def write_source(directory: Path, name: str, sentences: list[dict[str, str]]) -> Path:
    source_file = directory / name
    source_file.write_text(json.dumps({"sentences": sentences}), encoding="utf-8")
    return source_file


def sentence(
    *,
    language: str = "fr",
    category: str = "Greetings",
    original: str = "Bonjour",
    translation: str = "سلام",
    usage: str | None = None,
) -> dict[str, str]:
    result = {
        "language": language,
        "category": category,
        "sentence": original,
        "translation": translation,
    }
    if usage is not None:
        result["usage"] = usage
    return result


def test_merges_normalized_duplicates_and_preserves_display_text(
    tmp_path: Path,
) -> None:
    write_source(
        tmp_path,
        "first.json",
        [
            sentence(
                original="Café  du matin",
                usage="Formal morning greeting",
            )
        ],
    )
    write_source(
        tmp_path,
        "second.json",
        [
            sentence(
                language="FR",
                original=" cafe\u0301 du matin ",
                usage="Informal morning greeting",
            ),
            sentence(
                original="CAFÉ DU MATIN",
                usage="Formal morning greeting",
            ),
        ],
    )

    result = merge_source_directory(tmp_path)

    assert result.source_sentence_count == 3
    assert len(result.sentences) == 1
    assert result.sentences[0].language == "fr"
    assert result.sentences[0].sentence == "Café  du matin"
    assert result.sentences[0].usages == (
        "Formal morning greeting",
        "Informal morning greeting",
    )


def test_keeps_meaningful_diacritic_differences_distinct(tmp_path: Path) -> None:
    write_source(
        tmp_path,
        "sentences.json",
        [sentence(original="cafe"), sentence(original="café")],
    )

    result = merge_source_directory(tmp_path)

    assert len(result.sentences) == 2


def test_reports_translation_conflict_with_both_locations(tmp_path: Path) -> None:
    first_file = write_source(tmp_path, "first.json", [sentence()])
    second_file = write_source(
        tmp_path,
        "second.json",
        [sentence(original=" bonjour ", translation="درود")],
    )

    with pytest.raises(ContentConflictError) as raised:
        merge_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{second_file}: sentences[0]" in message
    assert f"first defined at {first_file}: sentences[0]" in message
    assert "conflicting translation" in message


def test_reports_category_conflict_with_both_locations(tmp_path: Path) -> None:
    first_file = write_source(tmp_path, "first.json", [sentence()])
    second_file = write_source(
        tmp_path,
        "second.json",
        [sentence(original=" bonjour ", category="Travel")],
    )

    with pytest.raises(ContentConflictError) as raised:
        merge_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{second_file}: sentences[0]" in message
    assert f"first defined at {first_file}: sentences[0]" in message
    assert "conflicting category" in message


def test_aggregates_translation_and_category_conflicts(tmp_path: Path) -> None:
    write_source(tmp_path, "first.json", [sentence()])
    write_source(
        tmp_path,
        "second.json",
        [sentence(original=" bonjour ", category="Travel", translation="درود")],
    )

    with pytest.raises(ContentConflictError) as raised:
        merge_source_directory(tmp_path)

    message = str(raised.value)
    assert "conflicting translation" in message
    assert "conflicting category" in message


def test_orders_merged_sentences_deterministically(tmp_path: Path) -> None:
    write_source(
        tmp_path,
        "sentences.json",
        [sentence(original="Zebra"), sentence(original="Apple")],
    )

    result = merge_source_directory(tmp_path)

    assert [merged.sentence for merged in result.sentences] == ["Apple", "Zebra"]
