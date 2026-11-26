import importlib.util
import json
import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[3] / "tools" / "verify_web_artifact.py"
SPEC = importlib.util.spec_from_file_location("verify_web_artifact", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def write_minimal_artifact(artifact: Path) -> None:
    artifact.mkdir()
    (artifact / "index.html").write_text(
        '<html><head><base href="/daily-sentences/">'
        "<title>Daily Sentences</title>"
        '<link rel="manifest" href="manifest.json"></head></html>',
        encoding="utf-8",
    )
    (artifact / "manifest.json").write_text(
        json.dumps(
            {
                "name": "Daily Sentences",
                "short_name": "Daily Sentences",
                "start_url": ".",
                "scope": ".",
                "icons": [
                    {"src": f"icons/Icon-{size}.png", "sizes": f"{size}x{size}"}
                    for size in (192, 512)
                ]
                + [
                    {
                        "src": f"icons/Icon-maskable-{size}.png",
                        "sizes": f"{size}x{size}",
                    }
                    for size in (192, 512)
                ],
            }
        ),
        encoding="utf-8",
    )
    for relative in (
        "flutter_bootstrap.js",
        "flutter_service_worker.js",
        "favicon.png",
        "icons/Icon-192.png",
        "icons/Icon-512.png",
        "icons/Icon-maskable-192.png",
        "icons/Icon-maskable-512.png",
    ):
        path = artifact / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"x")
    (artifact / "flutter_service_worker.js").write_text(
        "  if (key == 'generated/catalog.json' || "
        "key.startsWith('generated/sentences/')) {\n"
        "    return event.respondWith(fetch(event.request, {cache: 'reload'}));\n"
        "  }\n",
        encoding="utf-8",
    )
    generated = artifact / "generated"
    generated.mkdir()
    (generated / "catalog.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "contentVersion": "0" * 64,
                "languages": [],
            }
        ),
        encoding="utf-8",
    )


def test_accepts_empty_valid_deployment_artifact(tmp_path: Path) -> None:
    artifact = tmp_path / "web"
    write_minimal_artifact(artifact)

    assert MODULE.verify_artifact(artifact, "/daily-sentences/") == []


def test_rejects_authoring_and_builder_state(tmp_path: Path) -> None:
    artifact = tmp_path / "web"
    write_minimal_artifact(artifact)
    (artifact / "assets" / "content").mkdir(parents=True)
    (artifact / "assets" / "content" / "source.json").write_text("{}", encoding="utf-8")
    (artifact / ".content-builder-state").mkdir()

    errors = MODULE.verify_artifact(artifact, "/daily-sentences/")

    assert any("assets/content" in error for error in errors)
    assert any("authoring" in error and "path" in error for error in errors)


def test_service_worker_configures_generated_content_network_only(
    tmp_path: Path,
) -> None:
    worker = tmp_path / "flutter_service_worker.js"
    worker.write_text(
        "  if (!RESOURCES[key]) {\n"
        "    return;\n"
        "  }\n"
        "  event.respondWith(fetch(event.request));\n",
        encoding="utf-8",
    )
    script = (
        Path(__file__).resolve().parents[3] / "tools" / "configure_service_worker.py"
    )

    result = subprocess.run(
        ["python3", str(script), "--worker", str(worker)],
        check=False,
        capture_output=True,
        text=True,
    )

    assert result.returncode == 0
    configured = worker.read_text(encoding="utf-8")
    assert "key == 'generated/catalog.json'" in configured
    assert "key.startsWith('generated/sentences/')" in configured
