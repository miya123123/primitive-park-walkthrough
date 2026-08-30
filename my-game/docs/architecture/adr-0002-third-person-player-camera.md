# ADR-0002: プリミティブ来園者モデルと三人称追従カメラ

## Status

Accepted

## Date

2026-08-26

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Gameplay / Rendering / Physics / Input |
| References Consulted | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `modules/physics.md`, Godot SpringArm3D reference |
| Post-Cutoff APIs Used | `SpringArm3D.spring_length`, spherical shape cast, `add_excluded_object` |
| Verification Required | Headless tests, camera obstruction test, real-window playtest and screenshots |

## Context

既存のPrimitive Parkは、CharacterBody3Dを中心にした一人称ウォークスルーでした。遊園地を歩くプレイヤー自身の姿が見えず、施設のスケールや歩行アニメーションを楽しみにくいため、外部アセットを追加せず三人称視点へ移行します。

## Constraints

- 外部3Dモデル、画像テクスチャ、音声、アドオンを追加しない。
- プレイヤーの見た目もBoxMesh、CylinderMesh、SphereMesh、CapsuleMeshだけで構成する。
- 移動・カメラ・アニメーションの調整値は`assets/data/park_config.json`から注入する。
- 48m×48mの園内、Jolt Physics、既存の施設イベントと衝突契約を維持する。

## Decision

プレイヤーのCharacterBody3Dは位置と衝突だけを所有し、子ノードを次の責務に分けます。

```text
CharacterBody3D
├─ CollisionShape3D        # 既存のカプセル衝突
├─ VisualRoot               # プリミティブ来園者と手足のプロシージャル姿勢
└─ CameraYaw
   └─ CameraPitch
      └─ SpringArm3D
         └─ Camera3D         # 中央背面追従、遮蔽物で短縮
```

水平マウス入力はCameraYaw、垂直入力はCameraPitchだけを回転させます。WASDはCameraYawの水平Basisを使い、来園者モデルは移動方向へ補間回転します。SpringArm3Dからプレイヤー自身のRIDを除外し、球形状で園内ジオメトリを検知します。

## Key Interfaces

- `MovementMath.clamped_orbit_pitch(current, delta_pitch, sensitivity, min_pitch_degrees, max_pitch_degrees) -> float`
- `MovementMath.target_yaw(direction, fallback) -> float`
- `PlayerController.configure(settings) -> void`
- `PlayerController.apply_camera_motion(relative) -> void`
- `PlayerVisual.configure(settings) -> void`
- `PlayerVisual.update_motion(move_direction, horizontal_speed, grounded, sprinting, delta) -> void`

## Configuration Contract

`camera_min_pitch_degrees`、`camera_max_pitch_degrees`、`camera_default_pitch_degrees`は順序と範囲内の初期値を検証します。`camera_distance`、`camera_collision_radius`、`camera_collision_margin`、旋回・手足アニメーション値は正数として検証します。

## Alternatives Considered

### 一人称を残して切替式にする

既存体験は残せますが、カメラ・HUD・テスト・仕様が二重になり、今回の「モデルを見ながら歩く」目的がぼやけます。三人称専用を採用します。

### 固定距離のCamera3Dだけを使う

実装は簡単ですが、柵や施設の内部でカメラがめり込むため、SpringArm3Dの衝突短縮を採用します。

### 外部キャラクターモデルをインポートする

見た目は豊かになりますが、プリミティブ限定と再現性の制約に反します。コードネイティブのプリミティブモデルを採用します。

## Consequences

### Positive

- 背面から来園者と遊園地を同時に確認できる。
- カメラ基準移動とモデルの向きが一致し、操作意図が視覚化される。
- 外部アセットなしで歩行・ダッシュ・ジャンプの姿勢を表現できる。
- SpringArm3Dで壁際のカメラ遮蔽を自動的に緩和できる。

### Negative

- プリミティブモデルの表情や衣服の細部は限定される。
- カメラ距離とピッチの調整が一人称より増える。
- 手足アニメーションは骨格アニメーションではなく、少数のPivot回転による表現になる。

## Validation Criteria

- 設定・移動数学・シーン統合テストが全件PASSする。
- 来園者の全MeshInstance3Dが許可された4種類のMeshである。
- マウス旋回、カメラ基準WASD、モデル旋回、歩行／ダッシュ／ジャンプ姿勢を実入力で確認する。
- 壁際でSpringArm3Dの実効距離が短くなり、カメラがプレイヤー内部へ入らない。
- 実画面QA後にゲームプロセスを停止し、画面証跡を保存する。
