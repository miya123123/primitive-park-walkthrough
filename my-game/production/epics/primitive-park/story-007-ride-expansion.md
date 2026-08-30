# EPIC-001-S07: フリーフォールとゴーカートの乗車体験

**Status:** Complete
**Type:** Gameplay/UI
**TR-ID:** TR-ride-005, TR-ride-006, TR-ride-007, TR-ride-008
**ADR Governing Implementation:** `docs/architecture/adr-0004-interactive-ride-providers.md`
**Manifest Version:** 2026-08-28
**Dependencies:** EPIC-001-S06

## Goal

フリーフォールタワーに落下前の「間」を持つ自動シーケンスを、ゴーカートに3周タイムアタックを追加し、既存の乗車リースとイベント駆動HUDへ接続する。

## Acceptance Criteria

- [x] 72m四方の設定からフリーフォールタワーとゴーカートコースを生成する。
- [x] フリーフォールがハーネス、上昇、ランダム待機、落下、制動、着地、自動降車を行う。
- [x] ゴーカートがカウントダウン後にWASD／Shiftで運転できる。
- [x] 順序付きチェックポイントと逆走防止で3周を判定し、RリセットとE退出を提供する。
- [x] ラップ・時間・ベストタイムをHUDへ表示し、ベストをローカルへ保存する。
- [x] 既存3施設の自動運行と乗車テストを回帰させない。

## Implementation Notes

- `RideProvider`を介して`AttractionAnimator`、`FreeFallController`、`GoKartController`を`RideCoordinator`へ登録する。
- フリーフォールの抽選範囲、ゴーカートの速度、コース点、記録先は`assets/data/park_config.json`から読む。
- 車体は`CharacterBody3D`、コース外周は固定プリミティブバリア、HUDは`ride_progress_changed`信号のみを購読する。

## Test Evidence

- `tests/helpers/test_suite.gd`
- `tests/run_all_tests.gd`
- `production/qa/smoke-2026-08-28.md`
- `production/qa/evidence/ride-expansion-playtest.md`
