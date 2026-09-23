extends SceneTree
## Minimal headless test runner: runs every res://tests/test_*.gd file.
##
## Usage (after an initial `godot --headless --import`):
##   godot --headless --xr-mode off --audio-driver Dummy --script res://tests/run_tests.gd
## Exits with code 1 if any check fails.

const TEST_DIR := "res://tests"

var _done := false
var _errors := ErrorLog.new()


## Collects engine and script errors, so a test that hits a runtime error
## fails even though GDScript carries on after it.
class ErrorLog extends Logger:
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		messages.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := messages
		messages = []
		_mutex.unlock()
		return out


func _initialize() -> void:
	OS.add_logger(_errors)


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
		if script == null or not script.can_instantiate():
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
			_errors.take()
			case.call(name)
			case.cleanup()
			for error in _errors.take():
				case.failures.append("%s: runtime error: %s" % [case.current_test, error])
			if case.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for failure in case.failures:
					printerr("FAIL ", failure)
	print("\n%d passed, %d failed" % [passed, failed])
	return 1 if failed > 0 else 0
