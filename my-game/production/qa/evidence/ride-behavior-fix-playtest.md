# Ride Behavior Fix Playtest Evidence — 2026-08-30

## 実行条件

- Engine: Godot 4.6.2.stable.official.71f334935
- Renderer: Metal / OpenGL Compatibility
- Window: 1280×720
- GoPeak: `v2.3.9`、MCP stdio server
- Runtime addon: `/private/tmp/primitive_park_gopeak_5qZcgn/my-game` の一時コピーだけに Autoload
- 対象コミット: `7487aa6 fix: 乗車位置とゴーカート走行を修正`

## 確認手順

1. GoPeak `runtime-status` で Runtime addon の `connected=true` を確認し、`inspect-runtime-tree` で `/root/Main/Player`、`GoKartController`、`FreeFallController` を確認した。
2. `set-runtime-property` でプレイヤーをゴーカート乗り場 `[8.0, 1.07, 20.0]` へ移動し、`inject-key(E)` を押下・解放した。
3. `call-runtime-method(Player, is_riding)` が `true`、`GoKartController.get_progress_snapshot()` が `status=countdown`、開始カート位置が `(-10, 0.45, 6)` であることを確認した。
4. `inject-action(move_forward)` を4.3秒押下し、解放後にスナップショットを取得した。
5. 走行後の状態が `status=racing`、`time_seconds=1.9667`、`checkpoint=0`、カート位置が `(-10.1768, 0.45, 5.2327)` となり、開始点から移動していることを確認した。`Player.get_ride_id()` は `go_kart` だった。
6. Eを押下・解放して `Player.is_riding=false` を確認した。Runtime tree の `VisualRoot` は降車後に原点オフセットへ戻った。
7. プレイヤーをフリーフォール乗り場 `[-22.0, 1.07, 17.2]` へ移動し、Eを押下・解放した。`is_riding=true`、`FreeFallController.get_ride_state()` が `harness`、`VisualRoot` の原点が `(0, -0.84, 0)` であることを確認した。
8. GoPeak `capture-screenshot` で各状態を1280×720 PNGへ保存し、実ウィンドウ終了後にGodotプロセスを停止した。

## 結果

| シナリオ | 状態 | 判定 |
| --- | --- | --- |
| ゴーカート E乗車 | `is_riding=true`, `countdown` | PASS |
| ゴーカート W走行 | `racing`, 開始点から約0.79m移動 | PASS |
| ゴーカート E退出 | `is_riding=false` | PASS |
| フリーフォール E乗車 | `harness`, `is_riding=true` | PASS |
| 着座表示 | `VisualRoot.y=-0.84`、降車後`0` | PASS |

## Evidence Files

- `ride-fix-kart-seated.png` — ゴーカート乗車直後、`GET READY — 3`
- `ride-fix-kart-driving.png` — W入力後、`LAP 1/3` と走行中のHUD
- `ride-fix-freefall-seated.png` — フリーフォール `FREE FALL — ASCENDING`

## 補足

ゴーカートの開始点は設定のローカル座標をワールド座標へ配置した値であり、修正前のように全点が原点へ潰れていないことを状態スナップショットで確認した。Runtime addon は製品プロジェクトへ追加せず、一時コピーでのみ使用した。QA終了時にゲームを停止し、対象ワークツリーに実行中プロセスを残していない。
