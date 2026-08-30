# ADR-0003: 乗り場同期型の1周乗車

## Status

Accepted

## Date

2026-08-27

## Last Verified

2026-08-28

## Decision Makers

ユーザー、実装エージェント

## Summary

既存の自動演出だけでは施設を「乗れる」体験にできないため、乗り物の位相を保ったまま乗り場到着を待つ仕組みを追加する。`AttractionAnimator`が車両位相を所有し、`RideCoordinator`が単一プレイヤーの予約・着座・自動降車をイベントで調整する。

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Input / Physics / Animation / UI |
| Knowledge Risk | HIGH — 4.6は学習カットオフ後 |
| References Consulted | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| Post-Cutoff APIs Used | 既存の`Area3D`、`CharacterBody3D`、`set_deferred`のみ |
| Verification Required | 3施設の実乗車、座席追従、1周完了、自動降車、衝突復元 |

## ADR Dependencies

| Field | Value |
|---|---|
| Depends On | ADR-0001 JSON駆動のプリミティブ遊園地生成、ADR-0002 三人称プレイヤーと追従カメラ |
| Enables | 既存3施設のインタラクティブ乗車 |
| Blocks | EPIC-001-S06 Ride Interaction |
| Ordering Note | JSON配置、座席アンカー、PlayerControllerの着座APIを先に用意する。 |

## Context

### Problem Statement

観覧車、コースター、カルーセルは現在動いているが、プレイヤーが乗車できず、施設を見つけるだけで体験が終わる。

### Current State

`AttractionAnimator`が3施設を常時更新し、`ParkBuilder`が案内エリアだけを生成している。プレイヤーは常に歩行状態で、移動ノードと座席の関係がない。

### Constraints

- 外部モデル、画像テクスチャ、音声、追加アドオンを使用しない。
- 72m四方、Godot 4.6.2、Jolt Physics、既存の三人称カメラを維持する。固有の手動運転・落下演出はADR-0004で拡張する。
- 1人用で、乗り物の操縦や任意途中降車は対象外とする。

### Requirements

- Eで次回の乗り場到着を予約できる。
- 各施設を1周した後に安全地点へ自動降車する。
- 乗車中のHUDは信号で更新し、プレイヤーの衝突と歩行を復元する。

## Decision

`AttractionAnimator`に施設ごとの位相、待機、乗車中状態を持たせ、位相境界を跨いだときだけ`station_ready`または`cycle_completed`を発行する。`RideCoordinator`は乗り場Area3D、単一プレイヤー、座席アンカー、降車マーカーを接続し、次の状態を管理する。

```text
PlayerController --interact_requested--> RideCoordinator
       ^                                      |
       | begin_ride / finish_ride             | request_boarding / begin_cycle
       |                                      v
       +----------- station_ready / cycle_completed -- AttractionAnimator
                              |
                              v
                         ParkBuilder nodes
```

### Key Interfaces

- `PlayerController.interact_requested()`
- `PlayerController.can_start_ride() -> bool`
- `PlayerController.begin_ride(ride_id, seat_anchor, exit_marker) -> bool`
- `PlayerController.finish_ride(exit_marker) -> void`
- `AttractionAnimator.request_boarding(ride_id) -> bool`
- `AttractionAnimator.begin_cycle(ride_id) -> bool`
- `AttractionAnimator.station_ready(ride_id)` / `cycle_completed(ride_id)`
- `RideCoordinator.ride_prompt_changed(state, display_name)`

### Implementation Guidelines

- 乗車予約は現在の位相をリセットせず、次の周期境界まで通常演出を続ける。
- 座席や動く車両には衝突を付けず、固定支柱・床・境界だけを衝突対象にする。
- HUDは`ride_prompt_changed`だけを購読し、毎フレームPlayerControllerを参照しない。
- 車両の速度、判定半径、座席・降車位置、着座姿勢はJSONから読む。

## Alternatives Considered

### Alternative 1: E押下時に即時テレポート

- Pros: 実装が短く、待ち時間がない。
- Cons: 動く座席との連続性がなく、視覚的に不自然。
- Rejection Reason: 次回到着を待つという乗車仕様に反する。

### Alternative 2: プレイヤーが乗り物を操縦

- Pros: 操作の自由度が高い。
- Cons: 入力・安全・カメラ・衝突の範囲が大きく広がる。
- Rejection Reason: ウォークスルーの短時間体験と1周自動運行を優先する。

## Consequences

### Positive

- 3施設すべてで、歩いて見つける体験と乗って見る体験がつながる。
- 1周完了と衝突復元を自動化でき、プレイヤーが迷いにくい。
- 位相とUIイベントをテストで再現できる。

### Negative

- 観覧車の1周は約28.6秒で、待機時間が発生する場合がある。
- 車両の座席アンカーと降車地点を施設ごとに維持する必要がある。

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 座席位置の見た目ずれ | Medium | Medium | 実画面で3施設の着座姿勢を確認し、JSONオフセットで調整する。 |
| 乗車中の衝突状態が残る | Low | High | 統合テストで無効化・復元を明示検証する。 |
| 長い待機で操作が分かりにくい | Medium | Low | 到着待ちをHUDに表示し、エリア外でキャンセルする。 |

## Performance Implications

- CPU: 既存の単一アニメータに位相判定を追加し、目標60 FPSの範囲内に収める。
- Memory: 3施設分の小さな辞書と座席ノードのみ追加する。
- Draw calls: 既存のプリミティブ制約と250以下の目標を維持する。

## Migration Plan

1. JSONへ乗り場・降車・姿勢値を追加し、`ParkConfig.validate`で検証する。
2. `ParkBuilder`に座席、乗り場Area3D、降車Marker3Dを追加する。
3. `AttractionAnimator`、`RideCoordinator`、`PlayerController`、HUDを接続する。
4. 既存テスト、クリーンコピー、実画面QAを順に実行する。

**Rollback plan**: 乗車システム接続を外し、従来の`AttractionAnimator.advance_time`と徒歩入力へ戻す。生成された乗車ノードは`ParkBuilder`の変更と同時に戻せる。

## Validation Criteria

- 3施設すべてで次回到着待ちから1周、自動降車まで成功する。
- 乗車中に三人称カメラが動き、降車後に衝突とWASDが復元する。
- 通常・クリーンコピーのテストが終了コード0で完了する。

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/ride-interaction.md` | Ride Interaction | 3施設をEで1周乗車し自動降車する | 位相境界イベント、座席アンカー、単一プレイヤー状態で実装する。 |
| `design/gdd/third-person-movement.md` | Third-Person Movement | 乗車中も視点を維持し、降車後に歩行へ戻る | PlayerControllerがカメラを保持し、衝突と入力を状態遷移で復元する。 |

## Related

- `docs/architecture/adr-0001-procedural-primitive-park.md`
- `docs/architecture/adr-0002-third-person-player-camera.md`
- `src/gameplay/attraction_animator.gd`
- `src/gameplay/ride_coordinator.gd`
