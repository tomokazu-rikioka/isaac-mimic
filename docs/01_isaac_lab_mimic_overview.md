# Isaac Lab Mimic の全体像とチュートリアル

## 1. Isaac Lab Mimic とは

Isaac Lab Mimic は、NVIDIA Isaac Lab フレームワーク内の**合成デモンストレーション自動生成モジュール**である。模倣学習（Imitation Learning）におけるデータ不足問題を解決するために設計されており、**少数の人間によるテレオペレーションデモ（5〜10本）から数千本の合成デモを自動生成**できる。

### 解決する課題

模倣学習ではロボットの動作を教示データ（デモンストレーション）から学習するが、高品質なデモの収集はコストが高い:

- テレオペレーションには熟練したオペレーターが必要
- 1本のデモに数分〜数十分かかる
- 学習に必要なデモ数は数百〜数千本

Isaac Lab Mimic はこの問題を、**サブタスク単位でのデモ分割・変換・再接合**によって解決する。

### 元になった研究

- **MimicGen** (Mandlekar et al., CoRL 2023): オリジナルのデモ増幅アルゴリズム
- **SkillGen**: GPU 並列モーション計画による自動デモ生成の拡張

## 2. NVIDIA エコシステムにおける位置づけ

```
┌─────────────────────────────────────────────────┐
│  NVIDIA Isaac Sim                                │
│  （物理シミュレーション基盤: PhysX 5, RTX）         │
│                                                   │
│  ┌─────────────────────────────────────────────┐ │
│  │  Isaac Lab                                   │ │
│  │  （ロボット学習フレームワーク: RL, IL）         │ │
│  │                                               │ │
│  │  ┌───────────────────────────────────────┐   │ │
│  │  │  Isaac Lab Mimic                       │   │ │
│  │  │  （合成デモ生成モジュール）               │   │ │
│  │  │  + SkillGen (cuRobo)                   │   │ │
│  │  └───────────────────────────────────────┘   │ │
│  │                                               │ │
│  │  ┌───────────────────────────────────────┐   │ │
│  │  │  robomimic                             │   │ │
│  │  │  （模倣学習ライブラリ: BC, BCQ 等）      │   │ │
│  │  └───────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

- **Isaac Sim**: 物理シミュレーション基盤。PhysX 5 による高精度な物理演算と RTX レンダリングによるフォトリアリスティックな画像生成を提供
- **Isaac Lab**: ロボット学習フレームワーク。強化学習（RL）や模倣学習（IL）のタスク定義、環境管理、学習パイプラインを統合
- **Isaac Lab Mimic**: デモンストレーション生成に特化したモジュール。Isaac Lab の環境定義を利用してデモを自動生成
- **robomimic**: Stanford 発の模倣学習ライブラリ。Behavioral Cloning (BC) 等のアルゴリズムを提供

## 3. コアワークフロー（6ステップ）

```
[1. テレオペ] → [2. サブタスク定義] → [3. アノテーション]
                                            ↓
[6. 評価] ← [5. ポリシー学習] ← [4. 合成デモ生成]
```

### 3.1 ステップ1: テレオペレーションによるデモ収集

人間がロボットを遠隔操作してタスクのデモンストレーションを収集する。

**対応入力デバイス**:
- キーボード（最も手軽）
- SpaceMouse（6DOF 入力、推奨）
- Apple Vision Pro / Meta Quest（VR ヘッドセット）
- ハンドトラッキング（Rokoko グローブ等）

**デモの記録**:
```bash
# Isaac Lab のテレオペスクリプト例
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/record_demos.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Mimic-v0 \
    --teleop_device keyboard \
    --num_demos 10
```

**記録形式**: HDF5 ファイル（`.hdf5`）

**必要デモ数の目安**: 5〜10本。デモは短く、直線的で、スムーズな動作が望ましい。

### 3.2 ステップ2: サブタスクの定義

タスクをサブタスク（部分動作）に分割する。これが Mimic の合成生成の単位となる。

**Stack Cube タスクの例**:

| サブタスク | 説明 | 終了条件 |
|-----------|------|---------|
| `grasp_1` | 最初のキューブに接近して掴む | グリッパーがキューブを把持 |
| `stack` | キューブを2つ目の上に積み重ねる | キューブが目標位置に到達 |

サブタスクは `SubTaskConfig` として環境定義に含まれる:

```python
subtasks = [
    SubTaskConfig(
        name="grasp_1",
        object_ref="cube_A",  # 変換の基準となるオブジェクト
    ),
    SubTaskConfig(
        name="stack",
        object_ref="cube_B",
    ),
]
```

### 3.3 ステップ3: デモのアノテーション

収集したデモにサブタスク境界を付与する。

**自動アノテーション**（推奨）:
```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/annotate_demos.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Mimic-v0 \
    --input datasets/teleop_dataset.hdf5 \
    --output datasets/annotated_dataset.hdf5
```

アノテーション後の HDF5 には以下が追加される:
- `obs/datagen_info/eef_pose/`: エンドエフェクタの姿勢 [T, 4, 4]
- `obs/datagen_info/object_pose/`: オブジェクトの姿勢 [T, 4, 4]
- `obs/datagen_info/subtask_term_signals/`: サブタスク終了信号 [T, 1]
- `obs/datagen_info/subtask_start_signals/`: サブタスク開始信号 [T, 1]（SkillGen 用）

> **ショートカット**: NVIDIA が提供する事前アノテーション済みデータセット `annotated_dataset_skillgen.hdf5` を使えば、ステップ1〜3をスキップできる。このプロジェクトでは `scripts/download_dataset.sh` でダウンロード可能。

### 3.4 ステップ4: 合成デモの生成

アノテーション済みデモを元に、新しい合成デモを自動生成する。

**生成アルゴリズム**:

1. **パース**: デモをサブタスク単位に分割
2. **変換**: 各サブタスクのエンドエフェクタ軌道を新しいシーン配置に変換
3. **接合（stitching）**: 変換されたサブタスクを線形補間で繋ぎ合わせ
4. **検証**: シミュレーション上でロールアウトし、成功したデモのみ保存

**選択戦略**:
- **ランダム**: サブタスクセグメントをランダムに選択
- **最近傍（オブジェクト）**: オブジェクト位置が最も近いセグメントを選択
- **最近傍（ロボット距離）**: ロボットの状態が最も近いセグメントを選択

**実行例（SkillGen モード）**:
```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/generate_dataset.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Skillgen-v0 \
    --input datasets/annotated_dataset_skillgen.hdf5 \
    --output datasets/generated_state_1000.hdf5 \
    --generation_num_trials 1000 \
    --num_envs 5 \
    --use_skillgen \
    --headless
```

### 3.5 ステップ5: ポリシー学習

生成された合成デモデータセットで Behavioral Cloning (BC) ポリシーを学習する。

**学習フレームワーク**: robomimic

**ポリシータイプ**:
- **State-based**: 関節角度、エンドエフェクタ位置/姿勢、グリッパー状態、オブジェクト位置を観測
- **Visuomotor**: 状態情報に加えてカメラ画像を観測（[詳細](./04_camera_and_vision.md)）

**実行例**:
```bash
./isaaclab.sh -p scripts/imitation_learning/robomimic/train.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-v0 \
    --algo bc \
    --normalize_training_actions \
    --dataset datasets/generated_state_1000.hdf5
```

### 3.6 ステップ6: 評価

学習済みポリシーをシミュレーション上でロールアウトし、成功率を計測する。

```bash
./isaaclab.sh -p scripts/imitation_learning/robomimic/play.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-v0 \
    --checkpoint logs/robomimic/.../model_epoch_1000.pth \
    --num_rollouts 50 \
    --device cuda
```

**参考成功率（Stack Cube, Franka）**:

| 条件 | エポック | 成功率 |
|------|---------|--------|
| State, 10 demos, 1000 ep | 1000 | 0% |
| State, 1000 demos, 100 ep | 100 | ~50% |
| State, 1000 demos, 1000 ep | 1000 | ~90% |
| SkillGen State, 1000 demos | 2000 | 40-85% |
| Visuomotor, 1000 demos | 600 | 50-60% |

## 4. HDF5 データフォーマット

Isaac Lab Mimic のデモンストレーションは HDF5 形式で保存される。

```
dataset.hdf5
├── data/
│   ├── demo_0/
│   │   ├── actions          # [T, action_dim] 制御コマンド
│   │   ├── obs/
│   │   │   ├── joint_pos    # [T, num_joints] 関節角度
│   │   │   ├── ee_pos       # [T, 3] エンドエフェクタ位置
│   │   │   ├── ee_quat      # [T, 4] エンドエフェクタ姿勢（クォータニオン）
│   │   │   ├── gripper      # [T, 1] グリッパー開閉状態
│   │   │   ├── object_pos   # [T, 3] オブジェクト位置
│   │   │   └── images/      # (Visuomotor の場合)
│   │   │       └── camera_0 # [T, H, W, C] カメラ画像
│   │   └── datagen_info/    # (アノテーション後)
│   │       ├── eef_pose     # [T, 4, 4] エンドエフェクタ変換行列
│   │       ├── object_pose  # [T, 4, 4] オブジェクト変換行列
│   │       └── subtask_term_signals  # [T, 1] サブタスク終了信号
│   ├── demo_1/
│   │   └── ...
│   └── ...
└── env_args              # 環境設定のメタデータ
```

**Python での読み込み例**:
```python
import h5py

with h5py.File("datasets/generated_state_1000.hdf5", "r") as f:
    # デモ数の確認
    demos = list(f["data"].keys())
    print(f"デモ数: {len(demos)}")

    # 最初のデモの actions を取得
    actions = f["data/demo_0/actions"][:]
    print(f"actions shape: {actions.shape}")

    # 観測データの確認
    for key in f["data/demo_0/obs"].keys():
        data = f[f"data/demo_0/obs/{key}"]
        print(f"obs/{key}: shape={data.shape}, dtype={data.dtype}")
```

## 5. SkillGen の詳細

SkillGen は Isaac Lab Mimic の拡張機能で、**cuRobo（GPU 並列モーション計画ライブラリ）** を使って、テレオペレーションなしでデモを自動生成する。

### 仕組み

1. **スキルの分解**: タスクを多段階のスキルに分割
   - **アプローチ**: 目標オブジェクトに接近
   - **コンタクト**: オブジェクトとの接触・把持
   - **リトリート**: オブジェクトを持ち上げて退避
2. **GPU 並列モーション計画**: cuRobo を使って各段階のモーション計画を GPU 上で並列実行
3. **軌道の接合**: 計画された各段階を滑らかに接合して完全な軌道を生成

### 利点

- テレオペレーションが不要（人間のデモ収集をスキップ可能）
- GPU 並列処理による高速な軌道生成
- 衝突回避を考慮した安全な軌道

### 制約

- cuRobo のバージョンは Isaac Lab と互換性のある `ebb71702` コミットに固定
- `TORCH_CUDA_ARCH_LIST="8.0+PTX"` の設定が必要（A100 向け）
- SkillGen 専用のタスク定義（`*-Skillgen-v0`）を使用する必要がある

### 事前提供データセット

NVIDIA が Stack Cube タスクの事前アノテーション済みデータセットを提供している:

```bash
# ダウンロード
bash scripts/download_dataset.sh
# → datasets/annotated_dataset_skillgen.hdf5 (約500MB)
```

このデータセットを使えば、テレオペレーションとアノテーションのステップをスキップして、直接合成デモ生成に進める。
