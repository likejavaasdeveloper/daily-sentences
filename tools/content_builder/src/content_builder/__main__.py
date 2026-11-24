import argparse
from pathlib import Path

from content_builder.merging import ContentConflictError
from content_builder.preparation import prepare_content
from content_builder.validation import ContentValidationError


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-directory",
        type=Path,
        default=Path(__file__).resolve().parents[4] / "assets" / "content",
    )
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=Path(__file__).resolve().parents[4] / "web" / "generated",
    )
    parser.add_argument(
        "--state-file",
        type=Path,
        default=(
            Path(__file__).resolve().parents[2]
            / ".content-builder-state"
            / "state.json"
        ),
    )
    arguments = parser.parse_args()

    try:
        result = prepare_content(
            arguments.source_directory,
            arguments.output_directory,
            arguments.state_file,
        )
    except (ContentValidationError, ContentConflictError) as error:
        for issue in error.issues:
            print(issue.render())
        return 1

    print(
        f"Prepared {result.source_file_count} source files and "
        f"{result.unique_sentence_count} unique sentences "
        f"using a {result.mode} build."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
