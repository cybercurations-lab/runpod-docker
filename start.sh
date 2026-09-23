#!/bin/bash
# RunPod ComfyUI startup script
# Mounts network volume if present, starts ComfyUI

set -e

COMFYUI_DIR="/workspace/ComfyUI"
VOLUME_MOUNT="/workspace-volume"

# If a network volume is mounted, symlink models from it
if [ -d "$VOLUME_MOUNT/models" ]; then
    echo "Network volume detected — using models from volume"
    # Link volume models into ComfyUI structure
    for dir in checkpoint clip unet vae lora controlnet diffusion_models text_encoders; do
        if [ -d "$VOLUME_MOUNT/models/$dir" ]; then
            ln -sf "$VOLUME_MOUNT/models/$dir"/* "$COMFYUI_DIR/models/$dir/" 2>/dev/null || true
        fi
    done
fi

# Ensure output directory exists
mkdir -p /workspace/outputs

# Start ComfyUI
cd "$COMFYUI_DIR"
exec python3 main.py \
    --listen 0.0.0.0 \
    --port "${COMFYUI_PORT:-8188}" \
    --output-directory /workspace/outputs \
    "$@"
