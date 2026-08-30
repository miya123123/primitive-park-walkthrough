# ADR-0001: JSON駆動のプリミティブ遊園地生成

## Status

Accepted

## Date

2026-08-25

## Engine Compatibility

| Field | Value |
|---|---|
| Engine | Godot 4.6.2 |
| Domain | Rendering / Physics / Input |
| Knowledge Risk | HIGH — 4.6は学習カットオフ後 |
| References Consulted | `docs/engine-reference/godot/VERSION.md`, `modules/input.md`, `modules/physics.md`, `modules/rendering.md`, `modules/ui.md` |
| Post-Cutoff APIs Used | Jolt Physics3Dを4.6標準として使用。特別な新規APIには依存しない。 |
| Verification Required | Headless scene launch, collision smoke test, real-window movement and screenshot |

## ADR Dependencies

| Field | Value |
|---|---|
| Depends On | None |
| Enables | EPIC-001 Primitive Park Vertical Slice |
| Blocks | None |
| Ordering Note | Configuration and primitive factory must exist before park generation. |

## Context

### Problem Statement

ゲームの主題は、外部アセットを使わず、プリミティブ形状だけで遊園地を成立させることです。手作業で多数のノードを配置すると、形状制約と配置データの検証が難しくなります。

### Constraints

- 外部3Dモデル、画像、テクスチャ、音源を追加しない。
- 小規模な48m四方のPC向けシーンに限定する。
- gameplay値はJSONで調整できるようにする。
- Godot 4.6.2の標準APIとJolt Physicsを使う。

### Requirements

- 同じJSONから同じ園内を再現できる。
- プレイヤーが全施設へ歩いて到達できる。
- 固定構造物には衝突があり、動く装飾はプレイヤーを拘束しない。

## Decision

`ParkBuilder`が`park_config.json`を受け取り、`PrimitiveFactory`経由でMeshInstance3Dと必要なCollisionShape3Dを実行時生成する。Main.tscnはMain、Park、Player、HUDの責務だけを持ち、施設の見た目はシーンへ直接保存しない。

```text
park_config.json
        |
   ParkConfig.validate
        |
      Main
   /    |     \\
Player ParkBuilder HUD
             |
      PrimitiveFactory
             |
   Box/Cylinder/Sphere/Capsule
```

### Key Interfaces

- `ParkConfig.load_from_file(path) -> Dictionary`
- `ParkConfig.validate(config) -> PackedStringArray`
- `PrimitiveFactory.create_box/create_cylinder/create_sphere/create_capsule(...)`
- `ParkBuilder.build(config) -> void`
- `ParkBuilder.landmark_entered(landmark_id, display_name)`
- `PlayerController.location_changed(display_name)`
- `AttractionAnimator.advance_time(delta) -> void`

### State Ownership

- 園内配置と演出速度は`ParkConfig`の読み取り専用データ。
- 園内ノードの所有者は`ParkBuilder`。
- 移動と視点の状態は`PlayerController`。
- HUDはゲーム状態を所有せず、イベントを表示するだけ。

## Alternatives Considered

### Alternative 1: 全施設を手作業でMain.tscnへ配置

- Pros: エディタで調整しやすい。
- Cons: プリミティブ制約の監査、配置の再現、値のデータ駆動が弱い。
- Rejection Reason: この依頼の「プリミティブのみ」を自動検証しにくい。

### Alternative 2: 外部3Dモデルを読み込む

- Pros: 施設の造形を短時間で高品質にできる。
- Cons: 依頼の制約に反し、アセット依存とインポート問題が増える。
- Rejection Reason: 明確にスコープ外。

## Consequences

### Positive

- JSONを変更するだけで配置と速度を調整できる。
- プリミティブ型のホワイトリストをテストできる。
- 外部アセットなしでクリーンな再現性を得られる。

### Negative

- 複雑な曲面や写実的な見た目は表現しにくい。
- 実行時生成のため、生成コードの可読性が品質を左右する。

### Risks

- 4.6のJoltと衝突形状の差異 → ヘッドレスと実プレイの両方で境界を検証する。
- プリミティブ数増加による描画負荷 → 48mの固定レイアウトと250 draw call目標を使う。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `primitive-park-layout.md` | 3施設をプリミティブだけで生成 | Factoryの型制限と実行時監査で担保 |
| `third-person-movement.md` | 衝突境界と歩行可能な導線 | 固定構造物にCollisionShape3Dを付与 |
| `landmark-guidance.md` | 施設イベントをHUDへ伝える | ParkBuilderのtyped signalを使用 |

## Performance Implications

- CPU: 起動時の一度だけ生成し、演出は単一Animatorで更新。
- Memory: 外部アセットを持たず、48mの小規模ノード数に制限。
- Load Time: JSON読込とプリミティブ生成が起動時に発生。
- Network: 対象外。

## Migration Plan

既存ゲームコードはないため移行不要。将来シーン編集へ移行する場合も、`PrimitiveFactory`のインターフェースとJSONを保持する。

## Validation Criteria

- 設定・移動計算の単体テストが全件PASS。
- Main.tscnのヘッドレス起動が終了コード0。
- 実ウィンドウで3施設、衝突、HUD、演出を確認。

## Related Decisions

- `design/gdd/game-pillars.md`
- `design/gdd/primitive-park-layout.md`
