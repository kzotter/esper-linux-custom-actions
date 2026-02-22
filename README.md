# Esper Linux Custom Actions Library

This repository contains a structured library of Linux Custom Actions designed for import into an Esper tenant using the Custom Actions API.

The goal is simple:

Turn repeatable Linux operational controls and telemetry primitives into version-controlled, API-driven Custom Actions that can be deployed consistently across tenants.

This is not a random script collection.  
It is a framework for operationalizing Linux fleet controls inside Esper.

---

## Repository Structure

actions/
connectivity/
docker/
display/
gpu-inference/
logs/
security/
system/

lib/
esper_action_lib.sh

tools/   (importer lives here)

.gitignore
README.md

Each action:

- Has a shell script implementation (`.sh`)
- Emits structured JSON (success/error and optional data payload)
- Is designed to be portable across common Linux distros
- Can be wrapped by an `action.json` manifest for API import

The shared library (`lib/esper_action_lib.sh`) provides:

- Distro detection
- Init system detection
- Container runtime detection
- JSON emit helpers (`json_emit`, `json_emit_data`)
- Privilege handling

---

## Philosophy

Linux is not one OS.

Different distros, init systems, container runtimes, and GPU stacks behave differently.  
These actions are intentionally:

- Capability-aware  
- Best-effort  
- Explicit about failure reasons  
- Safe by default  

Many actions emit structured telemetry via `json_emit_data`.  
This enables Custom Actions to act as lightweight observability primitives — not just “buttons that run commands.”

---

## Importing Into an Esper Tenant

Custom Actions are imported via the Esper Custom Actions API.

Production base URL format:
https://{tenant}-api.esper.cloud/api
Authentication:
Authorization: Bearer {API_KEY}
API keys must be stored securely (environment variables recommended).  
Never commit API keys to this repository.

Custom Actions are created via:
POST /api/v2/custom-actions/
The importer script (coming soon in `/tools`) will:

- Read `action.json` manifests
- Inline script content
- Generate UUID keys for options
- Perform GET-before-POST/PUT
- Support dry-run mode
- Create actions in `draft` state by default

---

## Safe Automation Defaults

This project follows these rules:

- No hardcoded API keys
- Dry-run mode for write operations
- Idempotent imports (update if exists, create if missing)
- No assumption of `enterprise_id` unless explicitly required by endpoint
- Exact endpoint paths from Esper API reference only

---

## Testing

Scripts should be validated on real Linux devices before activation in a production tenant.

Many actions require:

- root or sudo privileges
- systemd or openrc
- specific runtime tools (docker, nvidia-smi, nmcli, etc.)

Failure paths are intentional and part of the design.

---

## Current Action Categories

- Connectivity (Wi-Fi, Bluetooth, DNS, interfaces)
- Docker (daemon and container operations + telemetry)
- Display / Kiosk
- GPU / Inference
- Logs
- Security
- System (reboot, disk, NTP, host telemetry)
- Updates

---

## Why This Exists

Esper supports Linux Custom Actions.  
This repository makes them:

- Reproducible
- Version-controlled
- Reviewable
- Tenant-portable
- API-driven

It is designed to evolve into a standardized action manifest framework that maps directly to the Esper Custom Actions API schema.

---

## Status

Active development.  
Importer tooling and action manifest schema currently in progress.
