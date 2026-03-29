"""Domain Randomization 設定

Isaac Lab の EventTermCfg を使って環境のランダム化を定義する。
学習時に --dr フラグを指定した場合にこの設定が適用される。

参考: Isaac Lab の既存環境設定
  - isaaclab/source/isaaclab_tasks/isaaclab_tasks/manager_based/manipulation/stack/config/
"""

# NOTE: この設定は Isaac Lab の環境設定クラス内で使用する。
# 現時点では設定の定義のみ。実際の環境への適用は、Isaac Lab の
# EventTermCfg を継承したカスタム環境クラスで行う必要がある。
#
# Isaac Lab 標準の Stack Cube 環境にDRを追加するには、
# 環境設定クラスの events セクションをオーバーライドする。

# --- 物理パラメータのランダム化 ---
PHYSICS_RANDOMIZATION = {
    "friction": {
        "range": [0.5, 1.5],
        "description": "オブジェクトの摩擦係数",
    },
    "mass_scale": {
        "range": [0.8, 1.2],
        "description": "オブジェクトの質量スケール",
    },
    "restitution": {
        "range": [0.0, 0.3],
        "description": "反発係数",
    },
}

# --- オブジェクト配置のランダム化 ---
POSE_RANDOMIZATION = {
    "object_position_xy": {
        "range": [-0.05, 0.05],
        "description": "オブジェクトXY位置のオフセット (m)",
    },
    "object_rotation_z": {
        "range": [-3.14, 3.14],
        "description": "オブジェクトZ軸回転 (rad)",
    },
}

# --- 視覚的ランダム化（Visuomotor用） ---
VISUAL_RANDOMIZATION = {
    "light_intensity": {
        "range": [0.5, 2.0],
        "description": "照明強度のスケール",
    },
    "light_color_temperature": {
        "range": [3000, 8000],
        "description": "照明の色温度 (K)",
    },
    "object_color_hsv": {
        "hue_range": [-0.1, 0.1],
        "saturation_range": [-0.2, 0.2],
        "description": "オブジェクト色のHSV変動",
    },
    "table_texture": {
        "enabled": True,
        "description": "テーブルテクスチャのランダム変更",
    },
    "camera_fov": {
        "range": [-2.0, 2.0],
        "description": "カメラFOVの変動 (degrees)",
    },
}

# --- 制御ノイズ ---
ACTION_NOISE = {
    "position_noise": {
        "range": [-0.002, 0.002],
        "description": "アクション位置ノイズ (m)",
    },
    "rotation_noise": {
        "range": [-0.01, 0.01],
        "description": "アクション回転ノイズ (rad)",
    },
}


def get_dr_config(policy_type: str = "state") -> dict:
    """ポリシータイプに応じたDR設定を返す。

    Args:
        policy_type: "state" or "visuomotor"

    Returns:
        DR設定の辞書
    """
    config = {
        "physics": PHYSICS_RANDOMIZATION,
        "pose": POSE_RANDOMIZATION,
        "action_noise": ACTION_NOISE,
    }

    if policy_type == "visuomotor":
        config["visual"] = VISUAL_RANDOMIZATION

    return config
