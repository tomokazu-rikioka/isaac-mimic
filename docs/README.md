# Isaac Lab Mimic ドキュメント

## このドキュメントについて

Isaac Lab Mimic を使った模倣学習用合成データ生成に関する包括的なドキュメントです。

**対象読者**: Isaac Lab Mimic を使った模倣学習に興味がある研究者・エンジニア

**前提知識**:
- Python の基本操作
- ロボティクスの基礎（マニピュレーション、運動学）
- Docker の基本操作
- 機械学習の基本概念（Behavioral Cloning 等）

## 目次

| # | ドキュメント | 内容 |
|---|------------|------|
| 1 | [Isaac Lab Mimic の全体像とチュートリアル](./01_isaac_lab_mimic_overview.md) | 概念、6ステップワークフロー、SkillGen、HDF5 データ構造 |
| 2 | [Mimic でできること（機能一覧）](./02_features.md) | デモ生成、対応ロボット・タスク、ポリシー学習、Domain Randomization |
| 3 | [プロジェクトセットアップと実行手順](./03_project_setup.md) | このリポジトリのセットアップ、12条件実験マトリクス、Slurm ジョブ |
| 4 | [カメラ・画像データの扱い方](./04_camera_and_vision.md) | Visuomotor 対応、カメラセンサー、画像データの生成・学習 |
| 5 | [新しいロボットの追加方法](./05_new_robot_integration.md) | URDF→USD 変換、ArticulationCfg、SO-ARM100 の具体例 |
| 6 | [NVIDIA Cosmos との連携](./06_cosmos_integration.md) | CosmosWriter、Cosmos Transfer、GR00T-Dreams |
| 7 | [参考リンク集](./07_references.md) | 公式ドキュメント、論文、ブログ、リポジトリ |

## クイックリンク

- **今すぐ実験を始めたい** → [プロジェクトセットアップ](./03_project_setup.md)
- **カメラデータを使いたい** → [カメラ・画像データ](./04_camera_and_vision.md)
- **別のロボットで試したい** → [新しいロボットの追加](./05_new_robot_integration.md)
- **Cosmos でデータ拡張したい** → [Cosmos 連携](./06_cosmos_integration.md)
- **リンクだけ知りたい** → [参考リンク集](./07_references.md)
