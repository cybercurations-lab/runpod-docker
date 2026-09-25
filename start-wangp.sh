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

# ---- SSH provisioning ----
# Generate host keys if missing (image ships openssh-server but NO host keys —
# sshd refuses to start without them; same 2026-09-25 bug fixed in start.sh).
if ! ls /etc/ssh/ssh_host_*key >/dev/null 2>&1; then
    echo "Generating SSH host keys..."
    ssh-keygen -A
fi

# Install authorized_keys from PUBLIC_KEY env (RunPod sets it at pod create
# when startSsh=true; PATCH-set keys require a restart).
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh && chmod 700 /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "authorized_keys installed from PUBLIC_KEY"

    # Start sshd and supervise it (restart if the daemon dies).
    /usr/sbin/sshd
    if [ $? -eq 0 ]; then
        echo "sshd started on :22"
    else
        echo "WARNING: sshd failed to start (exit $?) " >&2
    fi
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

# Start WanGP web UI (binds to 0.0.0.0:7860)
cd "$WANGP_DIR"
exec "$PY" wgp.py \
    --listen \
    --server-port 7860 \
    "$@"
