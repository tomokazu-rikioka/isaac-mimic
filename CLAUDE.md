# Isaac Mimic - Synthetic Data Augmentation for Imitation Learning

## Overview

Isaac Lab Mimic を使った模倣学習用合成データのかさ増しパイプライン。
Franka Stack Cube タスクで、State-based / Visuomotor Policy × データ量 × Domain Randomization の包括的比較検証を行う。

## Architecture

- **ローカル (Mac)**: コード編集・git push
- **Windows GPU**: テレオペによるデモ収集（必要時のみ）
- **A100 highreso**: Docker + Slurm でヘッドレス実行（データ生成・学習・評価）

## Workflow

```
git push (Mac) → git pull (A100) → sbatch slurm/*.sh → scp logs back
```

## Key Commands (A100)

```bash
sbatch slurm/build.sh                        # Docker build
sbatch slurm/generate.sh                     # データ生成
sbatch slurm/generate.sh visuomotor          # Visuomotor用データ生成
sbatch slurm/train.sh state 1000             # State BC学習（1000デモ）
sbatch slurm/train.sh visuomotor 1000        # Visuomotor BC学習
sbatch slurm/play.sh state 1000              # 評価
```

## Constraints

- Isaac Lab Mimic は **Linux のみ** 対応（annotate/generate/train は A100 Docker 内で実行）
- cuRobo のバージョンは Isaac Lab と互換性のあるコミット `ebb71702` に固定
- Docker ベースイメージ: `nvcr.io/nvidia/isaac-lab:2.3.2`（最新タグ要確認）
- datasets/ ディレクトリの HDF5 ファイルは .gitignore 対象
- logs/ ディレクトリも .gitignore 対象（scp で Mac に転送して確認）
