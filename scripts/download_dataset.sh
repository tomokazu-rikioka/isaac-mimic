#!/bin/bash
#
# 事前アノテーション済みデータセットのダウンロード
#
# NVIDIA が提供する Franka Stack Cube の SkillGen 用データセットを取得する。
# テレオペなしでデータ生成を開始するために使用。
#
# 使い方:
#   cd ~/isaac-mimic && bash scripts/download_dataset.sh
#

set -euo pipefail

DATASET_DIR="$(cd "$(dirname "$0")/.." && pwd)/datasets"
mkdir -p "${DATASET_DIR}"

SKILLGEN_URL="https://omniverse-content-production.s3-us-west-2.amazonaws.com/Assets/Isaac/5.0/Isaac/IsaacLab/Mimic/franka_stack_datasets/annotated_dataset_skillgen.hdf5"
SKILLGEN_FILE="${DATASET_DIR}/annotated_dataset_skillgen.hdf5"

echo "============================================"
echo "  Dataset Download"
echo "============================================"

# SkillGen 用アノテーション済みデータセット
if [ -f "${SKILLGEN_FILE}" ]; then
    echo "  [SKIP] ${SKILLGEN_FILE} already exists"
else
    echo "  [1/1] Downloading SkillGen annotated dataset..."
    echo "    URL: ${SKILLGEN_URL}"
    wget -O "${SKILLGEN_FILE}" "${SKILLGEN_URL}"
    echo "    Saved: ${SKILLGEN_FILE}"
fi

# ダウンロードしたファイルの確認
echo ""
echo "  Downloaded datasets:"
ls -lh "${DATASET_DIR}"/*.hdf5 2>/dev/null || echo "  (no HDF5 files found)"

echo ""
echo "============================================"
echo "  Download complete!"
echo "============================================"
echo ""
echo "  次のステップ:"
echo "    cd ~/isaac-mimic && sbatch slurm/generate.sh"
echo "============================================"
