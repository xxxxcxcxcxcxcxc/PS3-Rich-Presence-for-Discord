#!/usr/bin/env python3
"""Cross-platform launcher for the original PS3 Rich Presence worker."""

import shutil
import subprocess
import sys


def main():
    if shutil.which("uv") is None:
        print("uv is required. Install it from https://docs.astral.sh/uv/getting-started/installation/")
        raise SystemExit(1)
    subprocess.check_call(["uv", "run", "--script", "PS3RPD.py"])


if __name__ == "__main__":
    main()
