"""Entry point for the pilot's fixed, opaque checks."""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

from content_gate import ContentGateError, validate_content_gate
from evidence import EvidenceError
from gate_context import GATE_CHECKS, validate_gate_context
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "autonomy"))
import core  # noqa: E402


# Names are fixed by the approved pilot check contract. Do not infer new gates
# from an evidence envelope or a caller-supplied path.
OPAQUE_GATES = frozenset(GATE_CHECKS)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate an opaque pilot gate")
    parser.add_argument("--gate", required=True, choices=sorted(OPAQUE_GATES), action="append")
    arguments = parser.parse_args(argv)
    if len(arguments.gate) != 1:
        parser.error("--gate must be supplied exactly once")
    gate = arguments.gate[0]

    workspace = Path(__file__).resolve().parents[2]
    try:
        validate_gate_context(gate, workspace=workspace)
        if gate == "content":
            validate_content_gate(workspace=workspace, snapshot=core.snapshot(workspace))
    except (EvidenceError, ContentGateError, core.GateError, OSError, ValueError,
            KeyError, TypeError) as error:
        print(f"PILOT gate {gate} cannot pass: semantic validator unavailable; {error}",
              file=sys.stderr)
        return 1

    if gate == "content":
        return 0
    # Envelope integrity is only a prerequisite for all other gates.
    print(
        f"PILOT gate {gate} cannot pass: semantic validator and "
        "genuine gate evidence are not implemented",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
