extends SceneTree
## Headless test runner:  godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## Exit code 0 = all passed. Prints "TESTS PASSED" / "TESTS FAILED".
## The suite is loaded one frame later so project autoloads (Config, Net...) are registered first.


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var suite: Node = load("res://tests/test_suite.gd").new()
	root.add_child(suite)
