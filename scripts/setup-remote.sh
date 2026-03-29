#!/bin/bash
#
# リモートホスト（A100 highreso）初期セットアップスクリプト
#
# 使い方: ssh a100-highreso で接続後に実行
#   bash scripts/setup-remote.sh
#
# このスクリプトは以下を行う:
#   1. 環境確認（Docker, GPU, Slurm）
#   2. プロジェクトディレクトリ作成
#   3. 事前データセットのダウンロード
#

set -euo pipefail

echo "============================================"
echo "  Isaac Lab Mimic Remote Setup"
echo "============================================"
echo ""

# --- 環境確認 ---
echo "[1/4] Checking environment..."

echo -n "  Docker: "
if command -v docker &>/dev/null; then
    docker --version
else
    echo "NOT FOUND - Docker is required"
    exit 1
fi

echo -n "  Docker Compose: "
if docker compose version &>/dev/null; then
    docker compose version
else
    echo "NOT FOUND - Docker Compose is required"
    exit 1
fi

echo -n "  NVIDIA GPU: "
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || echo "Available (details in compute node)"
else
    echo "nvidia-smi not found on login node (may be available on compute nodes)"
fi

echo -n "  Slurm: "
if command -v sinfo &>/dev/null; then
    echo "Available"
    echo "  Partitions:"
    sinfo --format="    %P %l %D %G" 2>/dev/null || echo "    (could not list partitions)"
else
    echo "NOT FOUND"
fi

# --- ディスク容量確認 ---
echo ""
echo "[2/4] Checking disk space..."
df -h "${HOME}" | tail -1
echo "  (Isaac Lab image requires ~25GB+, datasets ~5GB)"

# --- プロジェクトディレクトリ ---
echo ""
echo "[3/4] Setting up project directory..."
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "${PROJECT_DIR}/datasets"
mkdir -p "${PROJECT_DIR}/logs"
mkdir -p "${PROJECT_DIR}/results"
echo "  Project dir: ${PROJECT_DIR}"

# --- ファイル確認 ---
echo ""
echo "[4/4] Checking project files..."
if [ -f "${PROJECT_DIR}/docker/Dockerfile" ]; then
    echo "  Project files found."
else
    echo "  WARNING: Project files not found."
    echo "  Please clone the repository first:"
    echo "    git clone git@github.com:tomokazu-rikioka/isaac-mimic.git ~/isaac-mimic"
    exit 1
fi

echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "  次のステップ:"
echo "  1. 事前データセットのダウンロード:"
echo "     cd ~/isaac-mimic && bash scripts/download_dataset.sh"
echo ""
echo "  2. Docker イメージのビルド:"
echo "     cd ~/isaac-mimic && sbatch slurm/build.sh"
echo ""
echo "  3. データ生成:"
echo "     cd ~/isaac-mimic && sbatch slurm/generate.sh"
echo ""
echo "  4. 学習:"
echo "     cd ~/isaac-mimic && sbatch slurm/train.sh state 1000"
echo ""
echo "  5. ログ転送（Mac側）:"
echo "     scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/"
echo "============================================"
