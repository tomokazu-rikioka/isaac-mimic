#!/bin/bash
#
# バッチジョブ: デモデータのアノテーション（ヘッドレス）
#
# 使い方:
#   cd ~/isaac-mimic && sbatch slurm/annotate.sh                         # State-based
#   cd ~/isaac-mimic && sbatch slurm/annotate.sh visuomotor              # Visuomotor
#
#SBATCH --job-name=mimic-annotate
#SBATCH --gpus=1
#SBATCH --time=01:00:00
#SBATCH --output=logs/annotate_%j.out
#SBATCH --error=logs/annotate_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

POLICY_TYPE="${1:-state}"

if [ "${POLICY_TYPE}" = "visuomotor" ]; then
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0"
    EXTRA_ARGS="--enable_cameras"
    OUTPUT_FILE="datasets/annotated_visuomotor.hdf5"
else
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Mimic-v0"
    EXTRA_ARGS=""
    OUTPUT_FILE="datasets/annotated_state.hdf5"
fi

INPUT_FILE="datasets/teleop_dataset.hdf5"

echo "============================================"
echo "  Isaac Lab Mimic Annotation"
echo "============================================"
echo "  Node       : $(hostname)"
echo "  Policy Type: ${POLICY_TYPE}"
echo "  Task       : ${TASK}"
echo "  Input      : ${INPUT_FILE}"
echo "  Output     : ${OUTPUT_FILE}"
echo "  GPU        : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start      : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "mimic-annotate-${USER}-$$" \
    --gpus "device=${CUDA_VISIBLE_DEVICES}" \
    -e ACCEPT_EULA=Y \
    -e PRIVACY_CONSENT=Y \
    -v "${PROJECT_DIR}/datasets:/workspace/isaac-mimic/datasets" \
    -v "${PROJECT_DIR}/logs:/workspace/isaac-mimic/logs" \
    -v "${PROJECT_DIR}/scripts:/workspace/isaac-mimic/scripts:ro" \
    --entrypoint bash \
    "${IMAGE}" \
    -c "source /isaac-sim/setup_conda_env.sh && \
        source /workspace/isaac-mimic/scripts/env.sh && \
        cd \${ISAACLAB_DIR} && \
        ./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/annotate_demos.py \
            --device cuda \
            --task ${TASK} \
            --auto \
            --input_file /workspace/isaac-mimic/${INPUT_FILE} \
            --output_file /workspace/isaac-mimic/${OUTPUT_FILE} \
            ${EXTRA_ARGS}; \
        chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac-mimic/datasets"

echo ""
echo "============================================"
echo "  Annotation complete: $(date)"
echo "============================================"
echo "  Output: ${OUTPUT_FILE}"
echo "============================================"
