"""Entry point for the pilot's opaque checks.

Gate-specific semantic validators are not installed yet. An evidence envelope
alone cannot prove a check passed, so every supported gate currently fails.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence


# Names are fixed by the approved pilot check contract. Do not infer new gates
# from an evidence envelope or a caller-supplied path.
OPAQUE_GATES = frozenset({
    "content",
    "browser",
    "android_integration",
    "educator",
    "physical_phone",
    "physical_tablet",
    "release_candidate",
})


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate an opaque pilot gate")
    parser.add_argument("--gate", required=True, choices=sorted(OPAQUE_GATES), action="append")
    arguments = parser.parse_args(argv)
    if len(arguments.gate) != 1:
        parser.error("--gate must be supplied exactly once")
    gate = arguments.gate[0]

    # No semantic validator has been approved/implemented for these gates.
    # In particular, a caller cannot turn a structurally valid envelope into
    # a pass by supplying it as an extra argument.
    print(
        f"PILOT gate {gate} cannot pass: semantic validator and "
        "genuine gate evidence are not implemented",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
