# Ride Expansion Playtest Evidence — 2026-08-28

## 実行条件

- Engine: Godot 4.6.2
- Renderer: Metal / Forward+
- Window: 1280×720
- Launch: `godot --path my-game --script res://tests/gui_capture.gd --resolution 1280x720 --position 80,60`
- Stop: キャプチャスクリプトが`quit(0)`を呼び出して終了

## 確認手順

1. 初期フレームを保存し、プレイヤー、入口から続く道、既存3施設、新設2施設、操作説明の配置を目視した。
2. ゴーカート乗り場へプレイヤーを移動し、Eで着座。右上にカウントダウン、左上にカート操作、中央下に乗車状態が出ることを確認した。
3. ゴーカートをEで退出し、フリーフォール乗り場へ移動。Eで着座してハーネス後の上昇を進め、塔上部で`FREE FALL — HOLD ON...`が表示されることを確認した。
4. キャプチャ後にゲームプロセスを終了した。

## Evidence Files

- `ride-expansion-initial.png`
- `ride-expansion-kart-countdown.png`
- `ride-expansion-freefall-suspense.png`

## Notes

キャプチャは決定的なプロバイダ進行を使い、スクリーンショット保存後に明示的にシーンを解放した。Godotの終了時にObjectDB cleanup警告が残るため、これをアプリ実行時のGameplayエラーとは扱わず、ヘッドレス統合テストの終了コードとログを優先した。
