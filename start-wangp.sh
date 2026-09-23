#!/bin/bash
# WanGP startup script for RunPod

set -e

WANGP_DIR="/workspace/Wan2GP"
VOLUME_MOUNT="/workspace-volume"

# If network volume attached, use it for models
if [ -d "$VOLUME_MOUNT/models" ]; then
    echo "Network volume detected — using models from volume"
    mkdir -p "$WANGP_DIR/models"
    ln -sf "$VOLUME_MOUNT/models"/* "$WANGP_DIR/models/" 2>/dev/null || true
fi

# Start WanGP web UI
cd "$WANGP_DIR"
exec python3 app.py \
    --listen 0.0.0.0 \
    --port 7860 \
    "$@"
