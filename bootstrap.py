#!/usr/bin/env python3
"""Prepare the Python environment once, then run the PS3 worker directly."""

from pathlib import Path
import os
import platform
import subprocess
import sys
import venv


ROOT = Path(os.environ.get("PS3RPD_SOURCE_DIR", Path(__file__).resolve().parent))
DATA_ROOT = Path(os.environ.get("PS3RPD_DATA_DIR", ROOT))
VENV_DIR = DATA_ROOT / ".venv"
DEPENDENCIES = ("beautifulsoup4", "networkscan", "pypresence", "requests", "urllib3<2")


def python_in_venv():
    binary = "python.exe" if platform.system() == "Windows" else "python"
    directory = "Scripts" if platform.system() == "Windows" else "bin"
    return VENV_DIR / directory / binary


def ensure_environment():
    interpreter = python_in_venv()
    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    if not interpreter.exists():
        print(f"Creating virtual environment in {VENV_DIR}...", flush=True)
        venv.create(VENV_DIR, with_pip=True)
    subprocess.check_call(
        [str(interpreter), "-m", "pip", "install", "--upgrade", *DEPENDENCIES]
    )
    return interpreter


def main():
    if sys.version_info < (3, 9):
        raise SystemExit("Python 3.9 or newer is required.")
    interpreter = ensure_environment()
    worker = ROOT / "PS3RPD.py"
    print("Starting PS3RPD worker...", flush=True)
    os.execv(str(interpreter), [str(interpreter), str(worker)])


if __name__ == "__main__":
    main()
