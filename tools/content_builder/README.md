# Content Builder

The content builder validates flat authoring JSON files under `assets/content/`.

## Validation command

```bash
~/.local/bin/uv run python -m content_builder
```

Use `--source-directory` to validate another flat source directory during development or testing.

## Local production build

From the repository root:

```bash
tools/build_web.sh /
tools/build_web.sh /daily-sentences/
```

The build script prepares and validates content before `flutter build web`, then
verifies the generated Web artifact. A failed content preparation or artifact
validation stops the build workflow and leaves the prior preparation output
unchanged.

## Authoring contract

Each JSON source file is an object with exactly one field, `sentences`. The field must be a nonempty array. Every sentence entry must be an object with these required nonempty string fields:

- `language`
- `category`
- `sentence`
- `translation`

`usage` is optional; when provided, it must be a nonempty string. Unknown fields are rejected. The builder does not require sentence IDs.

`language` must be a valid BCP 47 language tag such as `de`, `fr-FR`, or `zh-Hant-TW`.

The source directory may contain zero JSON files. The builder reports invalid JSON by source file, line, and column, and sentence contract errors by source file and zero-based sentence-array position.

## Duplicate handling

The builder matches duplicate candidates with deterministic NFC Unicode normalization, case folding, and collapsed whitespace on language and original sentence text. It preserves the first authored display text and treats meaningful diacritic differences as distinct.

Compatible duplicates merge into one in-memory sentence result. Distinct nonempty usage values are retained. Different translations or categories are reported as conflicts with both source locations. This validation step does not generate a published JSON schema or output files.
