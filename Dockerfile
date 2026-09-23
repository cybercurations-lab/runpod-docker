# ============================================================
# RunPod Docker Images — Multi-model support
# ============================================================
# Build via GitHub Actions (cloud, no local disk impact):
#   - Push this directory to a GitHub repo
#   - Set secrets: DOCKERHUB_USERNAME, DOCKERHUB_TOKEN
#   - Run workflow with desired model
#
# Or build locally if you have 50GB+ free disk:
#   docker build --platform linux/amd64 -t cyber2000/MODEL:tag .
#
# Image variants (select via build arg MODEL):
#   base      — ComfyUI only, no models (~5GB)
#   wan22     — ComfyUI + Wan 2.2 Q5_K_M (~22GB)
#
# For other models (Flux, SDXL), create separate Dockerfiles
# that extend the base image.
# ============================================================

FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ARG MODEL=wan22

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV WORKSPACE=/workspace
ENV COMFYUI_PORT=8188

# ---- System deps (minimal) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- ComfyUI ----
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
WORKDIR /workspace/ComfyUI

RUN pip install --no-cache-dir -r requirements.txt

# ---- Custom Nodes ----
RUN git clone https://github.com/city96/ComfyUI-GGUF.git custom_nodes/ComfyUI-GGUF && \
    pip install --no-cache-dir -r custom_nodes/ComfyUI-GGUF/requirements.txt 2>/dev/null || true

# ---- Model downloads (conditional on MODEL build arg) ----
RUN if [ "$MODEL" = "wan22" ]; then \
      echo "=== Downloading Wan 2.2 GGUF models ===" && \
      mkdir -p models/diffusion_models && \
      wget --no-check-certificate -q \
        "https://huggingface.co/city96/Wan2.1-I2V-14B-480P-GGUF/resolve/main/wan2.1-i2v-14b-480p-q5_k_m.gguf" \
        -O models/diffusion_models/wan2.1-i2v-14b-480p-q5_k_m.gguf && \
      echo "480p model downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/city96/Wan2.1-I2V-14B-720P-GGUF/resolve/main/wan2.1-i2v-14b-720p-q5_k_m.gguf" \
        -O models/diffusion_models/wan2.1-i2v-14b-720p-q5_k_m.gguf && \
      echo "720p model downloaded" && \
      echo "=== Models downloaded ==="; \
    else \
      echo "=== Base image — no models ===" && \
      mkdir -p models/diffusion_models models/checkpoints models/text_encoders models/vae; \
    fi

# ---- Output dir ----
RUN mkdir -p /workspace/outputs /workspace/workflows

# ---- Startup script ----
COPY start.sh /workspace/start.sh
RUN chmod +x /workspace/start.sh

EXPOSE 8188
WORKDIR /workspace/ComfyUI
ENTRYPOINT ["/workspace/start.sh"]
