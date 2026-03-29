#!/bin/bash
#
# 12条件の実験を一括実行するスクリプト
#
# データ生成は事前に完了している前提で、学習→評価を全条件で実行する。
#
# 使い方:
#   cd ~/isaac-mimic && bash scripts/run_experiments.sh generate   # データ生成のみ
#   cd ~/isaac-mimic && bash scripts/run_experiments.sh train      # 学習のみ
#   cd ~/isaac-mimic && bash scripts/run_experiments.sh all        # 全ステップ
#
# 注意: 各ジョブは sbatch で投入されるため、完了を待たずに次のジョブが投入される。
#       依存関係が必要な場合は --dependency=afterok:JOBID を使用すること。
#

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${PROJECT_DIR}"

MODE="${1:-all}"

echo "============================================"
echo "  Isaac Lab Mimic Experiment Runner"
echo "============================================"
echo "  Mode: ${MODE}"
echo "  Date: $(date)"
echo "============================================"
echo ""

# --- データ生成 ---
if [ "${MODE}" = "generate" ] || [ "${MODE}" = "all" ]; then
    echo "=== Phase 1: Data Generation ==="

    # State-based (SkillGen)
    for NUM in 10 100 1000; do
        echo "  Submitting: state ${NUM} demos..."
        sbatch slurm/generate.sh state ${NUM}
    done

    # Visuomotor (カメラ付き)
    for NUM in 10 100 1000; do
        echo "  Submitting: visuomotor ${NUM} demos..."
        sbatch slurm/generate.sh visuomotor ${NUM}
    done

    echo ""
    echo "  6 generation jobs submitted."
    echo "  Check status: squeue -u ${USER}"
    echo ""
fi

# --- 学習 ---
if [ "${MODE}" = "train" ] || [ "${MODE}" = "all" ]; then
    echo "=== Phase 2: Training ==="

    # State-based BC（DRなし / あり）
    for NUM in 10 100 1000; do
        echo "  Submitting: state ${NUM} demos (no DR)..."
        sbatch slurm/train.sh state ${NUM}

        echo "  Submitting: state ${NUM} demos (with DR)..."
        sbatch slurm/train.sh state ${NUM} dr
    done

    # Visuomotor BC（DRなし / あり）
    for NUM in 10 100 1000; do
        echo "  Submitting: visuomotor ${NUM} demos (no DR)..."
        sbatch slurm/train.sh visuomotor ${NUM}

        echo "  Submitting: visuomotor ${NUM} demos (with DR)..."
        sbatch slurm/train.sh visuomotor ${NUM} dr
    done

    echo ""
    echo "  12 training jobs submitted."
    echo "  Check status: squeue -u ${USER}"
    echo ""
fi

echo "============================================"
echo "  All jobs submitted: $(date)"
echo "============================================"
echo ""
echo "  ジョブ状況確認:"
echo "    squeue -u ${USER}"
echo ""
echo "  ログ確認:"
echo "    tail -f logs/train_*.out"
echo ""
echo "  ログ転送（Mac側）:"
echo "    scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/"
echo "============================================"
