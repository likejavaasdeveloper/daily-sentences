# Daily Sentences

Daily Sentences is a Flutter Web application with an independent Python content-builder tool.

## Prerequisites

- Flutter 3.32.8 with Dart 3.8.1
- Chrome for web development
- uv with managed Python 3.12

## Flutter commands

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build web
```

## Content-builder commands

```bash
cd tools/content_builder
~/.local/bin/uv sync --group dev
~/.local/bin/uv run ruff format --check .
~/.local/bin/uv run ruff check .
~/.local/bin/uv run pytest
~/.local/bin/uv run python -m content_builder
```

The authoring directory is `assets/content/`. It is intentionally empty and is not a Flutter asset.

## Local PWA production build

```bash
tools/build_web.sh /
tools/build_web.sh /daily-sentences/
```

The first command builds for a repository-root host. The second builds for a
GitHub Pages repository base path. The script prepares generated content first,
then builds and verifies the deployment artifact. Invalid content or artifact
content stops the workflow.

## P1 dependencies

| Dependency | Version | Purpose | P1 rationale | Runtime compatibility |
| --- | --- | --- | --- | --- |
| Flutter | 3.32.8 | Flutter Web framework and tooling | Required for the Web application foundation | Dart 3.8.1 |
| http | ^1.3.0 | Generated catalog retrieval | Required for catalog-only Web access in P5 | Flutter/Dart 3.8.1 |
| provider | 6.1.5+1 | Dependency composition | Required by the approved Provider composition convention | Flutter/Dart 3.8.1 |
| flutter_lints | 5.0.0 | Dart static-analysis rules | Required to establish Flutter analysis | Flutter/Dart 3.8.1 |
| hatchling | >=1.27,<2 | Python build backend | Required to install the local builder package into its isolated environment | Python 3.12 |
| pytest | 8.4.2 | Python unit testing | Required test infrastructure for the builder foundation | Python 3.12 |
| ruff | 0.17.6 | Python formatting and static analysis | Required quality tooling for the builder foundation | Python 3.12 |
