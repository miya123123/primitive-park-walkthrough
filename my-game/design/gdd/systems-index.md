# Systems Index

## Foundation

| System | Description | Priority | Status |
|---|---|---|---|
| Engine and Input Setup | Godot 4.6.2、Forward+、Jolt、PC入力 | MVP | Complete |
| Park Configuration | JSONから園内サイズ、配置、速度、色を読む | MVP | Complete |
| Primitive Factory | 衝突付きプリミティブと色付きマテリアルを生成 | MVP | In Progress |

## Core

| System | Description | Priority | Status |
|---|---|---|---|
| Third-Person Movement | CharacterBody3Dによる歩行、ジャンプ、ダッシュ、追従カメラ | MVP | In Progress |
| Park Layout | 道、境界、入口、樹木、3施設を生成 | MVP | In Progress |
| Attraction Motion | 3施設の自動回転とコースター車両周回 | MVP | In Progress |
| Ride Interaction | Eキーで次回到着を待つ1周乗車と自動降車 | MVP | Complete |
| Ride Expansion | フリーフォールの落下前演出とゴーカート3周タイムアタック | MVP | Complete |

## Presentation

| System | Description | Priority | Status |
|---|---|---|---|
| Landmark Guidance | 案内板、検出エリア、現在位置イベント | MVP | In Progress |
| Minimal HUD | 操作説明、現在位置バナー | MVP | In Progress |
| Daylight Look | Procedural Sky、DirectionalLight3D、明るい配色 | MVP | In Progress |

## Dependency Order

```text
Park Configuration -> Primitive Factory -> Park Layout
Park Configuration -> Third-Person Movement
Park Layout -> Attraction Motion
Attraction Motion -> Ride Interaction
Ride Interaction -> Ride Expansion
Park Layout -> Landmark Guidance -> Minimal HUD
Ride Interaction -> Minimal HUD
Engine and Input Setup -> all runtime systems
```

## High-Risk Items

- Godot 4.6.2のJolt設定とCharacterBody3Dの衝突挙動。
- 実行時に生成する施設の視認性と、プリミティブだけでのシルエット表現。
