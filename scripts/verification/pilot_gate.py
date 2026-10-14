"""Entry point for the pilot's opaque checks.

Gate-specific semantic validators are not installed yet. An evidence envelope
alone cannot prove a check passed, so every supported gate currently fails.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

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

    try:
        validate_gate_context(gate, workspace=Path(__file__).resolve().parents[2])
    except (EvidenceError, core.GateError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"PILOT gate {gate} cannot pass: semantic validator unavailable; {error}",
              file=sys.stderr)
        return 1

    # Envelope integrity is only a prerequisite; no semantic validators exist.
    print(
        f"PILOT gate {gate} cannot pass: semantic validator and "
        "genuine gate evidence are not implemented",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
