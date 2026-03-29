#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT_DIR / "script/public-release-surface-manifest.json"
PRODUCT_CONF_PATH = ROOT_DIR / "product.conf"
VERSION_PATH = ROOT_DIR / "version.txt"


def format_mtime(timestamp: float) -> str:
    return datetime.fromtimestamp(timestamp, tz=timezone.utc).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_product_conf() -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in PRODUCT_CONF_PATH.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, remainder = line.partition("=")
        if sep != "=":
            continue
        key = key.strip()
        remainder = remainder.strip()
        if remainder.startswith('"'):
            quoted_match = re.match(r'^"([^"]*)"', remainder)
            if not quoted_match:
                continue
            values[key] = quoted_match.group(1)
            continue
        bare_value = remainder.split("#", 1)[0].strip()
        values[key] = bare_value
    return values


PRODUCT_CONF = parse_product_conf()
BUILD_VERSION = VERSION_PATH.read_text(encoding="utf-8").strip()
TAG = f"{PRODUCT_CONF['HYPRSPACE_TAG_PREFIX']}{BUILD_VERSION}"
CTX = {
    "version": BUILD_VERSION,
    "tag": TAG,
    "tap_repo": PRODUCT_CONF["HYPRSPACE_TAP_REPO"],
    "releases_repo": PRODUCT_CONF["HYPRSPACE_RELEASES_REPO"],
    "zip_name": f"Hyprspace-v{BUILD_VERSION}.zip",
}
CTX["zip_url"] = (
    f"https://github.com/{CTX['releases_repo']}/releases/download/{CTX['tag']}/{CTX['zip_name']}"
)
CTX["releases_readme_url"] = (
    f"https://github.com/{CTX['releases_repo']}/blob/main/README.md"
)
CTX["releases_legal_url"] = (
    f"https://github.com/{CTX['releases_repo']}/blob/main/LEGAL.md"
)
CTX["releases_license_url"] = (
    f"https://github.com/{CTX['releases_repo']}/blob/main/LICENSE"
)

MANIFEST = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def render(value: str) -> str:
    return value.format(**CTX)


def root_path(relative_path: str) -> Path:
    return (ROOT_DIR / render(relative_path)).resolve()


def render_text(text: str) -> str:
    rendered = text
    for key, value in CTX.items():
        rendered = rendered.replace(f"{{{{{key.upper()}}}}}", value)
    return rendered


def rendered_source_bytes(entry: dict[str, str]) -> bytes:
    source_path = root_path(entry["source"])
    text = source_path.read_text(encoding="utf-8")
    mode = entry.get("mode", "copy")
    if mode == "render":
        text = render_text(text)
    return text.encode("utf-8")


def validate_entry_schema(entries: list[dict[str, str]]) -> int:
    failures = 0
    print("[step] validating manifest schema")
    for entry in entries:
        mode = entry.get("mode")
        if mode not in {"copy", "render"}:
            print(f"[error] {entry.get('id', '<missing-id>')} invalid mode={mode!r}")
            failures += 1
        if "local_dest" in entry and "expected_local_parent" not in entry:
            print(f"[error] {entry['id']} missing expected_local_parent for local_dest")
            failures += 1
        if "zip_dest" in entry and "expected_zip_parent" not in entry:
            print(f"[error] {entry['id']} missing expected_zip_parent for zip_dest")
            failures += 1
    return failures


def fetch_url_bytes(url: str) -> bytes:
    with urllib.request.urlopen(render(url)) as response:
        return response.read()


def sync_local_entries(entries: list[dict[str, str]], *, only_within_root: bool = False) -> None:
    print("[step] syncing local public-surface files")
    for entry in entries:
        local_dest = entry.get("local_dest")
        if not local_dest:
            continue
        destination_path = root_path(local_dest)
        if only_within_root and ROOT_DIR not in destination_path.parents:
            continue
        destination_path.parent.mkdir(parents=True, exist_ok=True)
        destination_path.write_bytes(rendered_source_bytes(entry))
        source_path = root_path(entry["source"])
        print(
            f"[sync] {entry['id']} source={source_path} dest={destination_path} dest_parent={destination_path.parent}"
        )


def validate_local_entries(entries: list[dict[str, str]]) -> int:
    failures = 0
    print("[step] validating local public-surface files")
    for entry in entries:
        local_dest = entry.get("local_dest")
        if not local_dest:
            continue
        source_path = root_path(entry["source"])
        destination_path = root_path(local_dest)
        expected_parent = root_path(entry["expected_local_parent"])
        if not destination_path.exists():
            print(f"[error] {entry['id']} missing local destination {destination_path}")
            failures += 1
            continue
        if destination_path.parent != expected_parent:
            print(
                f"[error] {entry['id']} wrong local parent expected={expected_parent} actual={destination_path.parent} dest={destination_path}"
            )
            failures += 1
            continue
        source_bytes = rendered_source_bytes(entry)
        destination_bytes = destination_path.read_bytes()
        source_sha = sha256_bytes(source_bytes)
        destination_sha = sha256_bytes(destination_bytes)
        source_mtime = source_path.stat().st_mtime
        destination_mtime = destination_path.stat().st_mtime
        if source_sha != destination_sha:
            print(
                f"[error] {entry['id']} hash mismatch source={source_sha} dest={destination_sha} source={source_path} dest={destination_path}"
            )
            failures += 1
            continue
        if destination_mtime < source_mtime:
            print(
                f"[error] {entry['id']} stale destination source_mtime={format_mtime(source_mtime)} dest_mtime={format_mtime(destination_mtime)} source={source_path} dest={destination_path}"
            )
            failures += 1
            continue
        print(
            f"[ok] {entry['id']} source={source_path} dest={destination_path} source_sha={source_sha} dest_sha={destination_sha} source_mtime={format_mtime(source_mtime)} dest_mtime={format_mtime(destination_mtime)}"
        )
    return failures


def validate_zip_entries(entries: list[dict[str, str]], zip_path: Path) -> int:
    failures = 0
    print(f"[step] validating zip payload zip={zip_path}")
    if not zip_path.exists():
        print(f"[error] missing zip payload {zip_path}")
        return 1
    with zipfile.ZipFile(zip_path) as archive:
        names = set(archive.namelist())
        for entry in entries:
            zip_dest = entry.get("zip_dest")
            if not zip_dest:
                continue
            zip_member = render(zip_dest)
            expected_parent = render(entry["expected_zip_parent"])
            if zip_member not in names:
                print(f"[error] {entry['id']} missing zip member {zip_member}")
                failures += 1
                continue
            if str(Path(zip_member).parent) != expected_parent:
                print(
                    f"[error] {entry['id']} wrong zip parent expected={expected_parent} actual={Path(zip_member).parent} member={zip_member}"
                )
                failures += 1
                continue
            source_path = root_path(entry["source"])
            source_bytes = rendered_source_bytes(entry)
            member_bytes = archive.read(zip_member)
            source_sha = sha256_bytes(source_bytes)
            member_sha = sha256_bytes(member_bytes)
            if source_sha != member_sha:
                print(
                    f"[error] {entry['id']} zip hash mismatch source={source_sha} member={member_sha} member={zip_member}"
                )
                failures += 1
                continue
            info = archive.getinfo(zip_member)
            print(
                f"[ok] {entry['id']} zip_member={zip_member} source={source_path} source_sha={source_sha} member_sha={member_sha} zip_mtime={info.date_time}"
            )
    return failures


def validate_zip_identity(local_zip: Path, public_zip: Path) -> int:
    print(
        f"[step] validating uploaded zip identity local={local_zip} public={public_zip}"
    )
    failures = 0
    if not local_zip.exists():
        print(f"[error] missing local reference zip {local_zip}")
        return 1
    if not public_zip.exists():
        print(f"[error] missing public zip {public_zip}")
        return 1

    local_bytes = local_zip.read_bytes()
    public_bytes = public_zip.read_bytes()
    local_sha = sha256_bytes(local_bytes)
    public_sha = sha256_bytes(public_bytes)

    if local_sha != public_sha:
        print(
            f"[error] uploaded zip hash mismatch local={local_sha} public={public_sha} local_zip={local_zip} public_zip={public_zip}"
        )
        failures += 1
    else:
        print(
            f"[ok] uploaded-zip-identity local_zip={local_zip} public_zip={public_zip} local_sha={local_sha} public_sha={public_sha}"
        )

    return failures


def validate_assertions(assertions: list[dict[str, str]], mode: str) -> int:
    failures = 0
    print(f"[step] validating {mode} assertions")
    for assertion in assertions:
        if mode == "local":
            path = root_path(assertion["local_path"])
            if not path.exists():
                print(f"[error] {assertion['id']} missing local assertion path {path}")
                failures += 1
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            location = str(path)
        else:
            url = render(assertion["public_url"])
            text = fetch_url_bytes(assertion["public_url"]).decode(
                "utf-8", errors="replace"
            )
            location = url
        contains = assertion.get("contains")
        if contains and contains not in text:
            print(
                f"[error] {assertion['id']} missing expected text at {location}: {contains}"
            )
            failures += 1
            continue
        not_contains = assertion.get("not_contains")
        if not_contains and not_contains in text:
            print(
                f"[error] {assertion['id']} found forbidden text at {location}: {not_contains}"
            )
            failures += 1
            continue
        print(f"[ok] {assertion['id']} location={location}")
    return failures


def validate_public_entries(entries: list[dict[str, str]]) -> int:
    failures = 0
    print("[step] validating public raw-file surfaces")
    for entry in entries:
        public_url = entry.get("public_url")
        if not public_url:
            continue
        source_bytes = rendered_source_bytes(entry)
        fetched_bytes = fetch_url_bytes(public_url)
        source_sha = sha256_bytes(source_bytes)
        fetched_sha = sha256_bytes(fetched_bytes)
        if source_sha != fetched_sha:
            print(
                f"[error] {entry['id']} public hash mismatch source={source_sha} fetched={fetched_sha} url={render(public_url)}"
            )
            failures += 1
            continue
        print(
            f"[ok] {entry['id']} url={render(public_url)} source_sha={source_sha} fetched_sha={fetched_sha}"
        )
    return failures


def resolve_zip_path(
    phase: str, zip_argument: str | None
) -> tuple[Path, tempfile.TemporaryDirectory[str] | None]:
    if zip_argument:
        return root_path(zip_argument) if not Path(
            zip_argument
        ).is_absolute() else Path(zip_argument), None
    if phase == "zip":
        return root_path(f"AeroSpace/.release/Hyprspace-v{BUILD_VERSION}.zip"), None
    temporary_dir = tempfile.TemporaryDirectory()
    zip_path = Path(temporary_dir.name) / CTX["zip_name"]
    print(f"[step] downloading public zip {CTX['zip_url']} -> {zip_path}")
    urllib.request.urlretrieve(CTX["zip_url"], zip_path)
    return zip_path, temporary_dir


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--phase",
        choices=["local", "local-sync", "local-owned-sync", "zip", "public"],
        required=True,
    )
    parser.add_argument("--zip", dest="zip_path")
    args = parser.parse_args()

    entries = MANIFEST["entries"]
    assertions = MANIFEST["assertions"]
    failures = 0
    temp_dir: tempfile.TemporaryDirectory[str] | None = None

    failures += validate_entry_schema(entries)

    if args.phase == "local-sync":
        sync_local_entries(entries)
        failures += validate_local_entries(entries)
        failures += validate_assertions(assertions, mode="local")
    elif args.phase == "local-owned-sync":
        sync_local_entries(entries, only_within_root=True)
        failures += validate_local_entries(entries)
        failures += validate_assertions(assertions, mode="local")
    elif args.phase == "local":
        failures += validate_local_entries(entries)
        failures += validate_assertions(assertions, mode="local")
    elif args.phase == "zip":
        zip_path, temp_dir = resolve_zip_path("zip", args.zip_path)
        failures += validate_zip_entries(entries, zip_path)
        failures += validate_assertions(assertions, mode="local")
    else:
        zip_path, temp_dir = resolve_zip_path("public", args.zip_path)
        local_zip_path = root_path(f"AeroSpace/.release/Hyprspace-v{BUILD_VERSION}.zip")
        failures += validate_public_entries(entries)
        failures += validate_assertions(assertions, mode="public")
        failures += validate_zip_identity(local_zip_path, zip_path)

    if temp_dir is not None:
        temp_dir.cleanup()

    if failures:
        print(f"[error] validate-public-release-surface failed count={failures}")
        return 1
    print(
        f"[ok] validate-public-release-surface phase={args.phase} version={BUILD_VERSION}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
