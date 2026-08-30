# Primitive Park Walkthrough

[ブラウザでデモを遊ぶ](https://miya123123.github.io/primitive-park-walkthrough/)

Godot 4.6.2で制作した、プリミティブ形状だけの72m四方の遊園地を三人称視点で歩き回る3Dゲームです。観覧車、ジェットコースター、メリーゴーラウンド、フリーフォールタワー、ゴーカートを体験できます。外部モデル・テクスチャ・音声を使わず、JSON設定とGDScriptから園内を生成します。

## 遊び方

- `WASD`: 移動
- マウス: カメラ旋回
- `Space`: ジャンプ
- `Shift`: ダッシュ（ゴーカート中はブレーキ）
- `E`: 乗り場で乗車／ゴーカートから退出
- `R`: ゴーカートを最後に通過したチェックポイントへリセット
- `Esc`: マウスカーソルを解放（左クリックで再取得）

ブラウザ版はGitHub Pagesで配信しています。初回クリックでゲーム画面を選択すると、マウス操作とキーボード操作が有効になります。

## ローカルで起動

```bash
cd my-game
godot --path .
```

自動テストは次のコマンドで実行できます。

```bash
godot --headless --path . --script tests/run_all_tests.gd --log-file /private/tmp/primitive_park_tests.log
```

## GitHub Pages公開

`master` へのpushで [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml) がGodot Web版をビルドし、GitHub Pagesへ自動デプロイします。WebGL 2に対応するCompatibilityレンダラーを使用し、スレッドを使わないWeb export presetで構成しています。

## プロジェクト構成

- [`my-game/`](my-game/): Godotプロジェクト本体
- [`my-game/src/`](my-game/src/): ゲーム実装
- [`my-game/assets/data/park_config.json`](my-game/assets/data/park_config.json): 園内・乗り物設定
- [`my-game/design/`](my-game/design/): 設計資料
- [`my-game/production/qa/`](my-game/production/qa/): QA記録

## ライセンス

MIT License（[`my-game/LICENSE`](my-game/LICENSE)）
