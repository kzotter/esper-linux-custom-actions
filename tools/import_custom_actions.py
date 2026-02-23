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


def is_uuid4(s: str) -> bool:
    try:
        u = uuid.UUID(str(s))
        return u.version == 4
    except Exception:
        return False


def ensure_option_keys(manifest: Dict[str, Any], strict: bool = False) -> None:
    options = manifest.get("options") or []
    for opt in options:
        k = opt.get("key")

        # If missing or explicitly AUTO_UUID -> generate new UUIDv4
        if not k or k == "AUTO_UUID":
            opt["key"] = str(uuid.uuid4())
            continue

        # If present but not UUIDv4 -> fix or fail
        if not is_uuid4(str(k)):
            msg = f"Option key must be UUIDv4. Got '{k}'."
            if strict:
                die(msg)
            else:
                eprint(f"WARNING: {msg} Replacing with new UUIDv4.")
                opt["key"] = str(uuid.uuid4())

