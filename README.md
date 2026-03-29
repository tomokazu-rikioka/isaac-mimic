# isaac-mimic

Isaac Lab Mimic を使った模倣学習用合成データのかさ増し（Synthetic Data Augmentation）パイプライン。

Franka Stack Cube タスクで **State-based / Visuomotor Policy × データ量 × Domain Randomization** の包括的比較検証を行う。

## Architecture

```
Mac (コード編集) → git push → A100 highreso (Docker + Slurm) → scp logs back
                                  ↑
Windows GPU (テレオペ収集、必要時のみ)
```

## Quick Start

### 1. リモート（A100 highreso）初期セットアップ

```bash
ssh a100-highreso
git clone git@github.com:tomokazu-rikioka/isaac-mimic.git ~/isaac-mimic
cd ~/isaac-mimic
bash scripts/setup-remote.sh
```

### 2. Docker イメージのビルド

```bash
cd ~/isaac-mimic && sbatch slurm/build.sh
```

### 3. 事前データセットのダウンロード

```bash
cd ~/isaac-mimic && bash scripts/download_dataset.sh
```

### 4. データ生成（SkillGen、テレオペ不要）

```bash
# 小規模テスト（10エピソード）
sbatch slurm/generate.sh state 10

# 本番（1000エピソード）
sbatch slurm/generate.sh state 1000

# Visuomotor用（カメラ画像付き）
sbatch slurm/generate.sh visuomotor 1000
```

### 5. 学習

```bash
# State-based BC
sbatch slurm/train.sh state 1000

# Visuomotor BC
sbatch slurm/train.sh visuomotor 1000

# Domain Randomization 付き
sbatch slurm/train.sh state 1000 dr
```

### 6. 評価

```bash
sbatch slurm/play.sh state 1000 logs/robomimic/.../model_epoch_XXXX.pth
```

### 7. 全12条件の一括実行

```bash
bash scripts/run_experiments.sh all
```

### 8. ログ転送（Mac 側）

```bash
scp -r a100-highreso:~/isaac-mimic/logs/ ./logs/
```

## Experiment Matrix (12 Conditions)

| # | Policy | Demos | DR | Expected Success Rate |
|---|--------|-------|----|-----------------------|
| 1 | State BC | 10 | - | ~0% (参考値) |
| 2 | State BC | 100 | - | TBD |
| 3 | State BC | 1000 | - | ~90% (参考値) |
| 4 | State BC | 10 | Yes | TBD |
| 5 | State BC | 100 | Yes | TBD |
| 6 | State BC | 1000 | Yes | TBD |
| 7 | Visuomotor BC | 10 | - | TBD |
| 8 | Visuomotor BC | 100 | - | TBD |
| 9 | Visuomotor BC | 1000 | - | TBD |
| 10 | Visuomotor BC | 10 | Yes | TBD |
| 11 | Visuomotor BC | 100 | Yes | TBD |
| 12 | Visuomotor BC | 1000 | Yes | TBD |

## Directory Structure

```
isaac-mimic/
├── docker/                  # Docker 環境
│   ├── Dockerfile
│   └── docker-compose.yml
├── slurm/                   # Slurm バッチスクリプト
│   ├── build.sh
│   ├── annotate.sh
│   ├── generate.sh
│   ├── train.sh
│   └── play.sh
├── scripts/                 # ユーティリティ
│   ├── env.sh
│   ├── setup-remote.sh
│   ├── download_dataset.sh
│   └── run_experiments.sh
├── configs/                 # 実験設定
│   ├── experiments.yaml
│   └── domain_randomization.py
├── datasets/                # HDF5 データセット（.gitignore）
├── logs/                    # 学習ログ（.gitignore）
└── results/                 # 実験結果（.gitignore）
```

## Requirements

- **A100 highreso**: Docker, Slurm, NVIDIA GPU driver
- **Docker base image**: `nvcr.io/nvidia/isaac-lab:2.3.2`
- **追加依存**: robomimic, cuRobo (SkillGen用)

## (Optional) Windows テレオペデータ収集

事前データセットだけでは不十分な場合:

```bash
# Windows (Isaac Sim + Isaac Lab) でキーボード操作
./isaaclab.sh -p scripts/tools/record_demos.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-v0 \
    --teleop_device keyboard \
    --dataset_file ./datasets/teleop_dataset.hdf5 \
    --num_demos 10

# HDF5 を A100 に転送
scp datasets/teleop_dataset.hdf5 a100-highreso:~/isaac-mimic/datasets/
```

## References

- [ABEJA Tech Blog: Isaac Sim & Lab を使用したロボティクス学習データ生成](https://tech-blog.abeja.asia/entry/isaac-sim-lab-synthetic-dataset-202507)
- [Isaac Lab Documentation](https://isaac-sim.github.io/IsaacLab/main/index.html)
- [Isaac Lab Mimic - Teleoperation and Imitation Learning](https://isaac-sim.github.io/IsaacLab/main/source/overview/imitation-learning/teleop_imitation.html)
- [SkillGen for Automated Demonstration Generation](https://isaac-sim.github.io/IsaacLab/main/source/overview/imitation-learning/skillgen.html)
