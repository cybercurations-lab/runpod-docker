#!/bin/bash
# WanGP startup script for RunPod
# Launch: python wgp.py --listen --server-port 7860

set -e

WANGP_DIR="/workspace/Wan2GP"
VOLUME_MOUNT="/workspace-volume"

# If network volume attached, use it for models
if [ -d "$VOLUME_MOUNT/models" ]; then
    echo "Network volume detected — using models from volume"
    mkdir -p "$WANGP_DIR/models"
    ln -sf "$VOLUME_MOUNT/models"/* "$WANGP_DIR/models/" 2>/dev/null || true
fi

# Start WanGP web UI (binds to 0.0.0.0:7860)
cd "$WANGP_DIR"
exec python3 wgp.py \
    --listen \
    --server-port 7860 \
    "$@"
