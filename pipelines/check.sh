#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
PYTHON="${PYTHON:-.venv/bin/python}"

"$PYTHON" automation/check.py
"$PYTHON" -m unittest discover -s tests -p 'test_*.py' -v
