#!/usr/bin/env bash
set -e

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"
src_dir="$(realpath "${this_dir}/..")"

venv="${src_dir}/.venv"
if [[ -d "${venv}" ]]; then
    source "${venv}/bin/activate"
fi

python_files=("${src_dir}/"*.py "${src_dir}/glow_speak" "${src_dir}/larynx"  "${src_dir}/TTS")

# -----------------------------------------------------------------------------

# flake8 "${python_files[@]}"
# pylint "${python_files[@]}"
# mypy "${python_files[@]}"
black --check "${python_files[@]}"
isort --check-only "${python_files[@]}"

# -----------------------------------------------------------------------------

echo "OK"
