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
    git wget curl ffmpeg libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 \
    openssh-server && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/sshd && \
    echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

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
    elif [ "$MODEL" = "wan-a14b" ]; then \
      echo "=== Downloading Wan 2.2 I2V A14B (Q5_K_M experts + umt5 + VAE) ===" && \
      mkdir -p models/diffusion_models models/text_encoders models/vae && \
      wget --no-check-certificate -q \
        "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/HighNoise/Wan2.2-I2V-A14B-HighNoise-Q5_K_M.gguf" \
        -O models/diffusion_models/Wan2.2-I2V-A14B-HighNoise-Q5_K_M.gguf && \
      echo "HighNoise downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/QuantStack/Wan2.2-I2V-A14B-GGUF/resolve/main/LowNoise/Wan2.2-I2V-A14B-LowNoise-Q5_K_M.gguf" \
        -O models/diffusion_models/Wan2.2-I2V-A14B-LowNoise-Q5_K_M.gguf && \
      echo "LowNoise downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
        -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors && \
      echo "umt5 downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
        -O models/vae/wan_2.1_vae.safetensors && \
      echo "VAE downloaded" && \
      ls -la models/diffusion_models/ models/text_encoders/ models/vae/ && \
      echo "=== Wan A14B models ready ==="; \
    elif [ "$MODEL" = "hunyuan" ]; then \
      echo "=== Downloading HunyuanVideo (Q8_0 + T5 + CLIP-L + VAE) ===" && \
      mkdir -p models/diffusion_models models/text_encoders models/vae && \
      wget --no-check-certificate -q \
        "https://huggingface.co/city96/HunyuanVideo-gguf/resolve/main/hunyuan-video-t2v-720p-Q8_0.gguf" \
        -O models/diffusion_models/hunyuan-video-t2v-720p-Q8_0.gguf && \
      echo "Q8_0 downloaded" && \
      for i in 1 2 3 4; do \
        wget --no-check-certificate -q \
          "https://huggingface.co/hunyuanvideo-community/HunyuanVideo/resolve/main/text_encoder/model-0000${i}-of-00004.safetensors" \
          -O models/text_encoders/hunyuan_t5_model-0000${i}-of-00004.safetensors && \
          echo "T5 shard $i downloaded"; \
      done && \
      wget --no-check-certificate -q \
        "https://huggingface.co/hunyuanvideo-community/HunyuanVideo/resolve/main/text_encoder_2/model.safetensors" \
        -O models/text_encoders/hunyuan_clip_l.safetensors && \
      echo "CLIP-L downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/hunyuanvideo-community/HunyuanVideo/resolve/main/vae/diffusion_pytorch_model.safetensors" \
        -O models/vae/hunyuan_vae.safetensors && \
      echo "VAE downloaded" && \
      ls -la models/diffusion_models/ models/text_encoders/ models/vae/ && \
      echo "=== Hunyuan models ready ==="; \
    elif [ "$MODEL" = "ltx23" ]; then \
      echo "=== Downloading LTX-2.3 (fp8 checkpoint + Gemma 12B) ===" && \
      mkdir -p models/checkpoints models/text_encoders && \
      wget --no-check-certificate -q \
        "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors" \
        -O models/checkpoints/ltx-2.3-22b-distilled-fp8.safetensors && \
      echo "LTX-2.3 checkpoint downloaded" && \
      wget --no-check-certificate -q \
        "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors" \
        -O models/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors && \
      echo "Gemma 12B downloaded" && \
      ls -la models/checkpoints/ models/text_encoders/ && \
      echo "=== LTX-2.3 models ready ==="; \
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
