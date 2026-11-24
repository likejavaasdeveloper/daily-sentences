import hashlib
import json
from pathlib import Path

import pytest

from content_builder.merging import ContentConflictError
from content_builder.preparation import PACKAGE_SIZE_LIMIT, prepare_content
from content_builder.validation import ContentValidationError


def write_source(directory: Path, name: str, sentences: list[dict[str, str]]) -> Path:
    source_file = directory / name
    source_file.write_text(json.dumps({"sentences": sentences}), encoding="utf-8")
    return source_file


def sentence(index: int = 0) -> dict[str, str]:
    return {
        "language": "fr",
        "category": "Greetings",
        "sentence": f"Bonjour {index}",
        "translation": f"سلام {index}",
    }


def read_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def prepare(source_directory: Path, temporary_path: Path):
    return prepare_content(
        source_directory,
        temporary_path / "generated",
        temporary_path / "state" / "state.json",
    )


def test_generates_valid_empty_catalog(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()

    result = prepare(source_directory, tmp_path)
    catalog = read_json(tmp_path / "generated" / "catalog.json")

    assert result.mode == "full"
    assert result.unique_sentence_count == 0
    assert catalog["schemaVersion"] == 1
    assert catalog["languages"] == []
    assert len(catalog["contentVersion"]) == 64
    assert not (tmp_path / "generated" / "sentences").exists()


def test_generates_catalog_package_and_checksum(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(source_directory, "source.json", [sentence()])

    result = prepare(source_directory, tmp_path)
    catalog = read_json(tmp_path / "generated" / "catalog.json")
    language = catalog["languages"][0]
    category = language["categories"][0]
    package_reference = category["packages"][0]
    package_file = tmp_path / "generated" / package_reference["path"]

    assert result.package_count == 1
    assert language["code"] == "fr"
    assert language["sentenceCount"] == 1
    assert category["code"] == "Greetings"
    assert category["sentenceCount"] == 1
    assert package_reference["sentenceCount"] == 1
    assert (
        package_reference["checksum"]
        == hashlib.sha256(package_file.read_bytes()).hexdigest()
    )
    assert read_json(package_file)["sentences"][0]["usages"] == []


def test_bounds_packages_to_500_sentences(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(
        source_directory,
        "source.json",
        [sentence(index) for index in range(PACKAGE_SIZE_LIMIT + 1)],
    )

    prepare(source_directory, tmp_path)
    catalog = read_json(tmp_path / "generated" / "catalog.json")
    packages = catalog["languages"][0]["categories"][0]["packages"]

    assert [package["sentenceCount"] for package in packages] == [500, 1]


def test_incremental_add_modify_delete_matches_full_build(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    first = write_source(source_directory, "first.json", [sentence(1)])
    output_directory = tmp_path / "generated"
    state_file = tmp_path / "state" / "state.json"

    first_result = prepare_content(source_directory, output_directory, state_file)
    assert first_result.mode == "full"

    second = write_source(source_directory, "second.json", [sentence(2)])
    added_result = prepare_content(source_directory, output_directory, state_file)
    assert added_result.mode == "incremental"
    assert added_result.changed_sources == ("second.json",)

    write_source(source_directory, "first.json", [sentence(3)])
    modified_result = prepare_content(source_directory, output_directory, state_file)
    assert modified_result.changed_sources == ("first.json",)

    second.unlink()
    deleted_result = prepare_content(source_directory, output_directory, state_file)
    assert deleted_result.removed_sources == ("second.json",)

    full_output = tmp_path / "full-generated"
    full_state = tmp_path / "full-state" / "state.json"
    prepare_content(source_directory, full_output, full_state)

    assert _tree_contents(output_directory) == _tree_contents(full_output)
    assert first.exists()


def test_missing_or_incompatible_state_falls_back_to_full(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(source_directory, "source.json", [sentence()])
    output_directory = tmp_path / "generated"
    state_file = tmp_path / "state" / "state.json"

    first_result = prepare_content(source_directory, output_directory, state_file)
    state_file.write_text('{"schemaVersion": 999}', encoding="utf-8")
    second_result = prepare_content(source_directory, output_directory, state_file)

    assert first_result.mode == "full"
    assert second_result.mode == "full"


def test_preserves_previous_output_when_validation_fails(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(source_directory, "source.json", [sentence()])
    output_directory = tmp_path / "generated"
    state_file = tmp_path / "state" / "state.json"
    prepare_content(source_directory, output_directory, state_file)
    previous_output = _tree_contents(output_directory)
    write_source(source_directory, "source.json", [{}])

    with pytest.raises(ContentValidationError):
        prepare_content(source_directory, output_directory, state_file)

    assert _tree_contents(output_directory) == previous_output


def test_preserves_previous_output_when_conflicts_fail(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(source_directory, "source.json", [sentence()])
    output_directory = tmp_path / "generated"
    state_file = tmp_path / "state" / "state.json"
    prepare_content(source_directory, output_directory, state_file)
    previous_output = _tree_contents(output_directory)
    write_source(
        source_directory, "conflict.json", [{**sentence(), "translation": "درود"}]
    )

    with pytest.raises(ContentConflictError):
        prepare_content(source_directory, output_directory, state_file)

    assert _tree_contents(output_directory) == previous_output


def test_replaces_collection_and_removes_obsolete_packages(tmp_path: Path) -> None:
    source_directory = tmp_path / "content"
    source_directory.mkdir()
    write_source(
        source_directory,
        "source.json",
        [sentence(index) for index in range(PACKAGE_SIZE_LIMIT + 1)],
    )
    output_directory = tmp_path / "generated"
    state_file = tmp_path / "state" / "state.json"
    prepare_content(source_directory, output_directory, state_file)
    previous_packages = set((output_directory / "sentences").iterdir())

    write_source(source_directory, "source.json", [sentence()])
    prepare_content(source_directory, output_directory, state_file)
    current_packages = set((output_directory / "sentences").iterdir())

    assert len(previous_packages) == 2
    assert len(current_packages) == 1
    assert previous_packages.isdisjoint(current_packages)


def _tree_contents(directory: Path) -> dict[str, bytes]:
    return {
        path.relative_to(directory).as_posix(): path.read_bytes()
        for path in sorted(directory.rglob("*"))
        if path.is_file()
    }
