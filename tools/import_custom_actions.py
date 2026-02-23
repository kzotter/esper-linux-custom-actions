#!/usr/bin/env python3
"""
Esper Linux Custom Actions Importer (guardrail-compliant)

- Production base URL only: https://{tenant}-api.esper.cloud/api
- Auth: Authorization: Bearer {API_KEY}
- No enterprise_id unless endpoint explicitly requires it (Custom Actions does not)
- Dry-run by default, writes only with --apply
- Idempotent by name: GET-before-POST/PUT
- Converts repo-friendly manifests (script_file/args) into Esper API payload (script content)

Docs (reference):
- GET /v2/custom-actions/ supports name filter, pagination, response in content.results
- POST /v2/custom-actions/ expects options[].scripts.linux.script content
"""

import argparse
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
import urllib.parse
import urllib.request
import urllib.error


def eprint(*args: Any) -> None:
    print(*args, file=sys.stderr)


def die(msg: str, code: int = 2) -> None:
    eprint(f"ERROR: {msg}")
    sys.exit(code)


def load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as ex:
        die(f"Failed to read JSON {path}: {ex}")


def save_pretty(obj: Any) -> str:
    return json.dumps(obj, indent=2, sort_keys=True)


def is_probably_raw_shell_token(s: str) -> bool:
    # Allow env expansion for tokens like ${IFACE} or $IFACE
    return ("${" in s) or s.startswith("$")


def sh_quote(s: str) -> str:
    # Safe single-quote for bash
    return "'" + s.replace("'", "'\"'\"'") + "'"


def make_wrapper_with_args(embedded_script: str, args: List[str]) -> str:
    # Embed the script into a function and call it with provided args.
    # Args that look like env expansions are passed through raw.
    rendered_args: List[str] = []
    for a in args:
        if is_probably_raw_shell_token(a):
            rendered_args.append(a)
        else:
            rendered_args.append(sh_quote(a))

    call = " ".join(rendered_args)

    # Indent embedded script content for readability inside function
    indented = "\n".join("  " + line for line in embedded_script.splitlines())

    return (
        "#!/usr/bin/env bash\n"
        "set -euo pipefail\n\n"
        "# Generated wrapper (repository manifest -> Esper payload)\n"
        "main() {\n"
        "  # --- begin embedded script ---\n"
        f"{indented}\n"
        "  # --- end embedded script ---\n"
        "}\n\n"
        f"main {call}\n"
    )


def inline_manifest_scripts(manifest: Dict[str, Any], manifest_dir: Path) -> None:
    """
    Convert repo-friendly:
      scripts.linux.script_file + optional scripts.linux.args
    into Esper API payload:
      scripts.linux.script (actual content)
    """
    options = manifest.get("options") or []
    for opt in options:
        scripts = opt.get("scripts") or {}
        linux = scripts.get("linux") or {}

        script_file = linux.pop("script_file", None)
        args = linux.pop("args", []) or []

        if script_file:
            script_path = (manifest_dir / script_file).resolve()
            if not script_path.exists():
                die(f"{manifest_dir}: script_file not found: {script_file} -> {script_path}")
            embedded = script_path.read_text(encoding="utf-8")

            if args:
                linux["script"] = make_wrapper_with_args(embedded, args)
            else:
                linux["script"] = embedded

        # Default interpreter if not present
        if "interpreter" not in linux or not linux["interpreter"]:
            linux["interpreter"] = "bash"

        scripts["linux"] = linux
        opt["scripts"] = scripts


def ensure_option_keys(manifest: Dict[str, Any]) -> None:
    options = manifest.get("options") or []
    for opt in options:
        if opt.get("key") in (None, "", "AUTO_UUID"):
            opt["key"] = str(uuid.uuid4())


def http_json(method: str, url: str, api_key: str, payload: Optional[Dict[str, Any]] = None) -> Tuple[int, Any]:
    data = None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url=url, method=method, headers=headers, data=data)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            if not raw:
                return resp.status, None
            try:
                return resp.status, json.loads(raw)
            except Exception:
                return resp.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        return e.code, raw
    except Exception as ex:
        die(f"HTTP request failed: {ex}")


def parse_results_list(resp: Any) -> List[Dict[str, Any]]:
    """
    Esper GET /v2/custom-actions/ returns:
      { content: { count, next, previous, results: [...] }, message, code }
    """
    if not isinstance(resp, dict):
        return []
    content = resp.get("content")
    if not isinstance(content, dict):
        return []
    results = content.get("results")
    if isinstance(results, list):
        return [r for r in results if isinstance(r, dict)]
    return []


def find_existing_action(base_url: str, api_key: str, name: str) -> Optional[Dict[str, Any]]:
    # name filter is partial match, case-insensitive; we still enforce exact match locally.
    q = urllib.parse.urlencode({"name": name, "limit": 50, "offset": 0})
    url = f"{base_url}/v2/custom-actions/?{q}"

    status, data = http_json("GET", url, api_key)
    if status != 200:
        # Most common reasons: wrong base path (/api missing) -> 404, or auth -> 401/403
        return None

    results = parse_results_list(data)
    # Exact name match (case sensitive), fallback to case-insensitive exact match
    exact = [r for r in results if r.get("name") == name]
    if not exact:
        exact = [r for r in results if isinstance(r.get("name"), str) and r.get("name").lower() == name.lower()]

    if len(exact) > 1:
        # Rare but possible if names differ only by case historically; pick the first but warn.
        eprint(f"WARNING: multiple existing custom actions matched name '{name}'. Using the first id={exact[0].get('id')}.")
    return exact[0] if exact else None


def build_payload(manifest_path: Path) -> Dict[str, Any]:
    manifest = load_json(manifest_path)

    # defensive copies / normalization
    ensure_option_keys(manifest)
    inline_manifest_scripts(manifest, manifest_path.parent)

    # Remove any repo-only fields if they slipped in
    # (We already popped script_file/args above; this is just belt-and-suspenders.)
    return manifest



    # Normalize placement fields: omit keys when unused (None)
    for k in ("position_in_blueprints", "position_in_device_settings"):
        if k in manifest and manifest.get(k) is None:
            del manifest[k]
def iter_manifests(root: Path) -> List[Path]:
    return sorted(root.rglob("action*.json"))


def main() -> None:
    ap = argparse.ArgumentParser(description="Import Esper Linux Custom Actions from action.json manifests.")
    ap.add_argument("--tenant", default=os.getenv("ESPER_TENANT"), help="Esper tenant name (env: ESPER_TENANT)")
    ap.add_argument("--api-key", default=os.getenv("ESPER_API_KEY"), help="Esper API key (env: ESPER_API_KEY)")
    ap.add_argument("--root", default="actions", help="Root folder containing action manifests (default: actions)")
    ap.add_argument("--only", default=None, help="Limit to a subpath under root, e.g. connectivity")
    ap.add_argument("--apply", action="store_true", help="Perform writes (POST/PUT). Default is dry-run.")
    ap.add_argument("--print-payloads", action="store_true", help="Print full payload JSON (dry-run only recommended).")
    args = ap.parse_args()

    if not args.tenant:
        die("Missing tenant. Provide --tenant or set ESPER_TENANT.")
    if not args.api_key:
        die("Missing API key. Provide --api-key or set ESPER_API_KEY.")

    base_url = f"https://{args.tenant}-api.esper.cloud/api"  # guardrail: always include /api
    root = Path(args.root).resolve()
    if not root.exists():
        die(f"Root path not found: {root}")

    scope = root
    if args.only:
        scope = (root / args.only).resolve()
        if not scope.exists():
            die(f"--only path not found: {scope}")

    manifests = iter_manifests(scope)
    if not manifests:
        die(f"No action manifests found under: {scope}")

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"[{mode}] Base URL: {base_url}")
    print(f"[{mode}] Manifests found: {len(manifests)} under {scope}")

    created = 0
    updated = 0
    skipped = 0

    for mp in manifests:
        payload = build_payload(mp)
        name = payload.get("name")
        if not isinstance(name, str) or not name.strip():
            eprint(f"SKIP {mp}: missing required field 'name'")
            skipped += 1
            continue

        existing = find_existing_action(base_url, args.api_key, name)
        if existing and existing.get("id"):
            action_id = existing["id"]
            print(f"[{mode}] UPDATE: {name} (id={action_id}) from {mp}")
            if args.print_payloads:
                print(save_pretty(payload))
            if args.apply:
                url = f"{base_url}/v2/custom-actions/{urllib.parse.quote(str(action_id))}/"
                if status not in (200, 201):
                    eprint(f"  -> ERROR {status}: {resp}")
                else:
                    print(f"  -> OK {status}")
                    updated += 1
        else:
            print(f"[{mode}] CREATE: {name} from {mp}")
            if args.print_payloads:
                print(save_pretty(payload))
            if args.apply:
                url = f"{base_url}/v2/custom-actions/"
                if status not in (200, 201):
                    eprint(f"  -> ERROR {status}: {resp}")
                else:
                    cid = None
                    if isinstance(resp, dict):
                        content = resp.get("content")
                        if isinstance(content, dict):
                            cid = content.get("id")
                    print(f"  -> OK {status}" + (f" (id={cid})" if cid else ""))
                    created += 1

    print(f"[{mode}] Done. Created={created}, Updated={updated}, Skipped={skipped}")


if __name__ == "__main__":
    main()
