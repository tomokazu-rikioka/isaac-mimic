FROM nvcr.io/nvidia/isaac-lab:2.3.2

ENV DEBIAN_FRONTEND=noninteractive

# ユーティリティ
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg git curl wget \
    && rm -rf /var/lib/apt/lists/*

# uv のインストール
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Python パスの設定
ENV UV_PYTHON="/workspace/isaaclab/_isaac_sim/kit/python/bin/python3"

# toml と numpy の修復（isaaclab.sh --install が壊すことがある）
RUN uv pip install --system toml

# robomimic（模倣学習フレームワーク）のインストール
RUN uv pip install --system robomimic

# cuRobo（SkillGen用GPU高速モーション計画）のインストール
# Isaac Lab と互換性のあるバージョンに固定
RUN export TORCH_CUDA_ARCH_LIST="8.0+PTX" && \
    uv pip install --system -e \
    "git+https://github.com/NVlabs/curobo.git@ebb71702f3f70e767f40fd8e050674af0288abe8#egg=nvidia-curobo" \
    --no-build-isolation

# numpy の再インストール（依存関係解決後）
RUN uv pip install --system numpy

# プロジェクトファイルのコピー
COPY configs /workspace/isaac-mimic/configs
COPY scripts /workspace/isaac-mimic/scripts

WORKDIR /workspace/isaac-mimic

ENTRYPOINT []
CMD ["bash"]
