extends Node3D

var _failures: int = 0
var _body_scene: PackedScene

func _ready() -> void:
	var pawn: GsomPawn = GsomPawn.new()
	var body: Node3D = Node3D.new()
	var scene: PackedScene = PackedScene.new()
	scene.pack(body)
	body.free()
	_body_scene = scene
	pawn.scene = scene
	pawn.head_y_target = 1.5
	add_child(pawn)
	_expect(is_equal_approx(pawn.head_y, 1.5), "head set before ready")
	pawn.head_y_target = 1.7
	_expect(is_equal_approx(pawn.head_y, 1.7), "head set in parent ready")
	pawn._process(0.0)
	pawn.head_y_target = 1.2
	pawn._process(0.1)
	_expect(is_equal_approx(pawn.head_y, 1.6), "later head changes interpolate")
	var first: GsomPawnEnv = _zone(1)
	var second: GsomPawnEnv = _zone(2)
	first.attach() # Repeated attachment must not duplicate signal connections.
	_enter(first, pawn)
	_enter(second, pawn)
	_expect(pawn.get_env("surface", {}).get("value") == 2, "latest source wins")
	_exit(first, pawn)
	_expect(pawn.get_env("surface", {}).get("value") == 2, "leaving older source keeps newer")
	_enter(first, pawn)
	_expect(pawn.get_env("surface", {}).get("value") == 1, "reenter promotes source")
	var original_area: Area3D = first.get_parent() as Area3D
	original_area.remove_child(first)
	_expect(pawn.get_env("surface", {}).get("value") == 2, "detaching marker restores remaining source")
	original_area.body_entered.emit(pawn.body)
	_expect(pawn.get_env("surface", {}).get("value") == 2, "detached marker ignores old area")
	var new_area: Area3D = Area3D.new()
	add_child(new_area)
	new_area.add_child(first)
	original_area.body_entered.emit(pawn.body)
	_expect(pawn.get_env("surface", {}).get("value") == 2, "reattached marker ignores old area")
	_enter(first, pawn)
	_expect(pawn.get_env("surface", {}).get("value") == 1, "reattached marker uses new area")
	original_area.free()
	first.get_parent().free()
	_expect(pawn.get_env("surface", {}).get("value") == 2, "deleting zone restores remaining source")
	_exit(second, pawn)
	_expect(not pawn.has_env("surface"), "last exit clears environment")
	_enter(second, pawn)
	pawn.remove_child(pawn.body)
	_expect(not pawn.has_env("surface"), "body removal clears environment")
	pawn.add_child(pawn.body)
	_enter(second, pawn)
	pawn.free()
	second.get_parent().free() # No stale pawn reference.
	_test_event_modes()
	print("PAWNS_REGRESSION failures=%d" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)

func _zone(value: int) -> GsomPawnEnv:
	var area: Area3D = Area3D.new()
	var env: GsomPawnEnv = GsomPawnEnv.new()
	env.env_name = "surface"
	env.env_value = {"value": value}
	area.add_child(env)
	add_child(area)
	return env

func _enter(env: GsomPawnEnv, pawn: GsomPawn) -> void:
	(env.get_parent() as Area3D).body_entered.emit(pawn.body)

func _exit(env: GsomPawnEnv, pawn: GsomPawn) -> void:
	(env.get_parent() as Area3D).body_exited.emit(pawn.body)

func _test_event_modes() -> void:
	for mode: int in GsomPawnEnv.EnvBehavior.values():
		if mode == GsomPawnEnv.EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
			continue
		var pawn: GsomPawn = GsomPawn.new()
		pawn.scene = _body_scene
		add_child(pawn)
		var env: GsomPawnEnv = _zone(3)
		env.behavior = mode as GsomPawnEnv.EnvBehavior
		pawn.set_env("surface", {"value": 9})
		_enter(env, pawn)
		var removes: bool = mode in [GsomPawnEnv.EnvBehavior.ENTER_REMOVE, GsomPawnEnv.EnvBehavior.ENTER_REMOVE_EXIT_APPLY]
		_expect(pawn.has_env("surface") != removes, "event mode enter %d" % mode)
		_exit(env, pawn)
		var present: bool = mode in [GsomPawnEnv.EnvBehavior.ENTER_APPLY, GsomPawnEnv.EnvBehavior.ENTER_REMOVE_EXIT_APPLY, GsomPawnEnv.EnvBehavior.EXIT_APPLY]
		_expect(pawn.has_env("surface") == present, "event mode exit %d" % mode)
		env.get_parent().free()
		_expect(pawn.has_env("surface") == present, "event modes persist after zone deletion %d" % mode)
		pawn.free()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: " + label)
