#!/usr/bin/env python3
"""Opt-in live repro; requires two same-app windows on different displays.

Usage: script --cli PATH --target-window ID --other-window ID --neutral-window ID
Temporarily changes focus, preserves windows/assignments, and restores focus.
"""
import argparse
import json
import statistics
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--cli", required=True)
parser.add_argument("--target-window", required=True)
parser.add_argument("--other-window", required=True)
parser.add_argument("--neutral-window", required=True)
parser.add_argument("--iterations", type=int, default=5)
args = parser.parse_args()
if not 1 <= args.iterations <= 50:
    parser.error("--iterations must be between 1 and 50")


def cli(*command):
    result = subprocess.run([args.cli, *command], capture_output=True, text=True, timeout=5)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def context():
    return cli("list-workspaces", "--focused")


def run():
    rows = cli("list-windows", "--all", "--format",
               "%{window-id}|%{workspace}|%{monitor-name}|%{app-bundle-id}")
    windows = dict((parts[0], parts[1:]) for parts in (line.split("|") for line in rows.splitlines()))
    target = windows[args.target_window]
    other = windows[args.other_window]
    neutral = windows[args.neutral_window]
    if target[2] != other[2] or target[1] == other[1] or target[0] == other[0]:
        raise ValueError("Target/other must be same-app windows on different workspaces and displays")
    if neutral[2] == target[2]:
        raise ValueError("Neutral window must belong to a different application")
    original = context()
    original_window = cli("list-windows", "--workspace", original, "--format", "%{window-id}")
    if original_window:
        original_window = cli("list-windows", "--focused", "--format", "%{window-id}")
    measurements = []
    failures = 0
    try:
        for iteration in range(args.iterations):
            cli("focus", "--window-id", args.other_window)
            time.sleep(.15)
            cli("focus", "--window-id", args.neutral_window)
            time.sleep(.15)
            start = time.monotonic()
            cli("workspace", target[0])
            completion_ms = round((time.monotonic() - start) * 1000, 1)
            samples = []
            for _ in range(10):
                samples.append(context())
                time.sleep(.05)
            success = all(workspace == target[0] for workspace in samples)
            failures += not success
            measurements.append(completion_ms)
            print(json.dumps(dict(iteration=iteration, expected=target[0],
                                  samples=samples, completion_ms=completion_ms, passed=success)), flush=True)
    finally:
        if original_window:
            cli("focus", "--window-id", original_window)
        else:
            cli("workspace", original)
    print(json.dumps(dict(failures=failures, iterations=args.iterations,
                          median_completion_ms=statistics.median(measurements))))
    assert failures == 0, "Native workspace switching adopted another same-app window"


if __name__ == "__main__":
    run()
