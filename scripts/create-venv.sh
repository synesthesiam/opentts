#!/usr/bin/env bash
set -e

: "${PIP_INSTALL=install}"
: "${PIP_VERSION=pip}"

# Directory of *this* script
this_dir="$( cd "$( dirname "$0" )" && pwd )"
src_dir="$(realpath "${this_dir}/..")"

# -----------------------------------------------------------------------------

venv="${src_dir}/.venv"

# -----------------------------------------------------------------------------

: "${PYTHON=python3}"

python_version="$(${PYTHON} --version)"

# Create virtual environment
echo "Creating virtual environment at ${venv} (${python_version})"
rm -rf "${venv}"
"${PYTHON}" -m venv "${venv}"
source "${venv}/bin/activate"

# Install Python dependencies
echo "Installing Python dependencies"
pip3 ${PIP_INSTALL} --upgrade "${PIP_VERSION}"
pip3 ${PIP_INSTALL} --upgrade wheel setuptools

if [[ -f requirements.txt ]]; then
    pip3 ${PIP_INSTALL} -r requirements.txt
fi

# Development dependencies
if [[ -f requirements_dev.txt ]]; then
    pip3 ${PIP_INSTALL} -r requirements_dev.txt || echo "Failed to install development dependencies" >&2
fi

# -----------------------------------------------------------------------------

echo "OK"
