# NVIDIA Cosmos との連携

## 1. Cosmos とは

NVIDIA Cosmos は、**世界基盤モデル（World Foundation Model, WFM）** を提供するプラットフォームである。9,000 兆トークン（2,000 万時間の実世界データ）で事前学習されており、物理法則に基づいたリアルな映像を生成・変換できる。

**ロボティクスにおける価値**: シミュレーションで生成した合成データのビジュアルをフォトリアリスティックに変換し、Sim-to-Real のドメインギャップを削減する。

### 主要モデル

| モデル | 説明 | 用途 |
|--------|------|------|
| **Cosmos Transfer 2.5** | 構造情報（セグメンテーション、深度等）からフォトリアリスティック映像を生成 | データ拡張 |
| **Cosmos Predict 2.5** | テキスト/画像/映像から将来の状態を予測 | 世界シミュレーション |
| **Cosmos Reason 2** | 物理法則を考慮した理解と推論 | データキュレーション |

## 2. Isaac Lab Mimic + Cosmos のワークフロー

### 2.1 全体パイプライン

```
Isaac Lab Mimic               Cosmos                    学習
┌─────────────────┐    ┌──────────────────┐    ┌──────────────┐
│ Visuomotor      │    │ Cosmos Transfer  │    │ robomimic    │
│ データ生成       │ →  │ 2.5              │ →  │ BC 学習       │
│                 │    │                  │    │              │
│ HDF5            │    │ フォトリアル変換   │    │ 拡張データ    │
│ (RGB, Depth,    │ →  │                  │ →  │ セットで学習   │
│  Segmentation)  │    │ MP4 → MP4        │    │              │
└─────────────────┘    └──────────────────┘    └──────────────┘
```

**詳細フロー**:
1. Isaac Lab Mimic で Visuomotor データ生成（RGB + 深度 + セグメンテーション）
2. HDF5 のカメラフレームを MP4 に変換
3. Cosmos Transfer 2.5 でフォトリアリスティックに変換
4. 変換後の MP4 を HDF5 に戻す
5. オリジナル + 拡張データセットで BC ポリシーを学習

### 2.2 Cosmos 用タスクバリアント

通常の Visuomotor タスクに加えて、Cosmos 連携用のマルチモーダルタスクが用意されている:

| タスク | 出力モダリティ |
|--------|-------------|
| `Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0` | RGB のみ |
| `Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Cosmos-Mimic-v0` | RGB + 深度 + セグメンテーション + 法線 |

Cosmos 連携には `*-Cosmos-Mimic-*` バリアントの使用が推奨される。セグメンテーションや深度を Cosmos Transfer の制御入力として使用することで、より高品質な変換が可能になる。

## 3. 実装手順

### 3.1 ステップ1: マルチモーダルデータ生成

まず Cosmos 連携用タスクでデータを生成する:

```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/generate_dataset.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Cosmos-Mimic-v0 \
    --input datasets/annotated_dataset_skillgen.hdf5 \
    --output datasets/generated_visuomotor_cosmos_1000.hdf5 \
    --generation_num_trials 1000 \
    --num_envs 5 \
    --enable_cameras \
    --headless
```

### 3.2 ステップ2: HDF5 → MP4 変換

Isaac Lab に含まれる `hdf5_to_mp4.py` スクリプトでカメラフレームを MP4 に変換:

```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/hdf5_to_mp4.py \
    --input datasets/generated_visuomotor_cosmos_1000.hdf5 \
    --output_dir datasets/cosmos_input/ \
    --modalities rgb depth segmentation normals
```

出力ディレクトリ構造:
```
datasets/cosmos_input/
├── demo_0/
│   ├── rgb.mp4
│   ├── depth.mp4
│   ├── segmentation.mp4
│   └── normals.mp4
├── demo_1/
│   └── ...
└── ...
```

### 3.3 ステップ3: CosmosWriter（Isaac Sim Replicator 経由の場合）

Isaac Sim 5.0+ には Replicator の CosmosWriter が内蔵されており、シミュレーション中に直接マルチモーダルデータをキャプチャできる:

```python
import omni.replicator.core as rep

# CosmosWriter の設定
writer = rep.WriterRegistry.get("CosmosWriter")
writer.initialize(
    output_dir="datasets/cosmos_capture/",
    # キャプチャするモダリティ
    rgb=True,
    depth=True,
    semantic_segmentation=True,
    instance_segmentation=True,
)
writer.attach(render_products)
```

**出力形式**: PNG 連番 + MP4 + メタデータ JSON が自動生成される。

### 3.4 ステップ4: Cosmos Transfer 2.5 での変換

Cosmos Transfer は Multi-ControlNet アーキテクチャを使用し、複数の制御入力（RGB、深度、セグメンテーション）から新しいフォトリアリスティック映像を生成する。

**制御ブランチ**:

| ブランチ | 入力 | 効果 |
|---------|------|------|
| `vis` (RGB) | シミュレーション画像 | 外観、照明、テクスチャを変換 |
| `depth` | 深度マップ | 空間構造を維持 |
| `seg` (セグメンテーション) | セグメンテーションマスク | オブジェクト境界を維持 |

**API 呼び出し例**（NVIDIA Build Platform）:

```python
import requests

# Cosmos Transfer API
response = requests.post(
    "https://api.nvidia.com/cosmos/transfer",
    headers={"Authorization": f"Bearer {API_KEY}"},
    json={
        "input_video": "path/to/rgb.mp4",
        "control_inputs": {
            "depth": "path/to/depth.mp4",
            "segmentation": "path/to/segmentation.mp4",
        },
        "prompt": "photorealistic kitchen scene with warm lighting",
        "num_variations": 5,  # 1入力から5パターン生成
    }
)
```

> 具体的な API 仕様は NVIDIA Build Platform の最新ドキュメントを参照のこと。

### 3.5 ステップ5: 変換後データの HDF5 再格納

変換後の MP4 を元の HDF5 と組み合わせて新しいデータセットを作成:

```python
import h5py
import cv2
import numpy as np

# オリジナルの HDF5 を読み込み
with h5py.File("datasets/generated_visuomotor_cosmos_1000.hdf5", "r") as src:
    with h5py.File("datasets/augmented_visuomotor_1000.hdf5", "w") as dst:
        for demo_key in src["data"].keys():
            # アクションと状態データはそのままコピー
            src.copy(f"data/{demo_key}/actions", dst, f"data/{demo_key}/actions")
            src.copy(f"data/{demo_key}/obs/joint_pos", dst, f"data/{demo_key}/obs/joint_pos")
            # ...他の状態データも同様

            # 変換後の画像を読み込んで格納
            cap = cv2.VideoCapture(f"datasets/cosmos_output/{demo_key}/rgb_augmented.mp4")
            frames = []
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break
                frames.append(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            cap.release()

            dst.create_dataset(
                f"data/{demo_key}/obs/images/camera_0",
                data=np.array(frames),
                dtype=np.uint8,
            )
```

**重要なポイント**:
- **アクションデータは変換不要**: ロボットの制御コマンドはそのまま維持
- **タイムステップの同期**: 画像フレーム数が元データと一致していることを確認
- **データ形式の整合性**: `[T, H, W, C]` フォーマットを維持

### 3.6 ステップ6: 拡張データセットでの学習

オリジナルと拡張データを組み合わせて学習:

```bash
# 拡張データセットでの学習
./isaaclab.sh -p scripts/imitation_learning/robomimic/train.py \
    --task Isaac-Stack-Cube-Franka-IK-Rel-Visuomotor-Mimic-v0 \
    --algo bc \
    --normalize_training_actions \
    --dataset datasets/augmented_visuomotor_1000.hdf5
```

## 4. 効果と期待される改善

### 4.1 Sim-to-Real ドメインギャップの削減

シミュレーションと現実世界の間の視覚的な差異（ドメインギャップ）は、Visuomotor ポリシーの実機転移における主要な課題。Cosmos による視覚拡張は以下のバリエーションを生成:

- **照明条件**: 異なる時間帯、光源の種類
- **テクスチャ**: テーブル、壁、床の素材変更
- **背景**: 異なる室内環境
- **色彩**: オブジェクトの色やトーンの変動

### 4.2 研究結果

NVIDIA の報告によると:

| 条件 | 照明変動下の成功率 |
|------|-----------------|
| Cosmos 拡張なし（ベースライン） | 20-30% |
| Cosmos 拡張あり（2000 デモ） | 62-77% |

Cosmos 拡張により、**視覚的バリエーションに対する頑健性が大幅に向上**する。

## 5. GR00T-Dreams Blueprint

GR00T-Dreams は Cosmos を使った最先端のロボットデータ生成パイプラインである。

### 概要

1. **Post-training**: 人間のテレオペデモを収集
2. **Dream generation**: ファインチューニングされた Cosmos モデルが合成シナリオを生成
3. **Quality filtering**: Cosmos Reason が失敗した軌道を除外
4. **Action extraction**: 2D 映像から 3D ロボット軌道を復元
5. **Policy training**: 合成データでポリシーを学習

### 成果

- **GR00T N1.5**: 36 時間で開発（従来は 3 ヶ月の手動データ収集が必要）
- ヒューマノイドロボットが言語指示から新しい動作を習得可能
- AeiRobot、Foxlink、Lightwheel、NEURA Robotics が早期採用

### 現時点での制約

- GR00T-Dreams は NVIDIA の内部パイプラインであり、一般公開は限定的
- Cosmos API の利用にはアクセス権が必要
- リアルタイム変換は非対応（バッチ処理のみ）

## 6. このプロジェクトへの適用可能性

### 6.1 現在のパイプラインとの統合

このプロジェクトの Visuomotor パイプラインは Cosmos 拡張と自然に統合できる:

```
現在のパイプライン:
  generate.sh visuomotor → train.sh visuomotor

Cosmos 拡張パイプライン:
  generate.sh visuomotor → [HDF5→MP4] → [Cosmos Transfer] → [MP4→HDF5] → train.sh visuomotor
```

### 6.2 必要なリソース

| リソース | 要件 |
|---------|------|
| Cosmos API アクセス | NVIDIA Build Platform のアカウントと API キー |
| ストレージ | 元データの 2-5 倍（複数のバリエーション生成時） |
| 処理時間 | API 依存（バッチサイズと待ち時間による） |
| ネットワーク | API 呼び出しのためのインターネット接続 |

### 6.3 実装ロードマップ

1. **Phase 1**: 現在の Visuomotor パイプラインを完成させる（Cosmos なし）
2. **Phase 2**: Cosmos Transfer API のアクセスを取得
3. **Phase 3**: HDF5 ↔ MP4 変換スクリプトを実装
4. **Phase 4**: Cosmos 拡張パイプラインを統合
5. **Phase 5**: 拡張あり/なしの比較実験を実施

### 6.4 注意事項

- Cosmos Transfer API は **クラウドベース** であり、オンプレミスでの実行にはエンタープライズ契約が必要な場合がある
- データのプライバシーポリシーを確認すること（合成データの外部送信）
- API の利用料金と制限を事前に確認すること
- Isaac Sim 5.0+ 以降の CosmosWriter が最も統合が容易
