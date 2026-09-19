# Primitive Park Walkthrough

[ブラウザでデモを遊ぶ](https://miya123123.github.io/primitive-park-walkthrough/)

Godot 4.6.2で制作した、プリミティブ形状のみで構成された遊園地を三人称視点で歩き回る3Dゲームです。観覧車、ジェットコースター、メリーゴーラウンド、フリーフォールタワー、ゴーカートを体験できます。外部モデル・テクスチャ・音声は使用せず、JSON設定とGDScriptから園内を生成しています。

## 遊び方

- `WASD`: 移動
- マウス: カメラ旋回
- `Space`: ジャンプ
- `Shift`: ダッシュ（ゴーカート中はブレーキ）
- `E`: 乗り場で乗車／ゴーカートから退出
- `R`: ゴーカートを最後に通過したチェックポイントへリセット
- `Esc`: マウスカーソルを解放（左クリックで再取得）

## ローカルで起動

```bash
cd my-game
godot --path .
```

## 使用技術

- Godot 4.6.2: ゲームエンジン
- Claude Code Game Studios: 開発フレームワーク
- Codex: 開発支援ツール
- GoPeak: テスト

## 開発者

`miya123123`

## ライセンス

MIT License（[`my-game/LICENSE`](my-game/LICENSE)）
