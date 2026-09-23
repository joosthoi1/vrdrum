extends SceneTree
## CPU benchmark: runs the main scene in desktop mode with a busy drum
## pattern (about 24 hits per second across every piece, plus pedals) and
## reports per-frame script/process time. Fails (exit code 1) if the average
## frame's process time goes over the budget, as a performance smoke test.
##
## Usage: godot --headless --xr-mode off --audio-driver Dummy --script res://tools/benchmark.gd
## GPU cost can't be measured headless; check it on the headset with the
## SteamVR frame timing graph.

const FRAMES := 1200
const DT := 1.0 / 120.0
## Average process time allowed per frame, in ms. A 120 Hz frame is 8.3 ms
## in total, and rendering needs most of it.
const BUDGET_MS := 1.5

var _main: Node3D
var _frame := 0
var _process_us: Array[int] = []
var _hits := 0
var _objects_start := 0
var _exit_code := -1
var _exit_frame := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.get_node("DrumKit").persist = false
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	# After the report, give the audio thread a few frames to release the
	# voices before quitting, so shutdown doesn't report them as leaked.
	if _exit_code != -1:
		if _frame >= _exit_frame:
			quit(_exit_code)
			return true
		return false
	if _frame == 2:
		_main.rig.follow_mouse = false
		_main.kit.hit.connect(func(_h: DrumHit) -> void: _hits += 1)
		root.get_node("DrumAudio").wait_until_ready()
		_objects_start = Performance.get_monitor(Performance.OBJECT_COUNT)
	if _frame < 2:
		return false
	var start := Time.get_ticks_usec()
	_drive(_frame)
	_main.rig._process(DT)
	for stick in _main.rig.sticks():
		stick.step(DT)
	_main.pedals.step(DT)
	for piece in _main.kit.pieces():
		for child in piece.get_children():
			if child.has_method("tilt_angle"):
				child._process(DT)
	_process_us.append(Time.get_ticks_usec() - start)
	if _frame >= FRAMES:
		_report()
		root.remove_child(_main)
		_main.free()
		_exit_frame = _frame + 10
	return false


## Alternating strokes every 5 frames (24 per second at 120 Hz), cycling
## through all pieces, with kick and hi-hat pedal on a pattern.
func _drive(frame: int) -> void:
	var pieces: Array = _main.kit.pieces().filter(func(p: DrumPiece) -> bool: return not p.zone_outer_radii.is_empty())
	if frame % 5 == 0:
		var piece: DrumPiece = pieces[(frame / 5) % pieces.size()]
		_main.rig.aim_at(piece, 0.05)
		_main.rig.strike((frame / 5) % 2)
	if frame % 30 == 0:
		Input.action_press(&"kick")
	elif frame % 30 == 3:
		Input.action_release(&"kick")
	if frame % 60 == 0:
		Input.action_press(&"hihat_pedal")
	elif frame % 60 == 40:
		Input.action_release(&"hihat_pedal")


func _report() -> void:
	var sorted: Array[int] = _process_us.duplicate()
	sorted.sort()
	var total := 0
	for us in sorted:
		total += us
	var avg_ms := total / 1000.0 / sorted.size()
	var p99_ms: float = sorted[int(sorted.size() * 0.99)] / 1000.0
	var max_ms: float = sorted[-1] / 1000.0
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT) - _objects_start
	print("frames %d, hits %d" % [sorted.size(), _hits])
	print("game logic per frame: avg %.3f ms, p99 %.3f ms, max %.3f ms (budget %.1f ms)" % [avg_ms, p99_ms, max_ms, BUDGET_MS])
	print("object count change over the run: %+d" % objects)
	var ok := avg_ms <= BUDGET_MS and _hits > 100 and objects < 200
	print("PASS" if ok else "FAIL")
	_exit_code = 0 if ok else 1
	var audio := root.get_node("DrumAudio")
	for voice in audio.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
