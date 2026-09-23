extends SceneTree
## Minimal headless test runner: runs every res://tests/test_*.gd file.
##
## Usage (after an initial `godot --headless --import`):
##   godot --headless --xr-mode off --audio-driver Dummy --script res://tests/run_tests.gd
## Exits with code 1 if any check fails.

const TEST_DIR := "res://tests"

var _done := false


func _process(_delta: float) -> bool:
	# Run on the first frame so autoloads and the root viewport are ready.
	if _done:
		return true
	_done = true
	quit(_run_all())
	return false


func _run_all() -> int:
	var files := Array(DirAccess.get_files_at(TEST_DIR)).filter(
		func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd")
	files.sort()
	var passed := 0
	var failed := 0
	for file in files:
		var script: GDScript = load(TEST_DIR.path_join(file))
		if script == null:
			printerr("FAIL %s: could not load" % file)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.tree = self
			case.current_test = "%s::%s" % [file.get_basename(), name]
			case.call(name)
			case.cleanup()
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in case.failures:
					printerr("FAIL ", failure)
	print("\n%d passed, %d failed" % [passed, failed])
	return 1 if failed > 0 else 0
