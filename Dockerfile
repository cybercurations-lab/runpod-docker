# ============================================================
# Wan 2.2 ComfyUI — RunPod Pod Image
# ============================================================
# Fixed 2026-09-23: base torch 2.4 too old for comfy_kitchen
# (list[int] unsupported in infer_schema). Upgrade torch via
# cu128 index first, then install ComfyUI.
#
# Build smoke tests ensure import failures break the BUILD,
# not the pod at runtime.
#
# Build: GitHub Actions workflow (model=wan22-comfyui)
# Image: cyber2000/wan22-comfyui:v2
# ============================================================

FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ARG MODEL=wan22

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV WORKSPACE=/workspace
ENV COMFYUI_PORT=8188

# ---- System deps ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    git wget curl ffmpeg libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---- Upgrade torch FIRST (base 2.4 too old for comfy_kitchen) ----
RUN pip install --no-cache-dir --upgrade torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 && \
    python3 -c "import torch; print('torch:', torch.__version__); assert torch.__version__ >= '2.7', 'torch too old'"

# ---- ComfyUI ----
WORKDIR /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN pip install --no-cache-dir -r requirements.txt

# ---- Custom Nodes ----
RUN git clone https://github.com/city96/ComfyUI-GGUF.git custom_nodes/ComfyUI-GGUF && \
    pip install --no-cache-dir -r custom_nodes/ComfyUI-GGUF/requirements.txt 2>/dev/null || true

# ---- SMOKE TEST: catch import failures at build time ----
RUN python3 -c "import comfy_kitchen; print('comfy_kitchen OK')" && \
    python3 -c "import comfy.quant_ops; print('comfy.quant_ops OK')" && \
    echo "=== Import smoke tests passed ==="

# ---- Model downloads (conditional on MODEL build arg) ----
RUN if [ "$MODEL" = "wan22-comfyui" ] || [ "$MODEL" = "wan22" ]; then \
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
      ls -la models/diffusion_models/ && \
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
