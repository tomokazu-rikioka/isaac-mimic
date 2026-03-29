#!/bin/bash
#
# バッチジョブ: Isaac Lab Mimic / SkillGen によるデータ生成（ヘッドレス）
#
# 使い方:
#   cd ~/isaac-mimic && sbatch slurm/generate.sh                    # State 1000デモ
#   cd ~/isaac-mimic && sbatch slurm/generate.sh state 100          # State 100デモ
#   cd ~/isaac-mimic && sbatch slurm/generate.sh visuomotor 1000    # Visuomotor 1000デモ
#
#SBATCH --job-name=mimic-gen
#SBATCH --gpus=1
#SBATCH --time=12:00:00
#SBATCH --output=logs/generate_%j.out
#SBATCH --error=logs/generate_%j.err

set -euo pipefail

PROJECT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "${PROJECT_DIR}/scripts/env.sh"

mkdir -p "${PROJECT_DIR}/logs"

POLICY_TYPE="${1:-state}"
NUM_TRIALS="${2:-1000}"
NUM_ENVS="${3:-5}"

# ポリシータイプに応じた設定
if [ "${POLICY_TYPE}" = "visuomotor" ]; then
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0"
    EXTRA_ARGS="--enable_cameras"
    OUTPUT_FILE="datasets/generated_visuomotor_${NUM_TRIALS}.hdf5"
else
    TASK="Isaac-Stack-Cube-Franka-IK-Rel-Skillgen-v0"
    EXTRA_ARGS="--use_skillgen"
    OUTPUT_FILE="datasets/generated_state_${NUM_TRIALS}.hdf5"
fi

INPUT_FILE="datasets/annotated_dataset_skillgen.hdf5"

echo "============================================"
echo "  Isaac Lab Mimic Data Generation"
echo "============================================"
echo "  Node       : $(hostname)"
echo "  Policy Type: ${POLICY_TYPE}"
echo "  Task       : ${TASK}"
echo "  Trials     : ${NUM_TRIALS}"
echo "  Envs       : ${NUM_ENVS}"
echo "  Input      : ${INPUT_FILE}"
echo "  Output     : ${OUTPUT_FILE}"
echo "  GPU        : CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-not set}"
echo "  Start      : $(date)"
echo "============================================"

HOST_UID=$(id -u)
HOST_GID=$(id -g)

docker run --rm \
    --name "mimic-gen-${USER}-$$" \
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
        ./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/generate_dataset.py \
            --device cuda \
            --headless \
            --num_envs ${NUM_ENVS} \
            --generation_num_trials ${NUM_TRIALS} \
            --input_file /workspace/isaac-mimic/${INPUT_FILE} \
            --output_file /workspace/isaac-mimic/${OUTPUT_FILE} \
            --task ${TASK} \
            ${EXTRA_ARGS}; \
        chown -R ${HOST_UID}:${HOST_GID} /workspace/isaac-mimic/datasets /workspace/isaac-mimic/logs"

echo ""
echo "============================================"
echo "  Generation complete: $(date)"
echo "============================================"
echo "  Output: ${OUTPUT_FILE}"
echo ""
echo "  次のステップ:"
echo "    cd ~/isaac-mimic && sbatch slurm/train.sh ${POLICY_TYPE} ${NUM_TRIALS}"
echo "============================================"
