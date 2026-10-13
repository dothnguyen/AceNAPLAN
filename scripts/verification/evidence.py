"""Fail-closed integrity checks for pilot verification evidence envelopes.

This module checks structure and local artifact integrity only. Callers must run
the gate-specific semantic checks before treating any pilot gate as passed.
"""

from __future__ import annotations

import hashlib
import re
from datetime import datetime
from pathlib import Path, PureWindowsPath
from typing import Any, Collection


class EvidenceError(ValueError):
    """An evidence envelope cannot be trusted for further gate validation."""


_DIGEST = re.compile(r"[0-9a-f]{64}\Z")
_HEAD = re.compile(r"[0-9a-f]{40}\Z")
_GATE = re.compile(r"PILOT-[A-Z0-9-]+\Z")
_PRODUCER_TYPES = frozenset({"tool", "human", "device", "reviewer", "test"})


def _object(value: Any, fields: set[str], label: str) -> dict:
    if type(value) is not dict or set(value) != fields:
        raise EvidenceError(f"{label} must contain exactly {sorted(fields)}")
    return value


def _nonempty(value: Any, label: str) -> str:
    if type(value) is not str or not value.strip() or value != value.strip():
        raise EvidenceError(f"{label} must be a nonempty trimmed string")
    return value


def _digest(value: Any, label: str) -> str:
    if type(value) is not str or _DIGEST.fullmatch(value) is None:
        raise EvidenceError(f"{label} must be a lowercase SHA-256 digest")
    return value


def _snapshot(value: Any, label: str) -> dict:
    value = _object(value, {"head", "source_sha256"}, label)
    if type(value["head"]) is not str or _HEAD.fullmatch(value["head"]) is None:
        raise EvidenceError(f"{label}.head must be a lowercase Git commit ID")
    _digest(value["source_sha256"], f"{label}.source_sha256")
    return value


def _json_value(value: Any) -> bool:
    if value is None or type(value) in (str, bool, int):
        return True
    if type(value) is float:
        return value == value and value not in (float("inf"), float("-inf"))
    if type(value) is list:
        return all(_json_value(item) for item in value)
    if type(value) is dict:
        return all(type(key) is str and _json_value(item) for key, item in value.items())
    return False


def validate_envelope(
    envelope: Any,
    *,
    expected_snapshot: dict,
    workspace: Path,
    allowed_gates: Collection[str],
    artifact_roots: Collection[Path] | None = None,
) -> None:
    """Raise EvidenceError unless the schema, snapshot and artifacts are valid.

    ``expected_snapshot`` and ``allowed_gates`` must come from a trusted runner,
    not from the envelope being checked. No gate success is decided here.
    """
    expected = _snapshot(expected_snapshot, "expected_snapshot")
    envelope = _object(
        envelope,
        {"schema_version", "gate_id", "status", "observed_at", "producer",
         "snapshot", "observations", "artifacts"},
        "envelope",
    )
    if type(envelope["schema_version"]) is not int or envelope["schema_version"] != 1:
        raise EvidenceError("unsupported schema_version")
    gate = _nonempty(envelope["gate_id"], "gate_id")
    if _GATE.fullmatch(gate) is None or gate not in allowed_gates:
        raise EvidenceError("unknown gate_id")
    if envelope["status"] != "passed" or type(envelope["status"]) is not str:
        raise EvidenceError("status must be passed")
    observed_at = _nonempty(envelope["observed_at"], "observed_at")
    try:
        instant = datetime.fromisoformat(observed_at.replace("Z", "+00:00"))
    except ValueError as error:
        raise EvidenceError("observed_at must be ISO 8601") from error
    if instant.tzinfo is None or instant.utcoffset() is None:
        raise EvidenceError("observed_at must include a timezone")
    producer = _object(envelope["producer"], {"id", "type"}, "producer")
    _nonempty(producer["id"], "producer.id")
    if type(producer["type"]) is not str or producer["type"] not in _PRODUCER_TYPES:
        raise EvidenceError("unsupported producer.type")
    if _snapshot(envelope["snapshot"], "snapshot") != expected:
        raise EvidenceError("stale source snapshot")
    observations = envelope["observations"]
    if type(observations) is not dict or not observations or not _json_value(observations):
        raise EvidenceError("observations must be a nonempty JSON object")
    artifacts = envelope["artifacts"]
    if type(artifacts) is not list or not artifacts:
        raise EvidenceError("artifacts must be a nonempty list")

    root = Path(workspace).resolve(strict=True)
    if not root.is_dir():
        raise EvidenceError("workspace must be a directory")
    roots = [Path(path).resolve(strict=True) for path in ([root] if artifact_roots is None else artifact_roots)]
    if not roots or any(not path.is_dir() or not path.is_relative_to(root) for path in roots):
        raise EvidenceError("artifact roots must be workspace directories")
    seen: set[Path] = set()
    for artifact in artifacts:
        artifact = _object(artifact, {"path", "sha256"}, "artifact")
        name = _nonempty(artifact["path"], "artifact.path")
        digest = _digest(artifact["sha256"], "artifact.sha256")
        relative = Path(name)
        if (relative.is_absolute() or PureWindowsPath(name).is_absolute()
                or PureWindowsPath(name).drive or "\\" in name
                or any(part in (".", "..") for part in name.split("/"))):
            raise EvidenceError("unsafe artifact path")
        target = (root / relative).resolve(strict=False)
        if not target.is_relative_to(root) or not any(target.is_relative_to(path) for path in roots):
            raise EvidenceError("artifact leaves permitted roots")
        if target in seen:
            raise EvidenceError("duplicate artifact reference")
        seen.add(target)
        if not target.is_file():
            raise EvidenceError("artifact is missing or not a file")
        hasher = hashlib.sha256()
        try:
            with target.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    hasher.update(chunk)
        except OSError as error:
            raise EvidenceError("artifact cannot be read") from error
        if hasher.hexdigest() != digest:
            raise EvidenceError("artifact digest mismatch")
