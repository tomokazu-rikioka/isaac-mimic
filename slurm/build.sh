#!/bin/bash
#
# バッチジョブ: Docker イメージの pull & build
#
# 使い方:
#   cd ~/isaac-mimic && sbatch slurm/build.sh
#
#SBATCH --job-name=mimic-build
#SBATCH --gpus=1
#SBATCH --time=02:00:00
#SBATCH --output=logs/build_%j.out
#SBATCH --error=logs/build_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

echo "============================================"
echo "  Isaac Lab Mimic Docker Build"
echo "============================================"
echo "  Node  : $(hostname)"
echo "  GPU   : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start : $(date)"
echo "============================================"

# --- Docker イメージ pull ---
echo ""
echo "[1/2] Pulling base Isaac Lab image (20-40 min)..."
echo "  Image: ${BASE_IMAGE}"
docker pull "${BASE_IMAGE}"

# --- Docker イメージ build ---
echo ""
echo "[2/2] Building Isaac Lab Mimic image..."
cd "${PROJECT_DIR}"
docker compose -f docker/docker-compose.yml build

echo ""
echo "============================================"
echo "  Build complete: $(date)"
echo "============================================"
echo ""
echo "  確認:"
echo "    docker images | grep isaac-lab-mimic"
echo ""
echo "  次のステップ:"
echo "    cd ~/isaac-mimic && bash scripts/download_dataset.sh"
echo "    cd ~/isaac-mimic && sbatch slurm/generate.sh"
echo "============================================"
