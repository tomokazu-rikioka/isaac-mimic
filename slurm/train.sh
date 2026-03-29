#!/bin/bash
#
# バッチジョブ: Robomimic BC 学習（ヘッドレス）
#
# 使い方:
#   cd ~/isaac-mimic && sbatch slurm/train.sh                    # State 1000デモ
#   cd ~/isaac-mimic && sbatch slurm/train.sh state 100          # State 100デモ
#   cd ~/isaac-mimic && sbatch slurm/train.sh visuomotor 1000    # Visuomotor 1000デモ
#   cd ~/isaac-mimic && sbatch slurm/train.sh state 1000 dr      # State + Domain Randomization
#
#SBATCH --job-name=mimic-train
#SBATCH --gpus=1
#SBATCH --time=24:00:00
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

POLICY_TYPE="${1:-state}"
NUM_DEMOS="${2:-1000}"
DR="${3:-}"

# ポリシータイプに応じた設定
if [ "${POLICY_TYPE}" = "visuomotor" ]; then
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0"
    DATASET="datasets/generated_visuomotor_${NUM_DEMOS}.hdf5"
else
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-v0"
    DATASET="datasets/generated_state_${NUM_DEMOS}.hdf5"
fi

# 実験名
EXPERIMENT_NAME="${POLICY_TYPE}_${NUM_DEMOS}"
[ -n "${DR}" ] && EXPERIMENT_NAME="${EXPERIMENT_NAME}_dr"

echo "============================================"
echo "  Isaac Lab Mimic BC Training"
echo "============================================"
echo "  Node       : $(hostname)"
echo "  Policy Type: ${POLICY_TYPE}"
echo "  Task       : ${TASK}"
echo "  Dataset    : ${DATASET}"
echo "  Demos      : ${NUM_DEMOS}"
echo "  DR         : ${DR:-none}"
echo "  Experiment : ${EXPERIMENT_NAME}"
echo "  GPU        : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start      : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "mimic-train-${USER}-$$" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${PROJECT_DIR}/datasets:/workspace/isaac-mimic/datasets:ro" \
    -v "${PROJECT_DIR}/logs:/workspace/isaac-mimic/logs" \
    -v "${PROJECT_DIR}/configs:/workspace/isaac-mimic/configs:ro" \
    -v "${PROJECT_DIR}/scripts:/workspace/isaac-mimic/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_conda_env.sh && \
        source /workspace/isaac-mimic/scripts/env.sh && \
        cd \${ISAACLAB_DIR} && \
        ./isaaclab.sh -p scripts/imitation_learning/robomimic/train.py \
            --task ${TASK} \
            --algo bc \
            --normalize_training_actions \
            --dataset /workspace/isaac-mimic/${DATASET}; \
        chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac-mimic/logs"

echo ""
echo "============================================"
echo "  Training complete: $(date)"
echo "============================================"
echo "  Experiment: ${EXPERIMENT_NAME}"
echo ""
echo "  次のステップ:"
echo "    cd ~/isaac-mimic && sbatch slurm/play.sh ${POLICY_TYPE} ${NUM_DEMOS}"
echo ""
echo "  ログ転送（Mac側）:"
echo "    scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/"
echo "============================================"
