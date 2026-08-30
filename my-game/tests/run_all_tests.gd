extends SceneTree

const TestSuite = preload("res://tests/helpers/test_suite.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var suite: RefCounted = TestSuite.new()
	suite.run_config_tests()
	suite.run_movement_tests()
	suite.run_ride_tests()
	await suite.run_scene_tests(self)
	var failures: PackedStringArray = suite.failures()
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("ALL TESTS PASSED (%d assertions)" % suite.assertion_count())
	quit(0)
