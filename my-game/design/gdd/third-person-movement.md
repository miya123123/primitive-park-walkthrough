# Third-Person Movement

## Overview

PCキーボード／マウスで、プレイヤーが72m四方の園内を中央背面追従の三人称視点で歩く移動システムです。CharacterBody3DとJolt物理を使い、地面・柵・施設との衝突を保ちながら、歩行・ダッシュ・ジャンプを提供します。

## Player Fantasy

色鮮やかなプリミティブ製の来園者を見ながら、自分の足で遊園地を巡り、見たい施設へ軽快に向かえる体験を実現します。

## Detailed Rules

- WASDはカメラの水平Yawを基準に前後左右へ移動する。
- マウスの水平移動でカメラYaw、垂直移動でカメラPitchを回転する。
- プレイヤーモデルは移動方向へ滑らかに向き、入力がないと最後の向きを保つ。
- SpringArm3Dはプレイヤー自身を除外し、柵・施設へ接近したときだけカメラ距離を短くする。
- Spaceは接地中だけジャンプする。
- Shift押下中は歩行速度にダッシュ倍率を掛ける。
- Escでマウスを解放し、左クリックで再捕捉する。
- Ride Interactionから乗車を開始すると座席へ追従し、降車イベントで通常の移動へ戻る。
- 園内境界の外へ出たり、床をすり抜けたりしない。

## Formulas

- `horizontal_velocity = normalized(input_direction) × camera_yaw_basis × speed`
- `vertical_velocity_next = vertical_velocity - gravity × delta`
- 接地中にジャンプ入力がある場合、`vertical_velocity = jump_velocity`。
- `model_yaw = target_yaw(move_direction)` を `turn_speed` で補間する。

## Edge Cases

- 入力が斜めでも速度が歩行速度を超えない。
- マウスを解放中は視点が動かない。
- Pitchは設定された下限・上限を超えず、カメラが反転しない。
- カメラが壁へめり込まず、プレイヤー自身を遮蔽物として扱わない。
- 境界へ走り込んでもCharacterBody3Dの衝突で停止する。
- 施設の動く装飾部品はプレイヤーを押し出さない。

## Dependencies

Park Configuration、Primitive Factory、Godot InputMap、SpringArm3D、Jolt Physics、Ride Interaction。

## Tuning Knobs

`walk_speed`、`sprint_multiplier`、`jump_velocity`、`gravity`、`mouse_sensitivity`、`camera_min_pitch_degrees`、`camera_max_pitch_degrees`、`camera_pivot_height`、`camera_distance`、`camera_collision_radius`、`camera_collision_margin`、`turn_speed`、`walk_cycle_speed`、`sprint_cycle_speed`、`limb_swing_degrees`、`ride_arm_pose_degrees`、`ride_leg_pose_degrees`、`ride_ground_height_limit`。

## Acceptance Criteria

- 起動後にプリミティブ製来園者と園内が同時に見える。
- WASD、マウス旋回、Space、Shift、Escが指定どおり動作する。
- 移動方向へモデルが向き、歩行・ダッシュ・ジャンプで姿勢が変わる。
- カメラが柵・施設に接近しても遮蔽を回避し、境界の外へ出られない。
- 斜め移動が過速にならず、三施設へ徒歩で到達できる。
