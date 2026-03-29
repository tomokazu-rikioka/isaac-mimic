# 新しいロボット（SO-ARM100 等）の追加方法

## 1. 概要

Isaac Lab Mimic は任意のロボットでデータ生成可能。新しいロボットを追加するには以下が必要:

1. **ロボットモデル**（URDF / MJCF → USD）
2. **ArticulationCfg**（ロボットの物理設定）
3. **Mimic 環境定義**（タスク、サブタスク、観測・行動空間）
4. **タスク登録**（Gymnasium への登録）

所要工数の目安: 簡単なマニピュレータ（SO-ARM100 等）で 1〜3 日程度。

## 2. ロボットモデルの準備

### 2.1 URDF の入手

ロボットの URDF（Unified Robot Description Format）を入手する。

**入手先の例**:
- メーカー提供の公式 URDF
- GitHub リポジトリ（ROS パッケージ内に多い）
- 自作（SolidWorks → URDF エクスポート等）

**SO-ARM100 の場合**:
- TheRobotStudio が提供する 6DOF 小型ロボットアーム（5関節 + 1グリッパー）
- URDF は LeRobot プロジェクト等から入手可能

### 2.2 URDF → USD 変換

Isaac Lab は URDF を直接 USD（Universal Scene Description）に変換できる:

```bash
# Isaac Lab の変換スクリプト
./isaaclab.sh -p scripts/tools/convert_urdf.py \
    --input_file /path/to/robot.urdf \
    --output_file /path/to/robot.usd \
    --fix_base  \
    --merge_fixed_joints
```

**主要オプション**:

| オプション | 説明 | 推奨値 |
|-----------|------|--------|
| `--fix_base` | ベースリンクを固定 | マニピュレータは `true` |
| `--merge_fixed_joints` | 固定ジョイントを結合（計算量削減） | `true` |
| `--joint_drive` | ジョイント制御タイプ | `position` or `velocity` |
| `--make_instanceable` | インスタンス化対応（並列環境用） | `true` |

**変換時の注意点**:
- `<gazebo>`, `<transmission>` タグは URDF から除去（Isaac Sim 非対応）
- メッシュファイル（STL/OBJ/DAE）のパスが正しいか確認
- コリジョンメッシュとビジュアルメッシュの両方を含めること

### 2.3 MJCF → USD 変換

MuJoCo 形式の場合:

```bash
./isaaclab.sh -p scripts/tools/convert_mjcf.py \
    --input_file /path/to/robot.xml \
    --output_file /path/to/robot.usd
```

### 2.4 変換結果の確認

Isaac Sim で USD ファイルを開いて確認:
- ジョイントの回転方向が正しいか
- コリジョンメッシュが適切か
- リンクの親子関係が正しいか

## 3. ArticulationCfg の定義

ロボットの物理パラメータを `ArticulationCfg` として定義する。最低限必要なのは **spawn 設定** と **actuators 辞書** の2つ。

### 3.1 基本構成

```python
from isaaclab.assets import ArticulationCfg
from isaaclab.actuators import ImplicitActuatorCfg

SO_ARM100_CFG = ArticulationCfg(
    # --- スポーン設定 ---
    spawn=sim_utils.UsdFileCfg(
        usd_path="/path/to/so_arm100.usd",
        activate_contact_sensors=True,
        rigid_props=sim_utils.RigidBodyPropertiesCfg(
            disable_gravity=False,
            max_depenetration_velocity=5.0,
        ),
        articulation_props=sim_utils.ArticulationRootPropertiesCfg(
            enabled_self_collisions=True,
            solver_position_iteration_count=8,
            solver_velocity_iteration_count=0,
        ),
    ),

    # --- 初期状態 ---
    init_state=ArticulationCfg.InitialStateCfg(
        pos=(0.0, 0.0, 0.0),  # ロボットの初期位置
        joint_pos={
            "joint_1": 0.0,
            "joint_2": -1.0,
            "joint_3": 0.5,
            "joint_4": 0.0,
            "joint_5": 0.5,
            "gripper": 0.04,   # グリッパー開状態
        },
    ),

    # --- アクチュエータ設定 ---
    actuators={
        "arm": ImplicitActuatorCfg(
            joint_names_expr=["joint_[1-5]"],  # 正規表現で指定
            stiffness=100.0,
            damping=10.0,
            effort_limit=50.0,
        ),
        "gripper": ImplicitActuatorCfg(
            joint_names_expr=["gripper"],
            stiffness=200.0,
            damping=20.0,
            effort_limit=20.0,
        ),
    },
)
```

### 3.2 スポーン設定の詳細

| プロパティ | 説明 |
|-----------|------|
| `usd_path` | USD アセットのファイルパス |
| `activate_contact_sensors` | 接触センサーの有効化 |
| `rigid_props` | 剛体の物理プロパティ（重力、貫通速度等） |
| `articulation_props` | 関節系のプロパティ（自己衝突、ソルバー設定等） |

### 3.3 アクチュエータの種類

| アクチュエータ | 説明 | 用途 |
|--------------|------|------|
| `ImplicitActuatorCfg` | PD 制御ベースの暗黙アクチュエータ | 一般的なロボットアーム |
| `DCMotorCfg` | DC モーターモデル | より物理的に正確な制御 |
| `IdealPDActuatorCfg` | 理想的な PD コントローラ | シンプルな実験向け |

**パラメータ調整のコツ**:
- **stiffness（剛性）**: 高いほど目標位置への追従が速い。高すぎると振動する
- **damping（減衰）**: 高いほど動きが滑らか。高すぎると応答が遅い
- **effort_limit（トルク限界）**: ロボットの物理仕様に合わせて設定

## 4. Mimic 環境の定義

### 4.1 環境クラスの作成

`ManagerBasedRLMimicEnv` を継承してカスタム環境を定義する:

```python
from isaaclab_mimic.envs import ManagerBasedRLMimicEnv

class SOArm100PickPlaceMimicEnv(ManagerBasedRLMimicEnv):
    """SO-ARM100 でピック＆プレースを行う Mimic 環境"""

    def get_robot_eef_pose(self):
        """エンドエフェクタの現在姿勢を [4, 4] 変換行列で返す"""
        ee_pos = self.scene["robot"].data.body_pos_w[:, self.ee_body_idx]
        ee_rot = self.scene["robot"].data.body_quat_w[:, self.ee_body_idx]
        return pose_to_matrix(ee_pos, ee_rot)

    def target_eef_pose_to_action(self, target_pose):
        """目標エンドエフェクタ姿勢をアクション（制御コマンド）に変換"""
        current_pose = self.get_robot_eef_pose()
        delta = compute_pose_delta(current_pose, target_pose)
        return delta

    def get_subtask_term_signals(self):
        """各サブタスクの終了信号を返す（バッチ × サブタスク数）"""
        signals = {}
        signals["grasp"] = self._check_object_grasped()
        signals["place"] = self._check_object_placed()
        return signals

    def get_subtask_start_signals(self):
        """各サブタスクの開始信号を返す（SkillGen 用）"""
        signals = {}
        signals["grasp"] = self._check_near_object()
        signals["place"] = self._check_object_grasped()
        return signals
```

### 4.2 シーン設定

```python
from isaaclab.scene import InteractiveSceneCfg

class SOArm100PickPlaceSceneCfg(InteractiveSceneCfg):
    # ロボット
    robot = ArticulationCfg(
        prim_path="{ENV_REGEX_NS}/Robot",
        spawn=...,
        actuators=...,
    )

    # テーブル
    table = AssetBaseCfg(
        prim_path="{ENV_REGEX_NS}/Table",
        spawn=sim_utils.UsdFileCfg(usd_path="..."),
    )

    # 操作対象オブジェクト
    cube = RigidObjectCfg(
        prim_path="{ENV_REGEX_NS}/Cube",
        spawn=sim_utils.CuboidCfg(
            size=(0.04, 0.04, 0.04),
            rigid_props=...,
        ),
    )

    # カメラ（Visuomotor の場合）
    camera = CameraCfg(
        prim_path="{ENV_REGEX_NS}/Camera",
        ...
    )
```

> `{ENV_REGEX_NS}` は並列環境の複製時に自動的に置換される特殊パターン。

### 4.3 サブタスクの定義

```python
from isaaclab_mimic.envs import SubTaskConfig, MimicEnvCfg

class SOArm100PickPlaceMimicCfg(MimicEnvCfg):
    subtasks = [
        SubTaskConfig(
            name="grasp",
            object_ref="cube",      # 変換基準のオブジェクト
        ),
        SubTaskConfig(
            name="place",
            object_ref="target",     # 変換基準のオブジェクト
        ),
    ]
```

**サブタスク設計のポイント**:
- タスクを意味のある部分動作に分割する
- 各サブタスクには明確な終了条件を設定する
- `object_ref` はそのサブタスクで操作の基準となるオブジェクトを指定
- サブタスク間の遷移は Mimic が自動的に補間する

## 5. タスクの登録

### 5.1 Gymnasium への登録

```python
import gymnasium as gym

# 基本タスク（State-based 学習用）
gym.register(
    id="Isaac-PickPlace-SOArm100-IK-Rel-v0",
    entry_point="my_package.envs:SOArm100PickPlaceEnv",
    kwargs={"env_cfg": SOArm100PickPlaceCfg()},
)

# Mimic タスク（アノテーション・生成用）
gym.register(
    id="Isaac-PickPlace-SOArm100-IK-Rel-Mimic-v0",
    entry_point="my_package.envs:SOArm100PickPlaceMimicEnv",
    kwargs={"env_cfg": SOArm100PickPlaceMimicCfg()},
)

# SkillGen タスク（GPU モーション計画生成用）
gym.register(
    id="Isaac-PickPlace-SOArm100-IK-Rel-Skillgen-v0",
    entry_point="my_package.envs:SOArm100PickPlaceSkillgenEnv",
    kwargs={"env_cfg": SOArm100PickPlaceSkillgenCfg()},
)

# Visuomotor タスク（カメラ付き生成用）
gym.register(
    id="Isaac-PickPlace-SOArm100-IK-Rel-Visuomotor-Mimic-v0",
    entry_point="my_package.envs:SOArm100PickPlaceMimicEnv",
    kwargs={"env_cfg": SOArm100PickPlaceVisuomotorMimicCfg()},
)
```

### 5.2 推奨ディレクトリ構造

```
my_isaac_lab_extension/
├── __init__.py
├── envs/
│   ├── __init__.py
│   ├── so_arm100_pick_place.py       # 環境定義
│   └── so_arm100_pick_place_cfg.py   # 設定クラス
├── assets/
│   └── so_arm100/
│       ├── so_arm100.usd
│       └── so_arm100.urdf
└── config/
    └── so_arm100_pick_place.yaml
```

## 6. テレオペレーションの設定

### 6.1 キーボードテレオペ

Isaac Lab のキーボードテレオペは IK（逆運動学）制御をベースにしている:

```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/record_demos.py \
    --task Isaac-PickPlace-SOArm100-IK-Rel-Mimic-v0 \
    --teleop_device keyboard \
    --num_demos 10
```

**キーマッピング**（デフォルト）:
- W/S: 前後移動
- A/D: 左右移動
- Q/E: 上下移動
- Arrow keys: 回転
- Space: グリッパー開閉

### 6.2 SpaceMouse テレオペ（推奨）

6DOF 入力デバイスで、より直感的な操作が可能:

```bash
./isaaclab.sh -p scripts/imitation_learning/isaaclab_mimic/record_demos.py \
    --task Isaac-PickPlace-SOArm100-IK-Rel-Mimic-v0 \
    --teleop_device spacemouse \
    --num_demos 10
```

### 6.3 デモ収集のコツ

- **短く直線的な動作**: 余計な動きを避け、最短経路でタスクを完了
- **スムーズな動き**: 急な方向転換を避ける
- **一定速度**: 速すぎず遅すぎず
- **5〜10本のデモ**: Mimic に十分な多様性を提供しつつ、収集コストを抑える

## 7. 参考: SO-ARM101 の実装例

[MuammerBay/isaac_so_arm101](https://github.com/MuammerBay/isaac_so_arm101) が SO-ARM101 の Isaac Lab 実装を公開している。

**含まれる内容**:
- SO-ARM101 の ArticulationCfg
- キューブスタッキング、ピック＆プレース、ペグ挿入、ギア組立タスク
- RSL-RL を使った強化学習の学習設定
- 評価スクリプト

**Isaac Lab Mimic への拡張ポイント**:
- `ManagerBasedRLMimicEnv` の継承クラスを追加
- SubTaskConfig でサブタスク境界を定義
- SkillGen 用の環境バリアントを登録

## 8. データ合成のフルワークフロー

新しいロボットでのデータ合成の全体フロー:

```
[1. URDF/MJCF 入手]
    ↓
[2. USD 変換 + Isaac Sim で確認]
    ↓
[3. ArticulationCfg 定義]
    ↓
[4. Mimic 環境定義 (ManagerBasedRLMimicEnv)]
    ↓
[5. サブタスク定義 (SubTaskConfig)]
    ↓
[6. Gymnasium 登録]
    ↓
[7. テレオペレーションでデモ収集 (5-10 本)]
    ↓
[8. アノテーション (annotate_demos.py)]
    ↓
[9. 合成デモ生成 (generate_dataset.py)]
    ↓
[10. ポリシー学習 (robomimic train.py)]
    ↓
[11. 評価 (play.py)]
```

## 9. トラブルシューティング

### USD モデルの表示がおかしい

- URDF のメッシュファイルパスが正しいか確認
- スケールの不一致（mm vs m）を確認
- `--merge_fixed_joints` でリンクが不適切に結合されていないか確認

### ジョイント制御が不安定

- `stiffness` と `damping` のバランスを調整
- `effort_limit` がロボットの実際のトルク範囲に合っているか確認
- シミュレーションタイムステップ（`dt`）が十分に小さいか確認

### アノテーションが正しく動作しない

- `get_subtask_term_signals()` が正しい信号を返しているか確認
- 各サブタスクの終了条件が全デモで一貫しているか確認
- デバッグ: アノテーション後の HDF5 を開いて `subtask_term_signals` を可視化

### 生成されたデモの品質が低い

- 入力デモの品質を確認（スムーズか、成功しているか）
- サブタスクの分割が適切か再検討
- 並列環境数を減らして GPU メモリの安定性を確保
- `--generation_num_trials` を増やして成功率の分母を増やす
