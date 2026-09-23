#!/bin/bash
# WanGP startup script for RunPod
# Uses pip's interpreter (resolved at build time), NOT system python3 —
# RunPod base images may have python3 pointing to a different version
# than pip targets (root cause of "No module named 'torch'").

set -e

WANGP_DIR="/workspace/Wan2GP"
VOLUME_MOUNT="/workspace-volume"

# Resolve interpreter: build-time diagnostic file, fallback to python3
PY=$(cat /workspace/wangp-python.txt 2>/dev/null || echo "python3")
echo "Starting WanGP with: $PY ($($PY --version 2>&1))"

# If network volume attached, use it for models
if [ -d "$VOLUME_MOUNT/models" ]; then
    echo "Network volume detected — using models from volume"
    mkdir -p "$WANGP_DIR/models"
    ln -sf "$VOLUME_MOUNT/models"/* "$WANGP_DIR/models/" 2>/dev/null || true
fi

# Start WanGP web UI (binds to 0.0.0.0:7860)
cd "$WANGP_DIR"
exec "$PY" wgp.py \
    --listen \
    --server-port 7860 \
    "$@"
