# Primitive Park 三人称実プレイ証跡

実施日: 2026-08-26
対象シーン: `scenes/Main.tscn`
実行環境: Godot 4.6.2、Forward+、Jolt Physics3D、macOS Apple M2

## 確認した操作と状態

1. Godotエディターからメインシーンを起動し、中央背面追従の来園者モデル、青空、芝生、3施設、左上の操作説明を確認した。中央クロスヘアは表示されない。
2. ゲーム画面をクリックしてマウス入力を有効化し、ドラッグでカメラを旋回した。背面追従から上方を含む自由な三人称視点へ変化し、来園者モデルが画面内に残ることを確認した。
3. W入力を連続送信して施設へ接近させた。遮蔽物付近ではカメラがプレイヤーへ近づき、来園者モデルを描画し続けた。SpringArm3Dの短縮は統合テストでも確認した。
4. 確認後、Godotのデバッグゲームウィンドウを閉じてプレイを停止した。

## 証跡ファイル

- 起動直後（背面追従）: [`third-person-park-initial.jpeg`](third-person-park-initial.jpeg)
- マウス旋回後: [`third-person-park-orbit.jpeg`](third-person-park-orbit.jpeg)
- 施設への接近時: [`third-person-park-obstruction.jpeg`](third-person-park-obstruction.jpeg)

## 判定

三人称の来園者表示、HUDからのクロスヘア除去、マウス旋回、施設付近でのカメラ短縮、停止操作を実画面で確認した。WASD方向、斜め速度、ジャンプ、モデル旋回・歩行／跳躍姿勢、遮蔽物短縮は同一シーンを使う自動テストで回帰確認している。
