# カメラ・画像データの扱い方

## 1. カメラデータは使えるのか

**結論: はい、Isaac Lab Mimic は Visuomotor ポリシー用のカメラデータ生成を完全にサポートしている。**

対応するデータタイプ:
- RGB / RGBA 画像
- 深度マップ（Depth）
- セマンティックセグメンテーション
- インスタンスセグメンテーション
- 法線マップ（Normal Maps）
- モーションベクトル

このプロジェクトでも、12条件中6条件が Visuomotor（カメラデータ付き）で実験を行う。

## 2. Isaac Lab のカメラシステム

### 2.1 Camera クラス

Isaac Lab の基本カメラセンサー。USD Camera prim をラップし、各種データタイプのレンダリングを行う。

**主要パラメータ**:

| パラメータ | 説明 | 例 |
|-----------|------|-----|
| `width` | 画像の幅（ピクセル） | 128, 256, 512 |
| `height` | 画像の高さ（ピクセル） | 128, 256, 512 |
| `data_types` | 取得するデータの種類 | `["rgb", "depth"]` |
| `spawn` | カメラの配置設定 | `PinholeCameraCfg(...)` |

### 2.2 TiledCamera クラス（推奨）

GPU タイルレンダリングを使った高速カメラ。複数環境のカメラを一括でレンダリングし、GPU 上でテンソルとして直接取得する。

**利点**:
- 数百〜数千のカメラを同時にレンダリング可能
- GPU→CPU のデータ転送が不要
- Visuomotor データ生成に推奨

**動作原理**: 全カメラの画像を GPU フレームバッファ上の「タイル」として1回のレンダリングパスで生成し、環境ごとのテンソルに効率的に再構成する。

### 2.3 対応データタイプ一覧

| データタイプ | 形状 | 型 | 説明 |
|------------|------|-----|------|
| `rgb` | [H, W, 3] | `uint8` | RGB カラー画像 |
| `rgba` | [H, W, 4] | `uint8` | RGBA 画像（アルファチャンネル付き） |
| `depth` | [H, W, 1] | `float32` | 深度マップ（カメラ光学中心からの距離） |
| `semantic_segmentation` | [H, W, 1] | `int32` | セマンティックセグメンテーション |
| `instance_segmentation_fast` | [H, W, 1] | `int32` | インスタンスセグメンテーション |
| `normals` | [H, W, 3] | `float32` | 法線マップ |
| `motion_vectors` | [H, W, 2] | `float32` | モーションベクトル（オプティカルフロー） |

## 3. Visuomotor データ生成の方法

### 3.1 基本的な使い方

カメラデータ付きのデモ生成は `--enable_cameras` フラグで有効化する:

```bash
# Visuomotor 用データ生成
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/generate_dataset.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0 \
    --input datasets/annotated_dataset_skillgen.hdf5 \
    --output datasets/generated_visuomotor_1000.hdf5 \
    --generation_num_trials 1000 \
    --num_envs 5 \
    --enable_cameras \
    --headless
```

このプロジェクトでは `slurm/generate.sh visuomotor` で実行できる:

```bash
sbatch slurm/generate.sh visuomotor 1000
```

### 3.2 タスク名の違い

| 用途 | タスク名 |
|------|---------|
| State-based 生成 | `Isaac-Stack-Cube-Franka-IK-Rel-Skillgen-v0` |
| Visuomotor 生成 | `Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0` |
| Cosmos 用マルチモーダル | `Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Cosmos-Mimic-v0` |

Visuomotor 用タスクには、環境定義にカメラセンサーの設定が含まれている。

### 3.3 HDF5 における画像データの格納

Visuomotor データの HDF5 構造:

```
demo_0/
  actions: [T, action_dim]
  obs/
    joint_pos: [T, num_joints]
    ee_pos: [T, 3]
    ee_quat: [T, 4]
    gripper: [T, 1]
    object_pos: [T, 3]
    images/
      camera_0: [T, H, W, C]    # RGB 画像データ
      depth_0: [T, H, W, 1]     # 深度マップ（オプション）
```

### 3.4 GPU メモリに関する注意

カメラレンダリングは追加の GPU メモリを消費する:

| モード | メモリ/環境 | A100 80GB での推奨並列数 |
|--------|-----------|------------------------|
| State-based | ~4.5 GB | 10-15 環境 |
| Visuomotor | ~8.0 GB | 5-8 環境 |

メモリ不足の場合は `--num_envs` を減らすか、画像解像度を下げる。

## 4. カメラ設定のカスタマイズ

### 4.1 カメラ位置・姿勢の変更

環境定義クラス内の `CameraCfg` でカメラの配置を指定する:

```python
from isaaclab.sensors import CameraCfg

# 正面カメラの例
front_camera = CameraCfg(
    prim_path="{ENV_REGEX_NS}/Camera/front",
    offset=CameraCfg.OffsetCfg(
        pos=(1.0, 0.0, 0.8),    # ワールド座標 (x, y, z)
        rot=(0.0, 0.0, 0.0, 1.0),  # クォータニオン
        convention="world",
    ),
    spawn=PinholeCameraCfg(
        focal_length=24.0,
        focus_distance=400.0,
        horizontal_aperture=20.955,
        clipping_range=(0.1, 10.0),
    ),
    width=128,
    height=128,
    data_types=["rgb"],
)
```

### 4.2 複数カメラの設定

複数視点からのカメラを追加できる:

```python
class MySceneCfg(InteractiveSceneCfg):
    # 正面カメラ
    front_camera = CameraCfg(...)
    # 手元カメラ（エンドエフェクタに取り付け）
    wrist_camera = CameraCfg(
        prim_path="{ENV_REGEX_NS}/Robot/ee_link/Camera",
        ...
    )
    # 俯瞰カメラ
    overhead_camera = CameraCfg(
        prim_path="{ENV_REGEX_NS}/Camera/overhead",
        offset=CameraCfg.OffsetCfg(pos=(0.5, 0.0, 1.5), ...),
        ...
    )
```

### 4.3 画像解像度の変更

| 解像度 | GPU メモリ | 学習品質 | 用途 |
|--------|-----------|---------|------|
| 64x64 | 低 | 低 | デバッグ・高速プロトタイプ |
| 128x128 | 中 | 中 | 一般的な実験（推奨） |
| 256x256 | 高 | 高 | 高品質な学習 |
| 512x512 | 非常に高 | 非常に高 | 研究用途 |

**推奨**: 初期実験では 128x128 で開始し、結果を見て解像度を調整。

## 5. Visuomotor ポリシーの学習

### 5.1 ネットワークアーキテクチャ

Visuomotor ポリシーは robomimic の BC アルゴリズムを使用する:

```
カメラ画像 [T, H, W, C]
        ↓
CNN エンコーダー (ResNet-18 等)
        ↓
画像特徴ベクトル [feature_dim]
        ↓  concat
状態情報 [joint_pos, ee_pos, ...]
        ↓
MLP ポリシーヘッド
        ↓
アクション [action_dim]
```

### 5.2 学習の実行

```bash
# Visuomotor ポリシーの学習
sbatch slurm/train.sh visuomotor 1000

# Domain Randomization あり
sbatch slurm/train.sh visuomotor 1000 dr
```

### 5.3 学習のコツ

- **十分なデモ数**: Visuomotor は State-based より多くのデモが必要（1000本推奨）
- **Domain Randomization の活用**: 視覚ランダム化（照明、色、テクスチャ）がポリシーの汎化に効果的
- **画像前処理**: 画像は [0, 255] の `uint8` で格納され、学習時に [0, 1] の `float32` に正規化
- **バッチサイズ**: 画像データはメモリを多く消費するため、バッチサイズの調整が必要

### 5.4 期待される性能

| 条件 | エポック | 成功率 |
|------|---------|--------|
| Visuomotor, 1000 demos, no DR | 600 | 50-60% |
| Visuomotor, 1000 demos, with DR | 600 | 要検証 |
| Visuomotor, 100 demos | 600 | 要検証（低い見込み） |

## 6. マルチモーダルデータの活用

### 6.1 RGB + 深度

RGB 画像に深度マップを組み合わせることで、空間的な認識を改善できる:

```python
data_types = ["rgb", "depth"]
```

### 6.2 複数カメラの組み合わせ

正面カメラと手元カメラを組み合わせることで、異なる視点からの情報を統合:

- **正面カメラ**: シーン全体の把握
- **手元カメラ**: 精密な操作の支援

### 6.3 Cosmos によるデータ拡張

生成された Visuomotor データに Cosmos で視覚的バリエーションを追加できる。詳細は [Cosmos 連携](./06_cosmos_integration.md) を参照。

## 7. デバッグとベストプラクティス

### 画像データの可視化

```python
import h5py
import matplotlib.pyplot as plt

with h5py.File("datasets/generated_visuomotor_1000.hdf5", "r") as f:
    # 最初のデモの最初のフレーム
    image = f["data/demo_0/obs/images/camera_0"][0]
    plt.imshow(image)
    plt.title("Camera 0, Frame 0")
    plt.savefig("debug_image.png")
```

### よくあるエラー

**`--enable_cameras` 忘れ**:
カメラデータなしでデータが生成される。Visuomotor 用タスクには必ず `--enable_cameras` を付ける。

**レンダリング速度の低下**:
カメラ数や解像度が多いとレンダリングが遅くなる。デバッグ時は解像度を下げるか、カメラ数を減らす。

**画像が真っ黒**:
- カメラの `clipping_range` がシーンに対して適切か確認
- 照明設定が正しいか確認
- カメラがオブジェクトの方向を向いているか確認
