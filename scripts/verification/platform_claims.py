"""Pure structural checks for claimed pilot platform observations.

These checks reject substitutions; they cannot authenticate a person, device,
execution, or locally editable evidence. The opaque CLI remains fail-closed.
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any, Mapping


class PlatformClaimError(ValueError):
    """A platform observation is missing or contradicts its claimed gate."""


_SHA = re.compile(r"[0-9a-f]{64}\Z")
_RUN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._:-]{7,127}\Z")
_FLOWS = {
    "browser": {"practice", "feedback", "summary"},
    "android_integration": {"sqlite_save_restart", "migration", "offline_practice"},
    "physical_phone": {"offline_practice", "audio", "accessibility"},
    "physical_tablet": {"offline_practice", "audio", "accessibility"},
}


def _object(value: Any, fields: set[str], label: str) -> dict:
    if type(value) is not dict or set(value) != fields:
        raise PlatformClaimError(f"{label} must contain exactly {sorted(fields)}")
    return value


def _string(value: Any, label: str) -> str:
    if type(value) is not str or not value or value != value.strip():
        raise PlatformClaimError(f"{label} must be a nonempty trimmed string")
    return value


def _instant(value: Any, label: str) -> datetime:
    raw = _string(value, label)
    try:
        instant = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as error:
        raise PlatformClaimError(f"{label} must be ISO 8601") from error
    if instant.utcoffset() is None:
        raise PlatformClaimError(f"{label} requires a timezone")
    return instant


def _artifact(value: Any, label: str, known: Mapping[str, str]) -> None:
    if _string(value, label) not in known:
        raise PlatformClaimError(f"{label} must reference an envelope artifact")


def validate_platform_observation(
    gate: str,
    observation: Any,
    *,
    expected_snapshot: dict,
    artifact_digests: Mapping[str, str],
) -> None:
    """Check a typed observation against trusted snapshot and artifact names.

    The caller must separately validate artifact bytes and provenance. A
    successful return establishes only consistency of locally supplied data.
    """
    if gate not in _FLOWS:
        raise PlatformClaimError("unsupported platform gate")
    item = _object(observation, {"run", "source", "build", "target", "adapter", "flows"},
                   "observation")
    run = _object(item["run"], {"id", "started_at", "ended_at", "command",
                                "build_id", "target_device_id", "log_artifact"}, "run")
    if _RUN.fullmatch(_string(run["id"], "run.id")) is None:
        raise PlatformClaimError("run.id has invalid syntax")
    if _instant(run["ended_at"], "run.ended_at") <= _instant(run["started_at"], "run.started_at"):
        raise PlatformClaimError("run must have a positive elapsed interval")
    _string(run["command"], "run.command")
    _artifact(run["log_artifact"], "run.log_artifact", artifact_digests)

    source = _object(item["source"], {"head", "source_sha256"}, "source")
    if source != expected_snapshot:
        raise PlatformClaimError("stale or mismatched source snapshot")
    build = _object(item["build"], {"id", "sha256", "artifact"}, "build")
    _string(build["id"], "build.id")
    if type(build["sha256"]) is not str or _SHA.fullmatch(build["sha256"]) is None:
        raise PlatformClaimError("build.sha256 must be a lowercase SHA-256 digest")
    _artifact(build["artifact"], "build.artifact", artifact_digests)
    if build["sha256"] != artifact_digests[build["artifact"]]:
        raise PlatformClaimError("build digest does not match its envelope artifact")
    if run["build_id"] != build["id"]:
        raise PlatformClaimError("run does not identify its claimed build")

    target = _object(item["target"], {"platform", "kind", "device_id", "form_factor"}, "target")
    platform = _string(target["platform"], "target.platform")
    kind = _string(target["kind"], "target.kind")
    device_id = _string(target["device_id"], "target.device_id")
    if run["target_device_id"] != device_id:
        raise PlatformClaimError("run does not identify its claimed target")
    form_factor = _string(target["form_factor"], "target.form_factor")
    adapter = _string(item["adapter"], "adapter")
    if gate == "browser":
        if (platform, kind, form_factor, adapter) != ("web", "browser", "browser", "memory"):
            raise PlatformClaimError("browser flow requires a Web browser and memory adapter")
    elif gate == "android_integration":
        if platform != "android" or kind not in {"emulator", "physical"} or adapter != "sqlite":
            raise PlatformClaimError("Android integration requires native Android SQLite")
        if form_factor not in {"phone", "tablet"}:
            raise PlatformClaimError("Android form factor must be phone or tablet")
    else:
        expected_form = gate.removeprefix("physical_")
        if (platform, kind, form_factor, adapter) != ("android", "physical", expected_form, "sqlite"):
            raise PlatformClaimError("physical gate requires a native physical Android SQLite target")
    if not device_id or device_id.lower() in {"unknown", "none", "generic"}:
        raise PlatformClaimError("target.device_id must identify the observed target")

    flows = item["flows"]
    if type(flows) is not list or not flows:
        raise PlatformClaimError("flows must contain executed results")
    seen = set()
    for flow in flows:
        result = _object(flow, {"name", "outcome", "artifact"}, "flow")
        name = _string(result["name"], "flow.name")
        if name in seen:
            raise PlatformClaimError("duplicate flow result")
        seen.add(name)
        if result["outcome"] != "passed" or type(result["outcome"]) is not str:
            raise PlatformClaimError("flow outcome must be passed")
        _artifact(result["artifact"], "flow.artifact", artifact_digests)
    if seen != _FLOWS[gate]:
        raise PlatformClaimError("required executed flows are missing or unexpected")


def validate_physical_pair(phone: dict, tablet: dict) -> None:
    """Reject duplicate target identities across already validated observations."""
    if phone["target"]["device_id"] == tablet["target"]["device_id"]:
        raise PlatformClaimError("phone and tablet must have distinct device identities")
    if phone["run"]["id"] == tablet["run"]["id"]:
        raise PlatformClaimError("phone and tablet must have distinct run identities")
