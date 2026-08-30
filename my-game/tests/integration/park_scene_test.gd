extends SceneTree

const TestSuite = preload("res://tests/helpers/test_suite.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite: RefCounted = TestSuite.new()
	await suite.run_scene_tests(self)
	var failures: PackedStringArray = suite.failures()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("PARK SCENE TEST PASSED (%d assertions)" % suite.assertion_count())
	quit(0)
