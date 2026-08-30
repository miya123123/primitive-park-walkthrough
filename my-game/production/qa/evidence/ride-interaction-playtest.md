# Ride Interaction 実画面証跡

実施日: 2026-08-27
対象: `scenes/Main.tscn` / カルーセル

| 状態 | 確認内容 | 証跡 |
|---|---|---|
| 乗り場 | 乗り場へ近づくとEキー案内を表示 | [`ride-interaction-prompt.jpeg`](ride-interaction-prompt.jpeg) |
| 到着待ち | E入力後、次の到着まで待機表示 | [`ride-interaction-waiting.jpeg`](ride-interaction-waiting.jpeg) |
| 乗車中 | 車両運行中に1周表示を継続 | [`ride-interaction-riding.jpeg`](ride-interaction-riding.jpeg) |
| 自動降車 | 1周完了後に乗り場案内へ復帰 | [`ride-interaction-exit.jpeg`](ride-interaction-exit.jpeg) |

実画面の確認後、デバッグウィンドウを閉じてプレイを停止した。3施設の同一状態機械と衝突復元は`tests/helpers/test_suite.gd`の統合検証で確認している。
