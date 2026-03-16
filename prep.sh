#!/usr/bin/env bash
set -euo pipefail

COMFYUI_PATH="/workspace/ComfyUI"
PERSIST_ROOT="/workspace"
MODELS_DIR="${PERSIST_ROOT}/models"
INPUT_DIR="${PERSIST_ROOT}/input"
OUTPUT_DIR="${PERSIST_ROOT}/output"
USER_DIR="${PERSIST_ROOT}/user"

mkdir -p "${MODELS_DIR}" "${INPUT_DIR}" "${OUTPUT_DIR}" "${USER_DIR}"
mkdir -p "${MODELS_DIR}/diffusion_models" \
         "${MODELS_DIR}/text_encoders" \
         "${MODELS_DIR}/clip_vision" \
         "${MODELS_DIR}/vae" \
         "${MODELS_DIR}/loras" \
         "${MODELS_DIR}/sam2"

download_if_missing() {
  local dst="$1"
  local url="$2"
  if [ ! -f "$dst" ]; then
    echo "Downloading $(basename "$dst")"
    aria2c -x 8 -s 8 -k 1M -d "$(dirname "$dst")" -o "$(basename "$dst")" "$url"
  else
    echo "Already exists: $dst"
  fi
}

# Wan2.2 Animate models
download_if_missing \
  "${MODELS_DIR}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

download_if_missing \
  "${MODELS_DIR}/vae/wan_2.1_vae.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"

download_if_missing \
  "${MODELS_DIR}/clip_vision/clip_vision_h.safetensors" \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"

download_if_missing \
  "${MODELS_DIR}/loras/WanAnimate_relight_lora_fp16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/LoRAs/Wan22_relight/WanAnimate_relight_lora_fp16.safetensors"

download_if_missing \
  "${MODELS_DIR}/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors"

download_if_missing \
  "${MODELS_DIR}/diffusion_models/Wan2_2-Animate-14B_fp8_e4m3fn_scaled_KJ.safetensors" \
  "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_e4m3fn_scaled_KJ.safetensors"

# SAM2 weights
download_if_missing \
  "${MODELS_DIR}/sam2/sam2_hiera_large.pt" \
  "https://huggingface.co/facebook/sam2-hiera-large/resolve/main/sam2_hiera_large.pt"

echo "=== Environment check ==="
python --version
python -c "import torch; print('torch:', torch.__version__); print('cuda available:', torch.cuda.is_available()); print('device count:', torch.cuda.device_count())"
