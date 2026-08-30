extends Node

## 共通の乗り物プロバイダ契約。
##
## RideCoordinator は乗り物の種類を意識せず、このイベントとメソッドだけで
## 乗車リースを管理する。各プロバイダは乗り物固有の状態を内部に保持する。

signal station_ready(ride_id: StringName)
signal cycle_completed(ride_id: StringName)
signal progress_changed(ride_id: StringName, snapshot: Dictionary)

## 乗車要求を受け付ける。駅で待つ場合も true を返す。
func request_boarding(_ride_id: StringName) -> bool:
	return false

## 待機中の乗車要求を取り消す。
func cancel_boarding(_ride_id: StringName) -> void:
	pass

## 駅に到着した車両の1サイクルを開始する。
func begin_cycle(_ride_id: StringName) -> bool:
	return false

## 乗車中のサイクルを安全に中断する。対応しない乗り物は false。
func abort_cycle(_ride_id: StringName) -> bool:
	return false

## リセット操作を受け付ける。対応しない乗り物は false。
func reset_cycle(_ride_id: StringName) -> bool:
	return false

## 乗り物の座席・出口・表示情報を返す。
func get_ride_descriptor(_ride_id: StringName) -> Dictionary:
	return {}

## 乗り物の内部状態を診断用に返す。
func get_ride_state(_ride_id: StringName) -> StringName:
	return &"unknown"
