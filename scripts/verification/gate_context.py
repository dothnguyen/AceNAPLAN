"""Trusted local context for the seven frozen pilot evidence gates.

Integrity validation is deliberately separate from semantic gate validation.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "autonomy"))
import core  # noqa: E402

from evidence import EvidenceError, validate_envelope


GATE_CHECKS = {
    "content": "PILOT-CONTENT",
    "browser": "PILOT-BROWSER-FLOWS",
    "android_integration": "PILOT-ANDROID-INTEGRATION",
    "educator": "PILOT-EDUCATOR",
    "physical_phone": "PILOT-PHYSICAL-PHONE",
    "physical_tablet": "PILOT-PHYSICAL-TABLET",
    "release_candidate": "PILOT-RELEASE-CANDIDATE",
}
EVIDENCE_ROOT = Path(".autonomy/evidence/pilot")


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError("duplicate JSON field")
        result[key] = value
    return result


def validate_gate_context(gate: str, *, workspace: Path) -> None:
    """Check the approved contract, clean source and fixed envelope integrity.

    This function never decides whether a gate passed. ``workspace`` is an
    internal runner input; the CLI always derives it from this script's path.
    """
    if gate not in GATE_CHECKS:
        raise EvidenceError("unknown pilot gate")
    root = workspace.resolve(strict=True)
    board = core.read_board(root)
    phase = core.phase_of(board, "pilot")
    approval = phase.get("approval", {})
    contract = phase.get("contract", {})
    if approval.get("status") != "approved":
        raise EvidenceError("pilot scope is not approved")
    scope = core.local(root, phase.get("scope_path", ""))
    if (not scope.is_file() or approval.get("scope_sha256") != core.scope_digest(scope)
            or approval.get("contract_sha256") != core.digest(contract)):
        raise EvidenceError("pilot scope or check contract has changed")
    core.validate_contract(contract)
    checks = contract["checks"]
    required = contract["required_phase_checks"]
    for name, check_id in GATE_CHECKS.items():
        if (checks.get(check_id) != ["python", "scripts/verification/pilot_gate.py", "--gate", name]
                or check_id not in required):
            raise EvidenceError("frozen pilot check contract mismatch")
    core.integrated(root, phase)
    current = core.snapshot(root)

    evidence_root = (root / EVIDENCE_ROOT).resolve(strict=True)
    if not evidence_root.is_dir() or not evidence_root.is_relative_to(root):
        raise EvidenceError("pilot evidence root is invalid")
    envelope_path = root / EVIDENCE_ROOT / "gates" / f"{gate}.json"
    if envelope_path.is_symlink() or not envelope_path.is_file():
        raise EvidenceError("fixed gate envelope is missing or invalid")
    if not envelope_path.resolve(strict=True).is_relative_to(evidence_root):
        raise EvidenceError("gate envelope leaves pilot evidence root")
    try:
        envelope = json.loads(envelope_path.read_text(encoding="utf-8"),
                              object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise EvidenceError("gate envelope cannot be read as JSON") from error
    validate_envelope(envelope, expected_snapshot=current, workspace=root,
                      allowed_gates={GATE_CHECKS[gate]}, artifact_roots=[evidence_root])
