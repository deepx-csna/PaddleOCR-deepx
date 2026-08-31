#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

ARCH=$(uname -m)

echo "========================================"
echo "NOTE: APT dependencies must be installed manually:"
echo "sudo apt-get update"
if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    echo "sudo apt-get install -y python3-venv python3-pip cmake build-essential libgl1-mesa-glx python3-pyqt5"
    VENV_OPTS="--system-site-packages"
else
    echo "sudo apt-get install -y python3-venv python3-pip cmake build-essential libgl1-mesa-glx"
    VENV_OPTS=""
fi
echo "========================================"

echo "========================================"
echo "Setting up Python Virtual Environment..."
echo "========================================"
cd "$REPO_ROOT"
if [ ! -d ".venv" ]; then
    python3 -m venv $VENV_OPTS .venv
    echo "Virtual environment created at .venv"
else
    echo "Virtual environment already exists."
fi

echo "========================================"
echo "Installing Python Requirements..."
echo "========================================"
source .venv/bin/activate
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        # Exclude PyQt5 on ARM since we use the system package (avoids build errors)
        grep -v -i "^pyqt5" requirements.txt > .requirements_arm.txt
        pip install -r .requirements_arm.txt
        rm -f .requirements_arm.txt
    else
        pip install -r requirements.txt
    fi
else
    echo "No requirements.txt found."
fi

echo "========================================"
echo "Installing DXRT Python bindings (dx_engine)..."
echo "========================================"
# The dx_engine wheels ship with the libdxrt-bin package (deb install) or with the
# dx_rt source tree (source build, common on aarch64 boards such as Radxa Pi).
# The wheel must match this interpreter and this architecture.
PY_TAG="cp$(python3 -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')"
DXRT_WHEEL_GLOB="dx_engine-*-${PY_TAG}-*${ARCH}.whl"
DXRT_WHEEL=$(ls /usr/share/libdxrt-bin/python/${DXRT_WHEEL_GLOB} \
                "${DXRT_DIR:-$HOME/dx_rt}"/python_package/${DXRT_WHEEL_GLOB} \
                2>/dev/null | head -n 1)

if python3 -c 'import dx_engine' 2>/dev/null; then
    echo "dx_engine is already importable in this environment. Skipping."
elif [ -n "${DXRT_WHEEL}" ]; then
    # Do not abort the whole setup (set -e) if this one install fails.
    pip install "${DXRT_WHEEL}" || echo "Warning: failed to install $(basename "${DXRT_WHEEL}")."
else
    echo "========================================"
    echo "NOTE: no ${DXRT_WHEEL_GLOB} found. Install dx_engine manually:"
    echo "pip install /usr/share/libdxrt-bin/python/${DXRT_WHEEL_GLOB}"
    echo "  (or from a dx_rt source tree: \$DXRT_DIR/python_package)"
    echo "Demos with a Python NPU backend will not run without dx_engine."
    echo "========================================"
fi

echo "Environment setup complete."
