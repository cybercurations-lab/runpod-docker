#!/bin/bash
# RunPod ComfyUI startup script
# 1. Mounts network volume models if present
# 2. Provisions SSH (host keys + authorized_keys from PUBLIC_KEY)
# 3. Starts sshd persistently (supervised loop)
# 4. Starts ComfyUI in foreground

COMFYUI_DIR="/workspace/ComfyUI"
VOLUME_MOUNT="/workspace-volume"

# If a network volume is mounted, symlink models from it
if [ -d "$VOLUME_MOUNT/models" ]; then
    echo "Network volume detected — using models from volume"
    for dir in checkpoint clip unet vae lora controlnet diffusion_models text_encoders; do
        if [ -d "$VOLUME_MOUNT/models/$dir" ]; then
            ln -sf "$VOLUME_MOUNT/models/$dir"/* "$COMFYUI_DIR/models/$dir/" 2>/dev/null || true
        fi
    done
fi

# Ensure output directory exists
mkdir -p /workspace/outputs

# ---- SSH provisioning ----
# Generate host keys if missing (image has openssh-server but NO host keys —
# sshd will refuse to start without them; this was the 2026-09-25 bug).
if ! ls /etc/ssh/ssh_host_*key >/dev/null 2>&1; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Install authorized_keys from PUBLIC_KEY env (RunPod sets it when the pod
# was created with startSsh, or when patched via API).
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "authorized_keys installed from PUBLIC_KEY"

    # Start sshd and supervise it: if it exits, restart after a beat.
    # (sshd daemonizes itself, so a plain start is fine; the loop guards
    # against the daemon dying when the host key dir was read-only etc.)
    /usr/sbin/sshd
    if [ $? -eq 0 ]; then
        echo "sshd started on :22"
    else
        echo "WARNING: sshd failed to start (exit $?)" >&2
    fi
    # Supervisor loop in background — only if sshd is not running
    (
        while true; do
            if ! pgrep -x sshd >/dev/null 2>&1; then
                echo "$(date -Is) sshd not running — restarting" >> /workspace/sshd-supervisor.log
                /usr/sbin/sshd 2>> /workspace/sshd-supervisor.log
            fi
            sleep 30
        done
    ) &
else
    echo "WARNING: PUBLIC_KEY not set — SSH access will NOT work" >&2
fi

# ---- LTX-2.3 checkpoint: pull from VPS1 relay (image bakes Gemma only) ----
# Non-blocking: start ComfyUI now, download 46GB in background. On reboot the
# file persists on the container disk, so this only downloads once per pod.
LTX_CKPT="$COMFYUI_DIR/models/checkpoints/ltx-2.3-22b-distilled.safetensors"
LTX_RELAY_URL="${LTX_RELAY_URL:-https://56f2827c89d6630a40c0.agent37.app/ltx-2.3-22b-distilled.safetensors}"
if [ ! -f "$LTX_CKPT" ] || [ "$(stat -c %s "$LTX_CKPT" 2>/dev/null || echo 0)" -lt 46000000000 ]; then
    echo "LTX checkpoint missing/incomplete — pulling from relay in background"
    mkdir -p "$COMFYUI_DIR/models/checkpoints"
    (
        wget -c -q --timeout=60 --tries=10 "$LTX_RELAY_URL" -O "$LTX_CKPT.tmp" \
            && mv "$LTX_CKPT.tmp" "$LTX_CKPT" \
            && echo "$(date -Is) LTX checkpoint downloaded" >> /workspace/ltx-download.log \
            || echo "$(date -Is) LTX checkpoint download FAILED" >> /workspace/ltx-download.log
    ) &
else
    echo "LTX checkpoint already present ($(stat -c %s "$LTX_CKPT") bytes)"
fi

# Start ComfyUI
cd "$COMFYUI_DIR"
exec python3 main.py \
    --listen 0.0.0.0 \
    --port "${COMFYUI_PORT:-8188}" \
    --output-directory /workspace/outputs \
    "$@"
