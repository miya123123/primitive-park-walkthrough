# ADR-0004: 乗り物プロバイダによる固有体験の分離

## Status

Accepted

## Context

既存の観覧車、ジェットコースター、メリーゴーラウンドは`AttractionAnimator`が位相を進め、`RideCoordinator`が次回到着と1周自動降車を調整している。フリーフォールは落下前のランダム待機を含む段階的な状態機械、ゴーカートはプレイヤー入力・衝突・チェックポイント・記録保存を必要とするため、既存アニメータへ条件分岐を集中させると乗り物固有の責務が混ざる。

## Decision

`ride_provider.gd`を共通契約とし、`FreeFallController`と`GoKartController`を個別プロバイダとして実装する。`AttractionAnimator`も同契約を継承し、既存3施設の挙動は維持する。`RideCoordinator`はプロバイダを乗り物IDへ登録し、以下の信号とメソッドだけを通じて単一プレイヤーの着座・退出を調整する。

- 信号: `station_ready(ride_id)`、`cycle_completed(ride_id)`、`progress_changed(ride_id, snapshot)`
- メソッド: `request_boarding`、`cancel_boarding`、`begin_cycle`、`abort_cycle`、`reset_cycle`、`get_ride_descriptor`、`get_ride_state`

フリーフォールの乱数は`RandomNumberGenerator`へ注入可能なシードを使い、ゴーカートのタイムは`ConfigFile`へ保存する。ゴーカートは`CharacterBody3D`、コース外周は固定バリアとし、プレイヤーの着座中だけPlayerControllerの衝突を無効化する。HUDは`RideCoordinator.ride_progress_changed`を購読し、毎フレームの内部状態ポーリングを行わない。

## Consequences

### Positive

- 自動運行、段階的落下、手動運転を同じ乗車リースへ接続できる。
- 乗り物固有の進捗と入力を個別テストでき、既存3施設の回帰範囲を小さく保てる。
- ゴーカートのHUD更新と記録保存をゲームプレイから分離して検証できる。

### Negative

- プロバイダの共通契約と5施設の登録情報を維持する必要がある。
- 3D物理、Area3D、ランダム待機、ファイル保存を含むため、純粋計算だけでは完結しない統合テストが必要になる。

## ADR Dependencies

- Depends On: `adr-0001-procedural-primitive-park.md`, `adr-0002-third-person-player-camera.md`, `adr-0003-ride-interaction.md`
- Enables: `design/gdd/ride-expansion.md`, `EPIC-001-S07`
- Supersedes: なし（ADR-0003の自動運行3施設を拡張する）

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Physics | Jolt / CharacterBody3D / Area3D |
| Rendering | Forward+、プリミティブメッシュのみ |
| References Consulted | `docs/engine-reference/godot/VERSION.md`, `modules/physics.md`, `modules/input.md`, `current-best-practices.md` |
| Verification | ヘッドレス321アサーション、実画面起動確認、解像度別HUD確認 |

## GDD Requirements Addressed

| GDD | Requirement | Implementation |
|---|---|---|
| `design/gdd/ride-expansion.md` | 落下前のランダムな間と自動降車 | `FreeFallController`の`SUSPENSE`段階と完走イベント |
| `design/gdd/ride-expansion.md` | 3周の手動タイムアタック | `GoKartController`の入力、順序付きチェックポイント、ベスト保存 |
| `design/gdd/ride-interaction.md` | 単一プレイヤーの乗車リース | `RideCoordinator`のプロバイダ登録とPlayerControllerの着座API |
