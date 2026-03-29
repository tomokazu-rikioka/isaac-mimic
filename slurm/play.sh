#!/bin/bash
#
# バッチジョブ: 学習済みポリシーの評価（ヘッドレス）
#
# 使い方:
#   cd ~/isaac-mimic && sbatch slurm/play.sh state 1000 /path/to/model.pth
#   cd ~/isaac-mimic && sbatch slurm/play.sh visuomotor 1000 /path/to/model.pth
#
#SBATCH --job-name=mimic-play
#SBATCH --gpus=1
#SBATCH --time=02:00:00
#SBATCH --output=logs/play_%j.out
#SBATCH --error=logs/play_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

POLICY_TYPE="${1:-state}"
NUM_DEMOS="${2:-1000}"
CHECKPOINT="${3:-}"
NUM_ROLLOUTS="${4:-50}"

# ポリシータイプに応じた設定
if [ "${POLICY_TYPE}" = "visuomotor" ]; then
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0"
else
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-v0"
fi

if [ -z "${CHECKPOINT}" ]; then
    echo "ERROR: Checkpoint path is required"
    echo "Usage: sbatch slurm/play.sh [state|visuomotor] [num_demos] [checkpoint_path] [num_rollouts]"
    exit 1
fi

echo "============================================"
echo "  Isaac Lab Mimic Policy Evaluation"
echo "============================================"
echo "  Node       : $(hostname)"
echo "  Policy Type: ${POLICY_TYPE}"
echo "  Task       : ${TASK}"
echo "  Checkpoint : ${CHECKPOINT}"
echo "  Rollouts   : ${NUM_ROLLOUTS}"
echo "  GPU        : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start      : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "mimic-play-${USER}-$$" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${PROJECT_DIR}/datasets:/workspace/isaac-mimic/datasets:ro" \
    -v "${PROJECT_DIR}/logs:/workspace/isaac-mimic/logs" \
    -v "${PROJECT_DIR}/scripts:/workspace/isaac-mimic/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_conda_env.sh && \
        source /workspace/isaac-mimic/scripts/env.sh && \
        cd \${ISAACLAB_DIR} && \
        ./isaaclab.sh -p scripts/imitation_learning/robomimic/play.py \
            --device cuda \
            --task ${TASK} \
            --num_rollouts ${NUM_ROLLOUTS} \
            --checkpoint /workspace/isaac-mimic/${CHECKPOINT}; \
        chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac-mimic/logs"

echo ""
echo "============================================"
echo "  Evaluation complete: $(date)"
echo "============================================"
echo ""
echo "  ログ転送（Mac側）:"
echo "    scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/"
echo "============================================"
