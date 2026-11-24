import json
import subprocess
import sys
from pathlib import Path

import pytest

from content_builder.validation import (
    ContentValidationError,
    discover_source_files,
    validate_source_directory,
)


def write_source(directory: Path, name: str, content: object) -> Path:
    source_file = directory / name
    source_file.write_text(json.dumps(content), encoding="utf-8")
    return source_file


def valid_sentence() -> dict[str, str]:
    return {
        "language": "de",
        "category": "Greetings",
        "sentence": "Guten Morgen",
        "translation": "صبح بخیر",
    }


def test_zero_source_files_is_valid(tmp_path: Path) -> None:
    result = validate_source_directory(tmp_path)

    assert result.source_file_count == 0
    assert result.sentence_count == 0


def test_discovers_flat_json_files_automatically(tmp_path: Path) -> None:
    write_source(tmp_path, "second.json", {"sentences": [valid_sentence()]})
    write_source(tmp_path, "first.json", {"sentences": [valid_sentence()]})
    (tmp_path / ".gitkeep").touch()

    discovered = discover_source_files(tmp_path)
    result = validate_source_directory(tmp_path)

    assert [source.name for source in discovered] == ["first.json", "second.json"]
    assert result.source_file_count == 2
    assert result.sentence_count == 2


def test_accepts_multiple_languages_and_categories_in_one_file(tmp_path: Path) -> None:
    write_source(
        tmp_path,
        "sentences.json",
        {
            "sentences": [
                valid_sentence(),
                {
                    "language": "fr-FR",
                    "category": "Travel",
                    "sentence": "Où est la gare ?",
                    "translation": "ایستگاه کجاست؟",
                    "usage": "Asking for directions",
                },
            ]
        },
    )

    result = validate_source_directory(tmp_path)

    assert result.sentence_count == 2


def test_invalid_json_reports_file_line_and_column(tmp_path: Path) -> None:
    source_file = tmp_path / "broken.json"
    source_file.write_text('{"sentences": [}', encoding="utf-8")

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    message = str(raised.value)
    assert str(source_file) in message
    assert "invalid JSON at line" in message
    assert "column" in message


@pytest.mark.parametrize(
    ("document", "expected_message"),
    [
        ([], "root value must be an object"),
        ({}, 'field "sentences" must be a nonempty array'),
        ({"sentences": []}, 'field "sentences" must be a nonempty array'),
        ({"sentences": [valid_sentence()], "unknown": True}, 'unknown field "unknown"'),
    ],
)
def test_reports_invalid_root_contract(
    tmp_path: Path,
    document: object,
    expected_message: str,
) -> None:
    source_file = write_source(tmp_path, "source.json", document)

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    assert str(source_file) in str(raised.value)
    assert expected_message in str(raised.value)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("language", ""),
        ("category", "   "),
        ("sentence", None),
        ("translation", 7),
    ],
)
def test_reports_required_field_at_sentence_position(
    tmp_path: Path,
    field: str,
    value: object,
) -> None:
    sentence = valid_sentence()
    sentence[field] = value
    source_file = write_source(tmp_path, "source.json", {"sentences": [sentence]})

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{source_file}: sentences[0]" in message
    assert f'required field "{field}" must be a nonempty string' in message


def test_reports_unknown_sentence_field_and_invalid_usage_position(
    tmp_path: Path,
) -> None:
    sentence = valid_sentence()
    sentence["usage"] = ""
    sentence["id"] = "not allowed"
    source_file = write_source(tmp_path, "source.json", {"sentences": [sentence]})

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{source_file}: sentences[0]" in message
    assert 'unknown field "id"' in message
    assert 'optional field "usage" must be a nonempty string when provided' in message


@pytest.mark.parametrize(
    "language",
    [
        "de",
        "fr-FR",
        "zh-Hant-TW",
        "sl-rozaj-biske-1994",
        "de-CH-1901",
        "en-a-myext-b-another-x-private",
        "x-private",
        "i-klingon",
    ],
)
def test_accepts_valid_bcp47_language_tags(tmp_path: Path, language: str) -> None:
    sentence = valid_sentence()
    sentence["language"] = language
    write_source(tmp_path, "source.json", {"sentences": [sentence]})

    result = validate_source_directory(tmp_path)

    assert result.sentence_count == 1


@pytest.mark.parametrize(
    "language",
    [
        "French",
        "en_US",
        "en-",
        "e",
        "en--US",
        "en-US-u",
        "en-US-u-ca-u-nu",
        "de-1901-1901",
        "x",
        " en-US",
    ],
)
def test_rejects_invalid_bcp47_language_tags_at_sentence_position(
    tmp_path: Path,
    language: str,
) -> None:
    sentence = valid_sentence()
    sentence["language"] = language
    source_file = write_source(
        tmp_path,
        "source.json",
        {"sentences": [sentence]},
    )

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{source_file}: sentences[0]" in message
    assert 'field "language" must be a valid BCP 47 language tag' in message


def test_reports_each_invalid_sentence_position(tmp_path: Path) -> None:
    source_file = write_source(
        tmp_path,
        "source.json",
        {"sentences": [valid_sentence(), {}, "invalid sentence"]},
    )

    with pytest.raises(ContentValidationError) as raised:
        validate_source_directory(tmp_path)

    message = str(raised.value)
    assert f"{source_file}: sentences[1]" in message
    assert f"{source_file}: sentences[2]" in message


def test_command_validates_selected_directory(tmp_path: Path) -> None:
    write_source(tmp_path, "source.json", {"sentences": [valid_sentence()]})

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "content_builder",
            "--source-directory",
            str(tmp_path),
            "--output-directory",
            str(tmp_path / "generated"),
            "--state-file",
            str(tmp_path / "state.json"),
        ],
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    assert result.stdout == (
        "Prepared 1 source files and 1 unique sentences using a full build.\n"
    )


def test_command_reports_invalid_content(tmp_path: Path) -> None:
    source_file = write_source(tmp_path, "source.json", {"sentences": [{}]})

    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "content_builder",
            "--source-directory",
            str(tmp_path),
            "--output-directory",
            str(tmp_path / "generated"),
            "--state-file",
            str(tmp_path / "state.json"),
        ],
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 1
    assert f"{source_file}: sentences[0]" in result.stdout
