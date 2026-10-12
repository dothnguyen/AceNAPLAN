"""Validated task mutation for the primary Lead (not specialist agents)."""
import argparse
import json
from pathlib import Path

from core import GateError, phase_of, read_board, ready_tasks, snapshot, upsert_task


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    commands = parser.add_subparsers(dest="command", required=True)
    task = commands.add_parser("task")
    task.add_argument("--phase", required=True)
    task.add_argument("--input", type=Path, required=True)
    ready = commands.add_parser("ready")
    ready.add_argument("--phase", required=True)
    commands.add_parser("snapshot")
    args = parser.parse_args()
    try:
        if args.command == "snapshot":
            print(json.dumps(snapshot(args.root.resolve()), indent=2))
        else:
            board = read_board(args.root)
            if args.command == "task":
                upsert_task(args.root, board, args.phase, json.loads(args.input.read_text(encoding="utf-8")))
                print("Task persisted")
            else:
                print(json.dumps(ready_tasks(phase_of(board, args.phase)), indent=2))
    except (GateError, OSError, ValueError) as error:
        parser.exit(2, f"Blocked: {error}\n")


if __name__ == "__main__":
    main()
