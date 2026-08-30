# EPIC-001-S06: Ride interaction and one-cycle boarding

**Status:** Complete
**Type:** Gameplay/UI
**TR-ID:** TR-ride-001, TR-ride-002, TR-ride-003, TR-ride-004
**ADR Governing Implementation:** `docs/architecture/adr-0003-ride-interaction.md`
**Manifest Version:** 2026-08-27
**Dependencies:** EPIC-001-S04, EPIC-001-S05

## Goal

プレイヤーが3施設の乗り場でEを押し、次回到着した車両へ着座して1周を体験し、安全な地点へ自動降車できるようにする。

## Acceptance Criteria

- [x] 観覧車、ジェットコースター、メリーゴーラウンドに乗り場Area3Dと座席アンカーがある。
- [x] E入力で次回到着を待ち、着座して1周後に自動降車する。
- [x] 乗車中は三人称カメラを維持し、歩行入力と衝突を停止・復元する。
- [x] 乗り場、待機中、乗車中のHUDがイベント駆動で切り替わる。
- [x] 通常・クリーンコピーの自動テストと実画面QAを記録する。

## Implementation Notes

- `AttractionAnimator`が位相と周期境界を管理し、`RideCoordinator`が単一プレイヤーの予約を管理する。
- 座席・降車位置・速度・判定値は`assets/data/park_config.json`から読み取る。
- 動く車両へ衝突は追加せず、固定構造物と地面のみをプレイヤー衝突対象にする。

## Test Evidence

`tests/helpers/test_suite.gd`、`tests/run_all_tests.gd`、`production/qa/smoke-2026-08-27.md`、`production/qa/evidence/ride-interaction-playtest.md`
