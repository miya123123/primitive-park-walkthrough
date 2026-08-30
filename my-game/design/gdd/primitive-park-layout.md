# Primitive Park Layout

## Overview

外部アセットを使わず、JSON配置データからプリミティブメッシュだけで遊園地を生成するシステムです。入口、中央広場、舗装路、境界、樹木、5施設を72m四方に配置します。

## Player Fantasy

遠くから見える大きなシルエットを目標に歩き、近づくほど色と形の組み合わせが分かる、手作り遊園地の散策感を提供します。

## Detailed Rules

- 園内のプレイ領域はX/Z各方向`-24m`から`24m`までとする。
- 入口は南側、プレイヤー初期位置は入口の内側とする。
- 中央広場から3施設へ舗装路を接続する。
- 固定構造物には表示形状と一致する衝突形状を付ける。
- すべての表示メッシュはBoxMesh、CylinderMesh、SphereMesh、CapsuleMeshのいずれかとする。
- 色はStandardMaterial3Dのalbedo_colorで指定する。

## Formulas

- `half_extent = world_size / 2`
- `boundary_position = ±half_extent`
- 樹木や施設の配置はJSONのローカルX/Z座標を園内原点へ加算する。

## Edge Cases

- JSONの施設数が3未満、座標が境界外、速度が負の場合は起動をエラーにする。
- 動く部品には衝突を付けず、固定支柱と境界だけを衝突対象にする。
- 配置が重なってもプレイヤーの初期位置と入口は遮らない。

## Dependencies

Park Configuration、Primitive Factory、Third-Person Movement、Landmark Guidance、Ride Interaction。

## Tuning Knobs

`world_size`、`boundary_height`、施設位置、施設色、トリガー半径、乗り場位置、降車位置、乗り場半径、道幅、樹木位置。

## Acceptance Criteria

- 3施設がJSONの順序と座標で生成される。
- 3施設の乗り場Area3D、座席アンカー、降車マーカーがJSON位置から生成される。
- 入口から中央広場、各施設へ歩ける道がある。
- 見える3施設がすべてプリミティブ形状である。
- プレイヤーが境界から出ない。
