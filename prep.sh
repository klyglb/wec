#!/usr/bin/env bash
set -euo pipefail

# RU: Активируем Python-окружение этого образа
# EN: Activate the Python environment provided by this image
source /venv/main/bin/activate

COMFYUI_PATH="/workspace/ComfyUI"
CUSTOM_NODES_DIR="${COMFYUI_PATH}/custom_nodes"
MODELS_DIR="${COMFYUI_PATH}/models"

INPUT_DIR="/workspace/input"
OUTPUT_DIR="/workspace/output"
USER_DIR="/workspace/user"

mkdir -p "${CUSTOM_NODES_DIR}"
mkdir -p "${INPUT_DIR}" "${OUTPUT_DIR}" "${USER_DIR}"
mkdir -p "${MODELS_DIR}/diffusion_models" \
         "${MODELS_DIR}/text_encoders" \
         "${MODELS_DIR}/clip_vision" \
         "${MODELS_DIR}/vae" \
         "${MODELS_DIR}/loras" \
         "${MODELS_DIR}/sam2"

log() {
  echo "[INFO] $*"
}

# RU: Определяем имя папки репозитория
# EN: Derive repository directory name from URL
repo_dir_name() {
  local repo_url="$1"
  basename "${repo_url}" .git
}

# RU: Клонируем или обновляем custom node
# EN: Clone or update a custom node repository
sync_node() {
  local repo_url="$1"
  local dir_name
  dir_name="$(repo_dir_name "${repo_url}")"
  local target_dir="${CUSTOM_NODES_DIR}/${dir_name}"

  if [[ -d "${target_dir}/.git" ]]; then
    log "Updating node: ${dir_name}"
    git -C "${target_dir}" fetch --all --tags --prune
    if ! git -C "${target_dir}" pull --ff-only; then
      # RU: Если fast-forward не прошёл, жёстко синхронизируемся с origin
      # EN: If fast-forward fails, hard reset to remote HEAD
      local default_branch
      default_branch="$(git -C "${target_dir}" remote show origin | sed -n '/HEAD branch/s/.*: //p')"
      [[ -n "${default_branch}" ]] || default_branch="main"
      git -C "${target_dir}" fetch origin "${default_branch}"
      git -C "${target_dir}" reset --hard "origin/${default_branch}"
      git -C "${target_dir}" submodule update --init --recursive
    fi
  else
    log "Cloning node: ${dir_name}"
    git clone --recursive "${repo_url}" "${target_dir}"
  fi

  # RU: Ставим Python-зависимости ноды, если они есть
  # EN: Install Python dependencies for the node if requirements.txt exists
  if [[ -f "${target_dir}/requirements.txt" ]]; then
    log "Installing requirements for: ${dir_name}"
    pip install --no-cache-dir -r "${target_dir}/requirements.txt"
  fi
}

# RU: Скачивание файла с fallback на aria2c / wget / curl
# EN: Download file with fallback to aria2c / wget / curl
download_if_missing() {
  local dst="$1"
  local url="$2"

  if [[ -s "${dst}" ]]; then
    log "Already exists: ${dst}"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"
  log "Downloading $(basename "${dst}")"

  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 8 -s 8 -k 1M -d "$(dirname "${dst}")" -o "$(basename "${dst}")" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${dst}" "${url}"
  elif command -v curl >/dev/null 2>&1; then
    curl -L --fail -o "${dst}" "${url}"
  else
    echo "[FATAL] aria2c/wget/curl not found" >&2
    exit 1
  fi
}

log "=== Installing Wan2.2 Animate required nodes ==="

# RU: Минимально нужные ноды для Wan2.2 Animate native/full workflow
# EN: Minimum required nodes for Wan2.2 Animate native/full workflow
sync_node "https://github.com/kijai/ComfyUI-KJNodes"
sync_node "https://github.com/Fannovel16/comfyui_controlnet_aux"

# RU: Часто полезно для расширенных workflow Kijai/Wan
# EN: Often useful for extended Kijai/Wan workflows
sync_node "https://github.com/kijai/ComfyUI-WanVideoWrapper"
sync_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"

log "=== Downloading Wan2.2 Animate models ==="

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

download_if_missing \
  "${MODELS_DIR}/sam2/sam2_hiera_large.pt" \
  "https://huggingface.co/facebook/sam2-hiera-large/resolve/main/sam2_hiera_large.pt"

log "=== Environment check ==="
python --version
python -c "import torch; print('torch:', torch.__version__); print('cuda available:', torch.cuda.is_available()); print('device count:', torch.cuda.device_count())"

log "=== Installed custom nodes ==="
find "${CUSTOM_NODES_DIR}" -maxdepth 1 -mindepth 1 -type d | sort || true

log "=== Provisioning completed successfully ==="
