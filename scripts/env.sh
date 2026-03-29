#!/bin/bash
# 共通環境変数定義
# 他のスクリプトから source して使用する

MIMIC_DIR="/workspace/isaac-mimic"
ISAACLAB_DIR="/workspace/isaaclab"
PYTHON="${ISAACLAB_DIR}/_isaac_sim/kit/python/bin/python3"
ISAACLAB_SH="${ISAACLAB_DIR}/isaaclab.sh"
BASE_IMAGE="nvcr.io/nvidia/isaac-lab:2.3.2"
IMAGE="isaac-lab-mimic:2.3.2"
