extends RefCounted

## ゴーカートのベストタイムをConfigFileへ安全に保存する小さなストア。

const SECTION: String = "go_kart"
const KEY_BEST: String = "best_seconds"

## 指定ファイルからベストタイムを読み、無効値は未登録として扱う。
static func load_best(path: String) -> float:
	if path.is_empty():
		return 0.0
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return 0.0
	var value: Variant = config.get_value(SECTION, KEY_BEST, 0.0)
	if value is int or value is float:
		return maxf(float(value), 0.0)
	return 0.0

## 新記録だけを保存し、ファイル失敗は乗車体験を止めずに false を返す。
static func save_best(path: String, seconds: float) -> bool:
	if path.is_empty() or seconds <= 0.0:
		return false
	var config: ConfigFile = ConfigFile.new()
	var existing: float = load_best(path)
	if existing > 0.0 and existing <= seconds:
		return false
	config.set_value(SECTION, KEY_BEST, seconds)
	return config.save(path) == OK
