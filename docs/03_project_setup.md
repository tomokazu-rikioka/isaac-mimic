# プロジェクトセットアップと実行手順

## 1. アーキテクチャ概要

このプロジェクトは3つの環境で構成される。

```
┌──────────────┐    git push    ┌──────────────────────────────────┐
│  Mac (ローカル) │ ──────────→ │  A100 highreso                    │
│               │              │  Docker + Slurm でヘッドレス実行     │
│  - コード編集   │ ←────────── │  - データ生成 (generate)            │
│  - git 管理    │   scp logs   │  - 学習 (train)                   │
└──────────────┘              │  - 評価 (play)                    │
                               └──────────────────────────────────┘
                                          ↑
┌──────────────┐    scp          │
│  Windows GPU  │ ──────────────┘
│  (必要時のみ)  │
│  - テレオペ収集 │
└──────────────┘
```

**基本フロー**:
```
git push (Mac) → git pull (A100) → sbatch slurm/*.sh → scp logs back (Mac)
```

## 2. 前提条件

### A100 highreso

| 要件 | 詳細 |
|------|------|
| GPU | NVIDIA A100 (80GB 推奨) |
| Docker | Docker + Docker Compose |
| Slurm | ジョブスケジューラ |
| GPU ドライバ | NVIDIA GPU Driver (nvidia-smi で確認) |
| ディスク | ~25GB (Isaac Lab) + ~5GB (データセット) |

### GPU メモリ要件

| モード | メモリ/環境 | 5並列時 |
|--------|-----------|---------|
| State-based | ~4.5 GB | ~22.5 GB |
| Visuomotor | ~8.0 GB | ~40.0 GB |

## 3. 初期セットアップ（A100）

### 3.1 リポジトリのクローン

```bash
ssh a100-highreso
cd ~
git clone <repository-url> isaac-mimic
cd isaac-mimic
```

### 3.2 環境チェック（setup-remote.sh）

```bash
bash scripts/setup-remote.sh
```

このスクリプトは以下を確認する:
- Docker & Docker Compose の利用可能性
- NVIDIA GPU ドライバと `nvidia-smi`
- Slurm (`sinfo`) と利用可能なパーティション
- ディスク空き容量（~30GB 必要）

確認後、`datasets/`, `logs/`, `results/` ディレクトリを自動作成する。

### 3.3 データセットのダウンロード

```bash
bash scripts/download_dataset.sh
```

NVIDIA S3 から事前アノテーション済みデータセットをダウンロードする:
- **ファイル**: `datasets/annotated_dataset_skillgen.hdf5`
- **サイズ**: 約 500MB
- **内容**: Franka Stack Cube タスクのアノテーション済みデモ（SkillGen 対応）

## 4. Docker イメージのビルド

### 4.1 ビルドの実行

```bash
sbatch slurm/build.sh
```

**所要時間**: 約 20-40 分（初回、ネットワーク速度依存）

### 4.2 Dockerfile の構成

```
ベースイメージ: nvcr.io/nvidia/isaac-lab:2.3.2
    ↓
システムパッケージ: ffmpeg, git, curl, wget
    ↓
uv パッケージマネージャのインストール
    ↓
Python パス設定 (Isaac Sim 内蔵 Python 3.11)
    ↓
追加ライブラリ:
  - toml (依存関係修復)
  - robomimic (模倣学習)
  - numpy (依存関係修復)
    ↓
cuRobo (GPU モーション計画, コミット ebb71702 に固定)
    ↓
プロジェクトファイルのコピー (configs/, scripts/)
```

**ビルド確認**:
```bash
docker images | grep isaac-lab-mimic
# → isaac-lab-mimic  2.3.2  ...
```

## 5. 実験マトリクス（12条件）

### 5.1 3軸の実験設計

| 軸 | 値 | 説明 |
|----|------|------|
| Policy | State / Visuomotor | 状態ベース vs 画像ベース |
| データ量 | 10 / 100 / 1000 | 生成するデモ数 |
| Domain Randomization | なし / あり | 環境ランダム化の有無 |

→ **2 × 3 × 2 = 12 条件**

### 5.2 全12条件一覧

| # | Policy | デモ数 | DR | タスク名 | データセット |
|---|--------|--------|-----|---------|-------------|
| 1 | State | 10 | No | Isaac-Stack-Cube-Franka-IK-Rel-v0 | generated_state_10.hdf5 |
| 2 | State | 100 | No | 同上 | generated_state_100.hdf5 |
| 3 | State | 1000 | No | 同上 | generated_state_1000.hdf5 |
| 4 | State | 10 | Yes | 同上 | generated_state_10.hdf5 |
| 5 | State | 100 | Yes | 同上 | generated_state_100.hdf5 |
| 6 | State | 1000 | Yes | 同上 | generated_state_1000.hdf5 |
| 7 | Visuomotor | 10 | No | Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0 | generated_visuomotor_10.hdf5 |
| 8 | Visuomotor | 100 | No | 同上 | generated_visuomotor_100.hdf5 |
| 9 | Visuomotor | 1000 | No | 同上 | generated_visuomotor_1000.hdf5 |
| 10 | Visuomotor | 10 | Yes | 同上 | generated_visuomotor_10.hdf5 |
| 11 | Visuomotor | 100 | Yes | 同上 | generated_visuomotor_100.hdf5 |
| 12 | Visuomotor | 1000 | Yes | 同上 | generated_visuomotor_1000.hdf5 |

### 5.3 参考成功率

ABEJA Tech Blog および Isaac Lab 公式ドキュメントからの参考値:

| 条件 | エポック | 成功率 |
|------|---------|--------|
| State, 10 demos | 1000 | 0% |
| State, 1000 demos | 100 | ~50% |
| State, 1000 demos | 1000 | ~90% |
| SkillGen State, 1000 demos | 2000 | 40-85% |
| Visuomotor, 1000 demos | 600 | 50-60% |

## 6. ワークフロー詳細

### 6.1 データ生成（slurm/generate.sh）

```bash
# State-based（SkillGen モード）
sbatch slurm/generate.sh                    # 1000 デモ
sbatch slurm/generate.sh state 100          # 100 デモ
sbatch slurm/generate.sh state 10           # 10 デモ

# Visuomotor（カメラ付き）
sbatch slurm/generate.sh visuomotor 1000    # 1000 デモ
sbatch slurm/generate.sh visuomotor 100     # 100 デモ
sbatch slurm/generate.sh visuomotor 10      # 10 デモ
```

**パラメータ**:
- 第1引数: ポリシータイプ（`state` / `visuomotor`、デフォルト: `state`）
- 第2引数: 生成デモ数（デフォルト: 1000）
- 第3引数: 並列環境数（デフォルト: 5）

**タイムアウト**: 12 時間

**State と Visuomotor の違い**:

| | State | Visuomotor |
|---|-------|-----------|
| タスク名 | `Isaac-Stack-Cube-Franka-IK-Rel-Skillgen-v0` | `Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0` |
| 追加フラグ | `--use_skillgen` | `--enable_cameras` |
| 入力 | `annotated_dataset_skillgen.hdf5` | `annotated_dataset_skillgen.hdf5` |
| 出力 | `generated_state_N.hdf5` | `generated_visuomotor_N.hdf5` |
| GPU メモリ | ~4.5 GB/env | ~8.0 GB/env |

### 6.2 学習（slurm/train.sh）

```bash
# State-based
sbatch slurm/train.sh state 1000             # DR なし
sbatch slurm/train.sh state 1000 dr          # DR あり

# Visuomotor
sbatch slurm/train.sh visuomotor 1000        # DR なし
sbatch slurm/train.sh visuomotor 1000 dr     # DR あり
```

**パラメータ**:
- 第1引数: ポリシータイプ（`state` / `visuomotor`、デフォルト: `state`）
- 第2引数: デモ数（デフォルト: 1000）
- 第3引数: `dr` を指定すると Domain Randomization 有効

**タイムアウト**: 24 時間

**出力先**: `logs/robomimic/<実験名>/`

### 6.3 評価（slurm/play.sh）

```bash
sbatch slurm/play.sh state 1000 logs/robomimic/.../model_epoch_1000.pth
sbatch slurm/play.sh visuomotor 1000 logs/robomimic/.../model_epoch_500.pth 100
```

**パラメータ**:
- 第1引数: ポリシータイプ
- 第2引数: デモ数
- 第3引数: チェックポイントパス（**必須**）
- 第4引数: ロールアウト数（デフォルト: 50）

**タイムアウト**: 2 時間

### 6.4 一括実行（scripts/run_experiments.sh）

```bash
# データ生成のみ（6ジョブ投入）
bash scripts/run_experiments.sh generate

# 学習のみ（12ジョブ投入）
bash scripts/run_experiments.sh train

# 生成 + 学習（生成完了後に学習を自動投入）
bash scripts/run_experiments.sh all
```

ジョブ依存関係（`--dependency=afterok:JOBID`）により、データ生成完了後に学習ジョブが自動的に開始される。

### 6.5 オプション: テレオペデモのアノテーション（slurm/annotate.sh）

事前提供データセットを使わず、自前のテレオペデモを使う場合:

```bash
# 事前に datasets/teleop_dataset.hdf5 を用意
sbatch slurm/annotate.sh              # State 用
sbatch slurm/annotate.sh visuomotor   # Visuomotor 用
```

## 7. ログ管理

### 7.1 Slurm ログ

各ジョブの stdout/stderr は `logs/` ディレクトリに保存される:
```
logs/
  build_12345.out
  generate_state_1000_12346.out
  train_state_1000_12347.out
  ...
```

### 7.2 学習ログ

robomimic の学習ログは `logs/robomimic/` 以下に保存される:
```
logs/robomimic/
  state_1000/
    models/
      model_epoch_100.pth
      model_epoch_200.pth
      ...
    logs/
      log.txt
      tb/  (TensorBoard)
```

### 7.3 ログの Mac への転送

```bash
# Mac 側で実行
scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/
```

## 8. トラブルシューティング

### GPU メモリ不足

```
RuntimeError: CUDA out of memory
```

**対処**: `--num_envs` を減らす（例: 5 → 3）

```bash
sbatch slurm/generate.sh visuomotor 1000 3  # 3並列に減らす
```

### Docker イメージが見つからない

```
docker: Error response from daemon: pull access denied
```

**対処**: `sbatch slurm/build.sh` でイメージをビルド

### cuRobo のビルドエラー

**対処**:
1. `TORCH_CUDA_ARCH_LIST` が GPU アーキテクチャに一致しているか確認（A100 = "8.0+PTX"）
2. cuRobo のコミット `ebb71702` が使われているか確認

### HDF5 ファイルの破損

```python
# Python で確認
import h5py
with h5py.File("datasets/generated_state_1000.hdf5", "r") as f:
    print(list(f["data"].keys()))
```

### 環境変数の確認

全スクリプトは `scripts/env.sh` を共有している:
```bash
MIMIC_DIR="/workspace/isaac-mimic"
ISAACLAB_DIR="/workspace/isaaclab"
PYTHON="${ISAACLAB_DIR}/_isaac_sim/kit/python/bin/python3"
BASE_IMAGE="nvcr.io/nvidia/isaac-lab:2.3.2"
IMAGE="isaac-lab-mimic:2.3.2"
```

## 9. ファイルリファレンス

| ファイル | 説明 |
|---------|------|
| `scripts/env.sh` | 共通環境変数の定義 |
| `scripts/setup-remote.sh` | A100 初期セットアップ |
| `scripts/download_dataset.sh` | 事前提供データセットのダウンロード |
| `scripts/run_experiments.sh` | 12条件一括実行 |
| `configs/experiments.yaml` | 実験マトリクスの定義 |
| `configs/domain_randomization.py` | Domain Randomization パラメータ |
| `slurm/build.sh` | Docker ビルド |
| `slurm/annotate.sh` | デモアノテーション |
| `slurm/generate.sh` | データ生成 |
| `slurm/train.sh` | ポリシー学習 |
| `slurm/play.sh` | ポリシー評価 |
| `docker/Dockerfile` | Docker イメージ定義 |
| `docker/docker-compose.yml` | Docker Compose 設定 |
