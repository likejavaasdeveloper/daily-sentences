#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
base_href="${1:-/}"

if [[ "$base_href" != /* || "$base_href" != */ ]]; then
  echo "base href must start and end with a slash, for example: /daily-sentences/" >&2
  exit 2
fi

cd "$repository_root/tools/content_builder"
if command -v uv >/dev/null 2>&1; then
  uv run --frozen python -m content_builder
elif [[ -x "$HOME/.local/bin/uv" ]]; then
  "$HOME/.local/bin/uv" run --frozen python -m content_builder
else
  echo "uv is required to prepare content." >&2
  exit 127
fi

cd "$repository_root"
flutter build web --base-href "$base_href"
python3 "$repository_root/tools/configure_service_worker.py" \
  --worker "$repository_root/build/web/flutter_service_worker.js"
python3 "$repository_root/tools/verify_web_artifact.py" \
  --artifact "$repository_root/build/web" \
  --base-href "$base_href"
