# 乗り物拡張（フリーフォールタワー／ゴーカート）

## Overview

既存の自動運行3施設に加え、落下前の緊張を演出するフリーフォールタワーと、プレイヤー自身が運転するゴーカートを追加する。園内は72m四方へ拡張し、どちらもプリミティブ形状とJSON設定だけで生成する。フリーフォールは短い自動シーケンス、ゴーカートは3周のタイムアタックとして、散策中に見つけた施設を操作可能なミニゲームへつなげる。

## Player Fantasy

フリーフォールでは、ハーネスが閉じて上昇したあと、いつ落ちるか分からない「間」を味わい、一気に落下して安全に停止する。ゴーカートでは、自分の入力でS字区間を抜け、チェックポイントを順番に通過しながら自己ベストを更新する。HUDは必要な情報だけを視線の端へ置き、園内の景観と運転の手応えを両立する。

## Detailed Rules

- フリーフォールの乗り場でEを押すと即時に座席へ着座し、ハーネス、上昇、ランダム待機、落下、制動、着地の順で1サイクルを行う。
- 待機時間は設定した最小値と最大値の範囲から毎回抽選する。待機中は塔上部のランプを点滅させ、HUDへ段階をイベント通知する。
- フリーフォールは途中退出せず、着地後に安全な出口マーカーへ自動降車する。
- ゴーカートの乗り場でEを押すと3秒のカウントダウンを開始し、GO後にWASDで運転できる。Wは前進、Sは減速／後退、A/Dは旋回、Shiftはブレーキ、Rは最後のチェックポイントへ戻る、Eは退出する。
- コースは10点の閉ループと4つの中間チェックポイントで構成する。チェックポイントは順番どおり、進行方向に向かって通過した場合だけ有効になる。
- 4つの中間チェックポイントとスタートラインを3回通過すると完走とし、結果表示を3秒行って自動降車する。最速タイムはユーザー設定へ保存する。
- 乗車中は三人称カメラを維持し、徒歩の衝突とジャンプを停止する。ゴーカートの車体はCharacterBody3Dとして固定バリアと衝突する。

## Formulas

- フリーフォール上昇位置は `y_next = move_toward(y, y_base + drop_distance, ascent_speed × delta)` とする。
- 落下速度は `v_next = min(v + drop_acceleration × delta, drop_max_speed)`、位置は `y_next = max(y_base + brake_height, y - v_next × delta)` とする。制動区間は `ease` 補間で `brake_seconds` の間に基準高さへ戻す。
- ゴーカート速度は `speed_next = approach_speed(speed, throttle × max_speed, delta, acceleration, brake_or_coast, coast_deceleration)` とする。後退時は `max_reverse_speed` を上限とする。
- 旋回角速度は `steering_degrees_per_second × steering_factor(speed, max_forward_speed)` とし、`steering_factor` は速度比を0.2〜1.0へクランプする。
- チェックポイント通過は `distance <= track_width × 0.9` かつ `forward · checkpoint_tangent >= 0` を満たす場合だけ成立する。

## Edge Cases

- フリーフォールの乱数シードはテストから注入でき、設定の待機範囲が逆順なら起動時に拒否する。
- ゴーカートがバリアへ衝突した場合は速度を減衰させ、コース外へ抜けてもチェックポイントをスキップできない。
- 逆走や同じチェックポイントの再通過は周回数へ加算しない。Rは最後に有効だった地点へ戻り、速度を0へ戻す。
- ベスト記録ファイルが読めない、壊れている、保存できない場合も乗車は継続し、記録だけを未登録として扱う。
- Eでの途中退出はゴーカートだけに対応し、フリーフォールや既存の自動運行は安全な完走後に降車する。

## Dependencies

- Park Configuration: 施設位置、コース点、速度、タイマー、記録先を外部JSONから提供する。
- Park Builder / Primitive Factory: 塔、バリア、ゲート、車体、座席アンカーをプリミティブだけで生成する。
- Ride Provider / Ride Coordinator: 乗車リース、座席への着座、退出、進捗シグナルを共通契約で調整する。
- Player Controller: E/R入力、カメラ維持、乗車中の徒歩入力停止、降車後の衝突復元を担当する。
- Park HUD: 乗車状態は信号で受け取り、ゴーカートのラップ・タイム・結果を安全領域へ表示する。

## Tuning Knobs

- `tower_height`, `drop_distance`, `harness_seconds`, `ascent_speed`
- `suspense_min_seconds`, `suspense_max_seconds`, `drop_acceleration`, `drop_max_speed`
- `brake_height`, `brake_seconds`, `settle_seconds`
- `track_points`, `track_width`, `checkpoint_indices`, `lap_count`
- `countdown_seconds`, `max_forward_speed`, `max_reverse_speed`, `acceleration`, `brake_strength`, `coast_deceleration`, `steering_degrees_per_second`
- `result_display_seconds`, `best_record_path`

## Acceptance Criteria

- [x] フリーフォールへEで着座し、上昇後に2.5〜4.5秒の間を置いて落下、制動、完走、自動降車できる。
- [x] フリーフォールの待機中にランプが点滅し、段階がHUDへイベント通知される。
- [x] ゴーカートへEで着座し、カウントダウン後にWASD／Shiftで運転できる。
- [x] ゴーカートはチェックポイント順序を守る3周タイムアタックになり、HUDへラップ・時間・ベストを表示する。
- [x] ゴーカートのRリセットとE退出が機能し、完走結果後に安全に降車する。
- [x] 設定検証、純粋計算、通常シーン、クリーンコピー、実画面の各QAが成功する。
