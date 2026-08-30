# Primitive Park 実プレイ証跡

実施日: 2026-08-25
対象シーン: `scenes/Main.tscn`
実行環境: Godot 4.6.2、Forward+、Jolt Physics3D、macOS Apple M2

## 確認した操作と状態

1. Godotエディターのプロジェクト実行で`Primitive Park Walkthrough (DEBUG)`を起動。
2. 起動直後に、青空、芝生、中央通路、カルーセル、背後の観覧車・ジェットコースター、左上の操作説明、中央クロスヘアを確認。
3. ゲーム画面をクリックして入力を有効化し、W入力を複数回送信。
4. カルーセルへ近づき、施設が画面内で大きくなることで前進を確認。
5. Godotのデバッグウィンドウを閉じてプレイを停止。

## 証跡ファイル

- 起動直後: [`primitive-park-initial.jpeg`](primitive-park-initial.jpeg)
- W入力後: [`primitive-park-movement.jpeg`](primitive-park-movement.jpeg)

2枚ともゲーム実行中のGodotデバッグウィンドウを保存したものです。両方にプリミティブで構成されたカルーセル、観覧車、ジェットコースター、操作HUDが写っています。

## イベント経路

実ウィンドウの見た目確認に加え、`tests/helpers/test_suite.gd`でゲームと同じW入力を50物理フレーム送信し、カルーセルのArea3Dから`landmark_entered`を受け取る統合検証を行った。HUDはこのイベントを受けて位置バナーを更新する設計で、毎フレームのHUDポーリングは行っていない。

## 判定

実プレイの起動・描画・前進入力・停止を確認済み。入力式のランドマーク入場イベント、HUD更新経路、アトラクション演出の自動テストも合格している。
