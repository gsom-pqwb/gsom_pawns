extends Node3D
class_name Main

const __PATH_GDTRICKS := "res://maps/gdtricks/gdtricks.tscn"
const __PATH_GODOTA := "res://maps/godota/godota.tscn"
const __PATH_TEST_CHAMBER := "res://maps/test_chamber/test_chamber.tscn"
const __PATH_CTRL_FPS := "res://controllers/fps/controller_fps.tscn"
const __PATH_CTRL_RTS := "res://controllers/rts/controller_rts.tscn"
const __PATH_CHAR_HUMAN := "res://characters/human/char_human.tscn"
const __PATH_CHAR_VTOL := "res://characters/vtol/char_vtol.tscn"
const __PATH_CHAR_SPEC := "res://characters/spec/char_spec.tscn"

var __DISPLAY_MONITORS: Dictionary[String, Performance.Monitor] = {
	"TIME_FPS": Performance.TIME_FPS,
	"TIME_PROCESS": Performance.TIME_PROCESS,
	"TIME_PHYSICS_PROCESS": Performance.TIME_PHYSICS_PROCESS,
	"OBJECT_COUNT": Performance.OBJECT_COUNT,
	"OBJECT_RESOURCE_COUNT": Performance.OBJECT_RESOURCE_COUNT,
	"RENDER_TOTAL_OBJECTS_IN_FRAME": Performance.RENDER_TOTAL_OBJECTS_IN_FRAME,
	"RENDER_TOTAL_PRIMITIVES_IN_FRAME": Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME,
	"RENDER_TOTAL_DRAW_CALLS_IN_FRAME": Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME,
}

static var __instance: Node3D = null

var __load_queue: Dictionary[String, Callable] = {}
var __char_human: CharHuman = null
var __char_vtol: CharVtol = null
var __char_spec: CharSpec = null
var __controller_fps: ControllerFps = null
var __controller_rts: ControllerRts = null


@onready var __timer_load: Timer = $TimerLoad
@onready var __timer_perf: Timer = $TimerPerf
@onready var __label_loading: Label = $LabelLoading
@onready var __label_perf: Label = $LabelPerf
@onready var __container: Node = $Container


func _ready() -> void:
	__instance = self
	
	__timer_load.connect("timeout", __update_load)
	__timer_perf.connect("timeout", __update_perf)
	
	__load_async(__PATH_CTRL_FPS, __on_load_cases)
	__load_async(__PATH_GDTRICKS, __on_load_cases)
	__load_async(__PATH_CTRL_RTS, __on_load_cases)


func _exit_tree() -> void:
	if __instance == self:
		__instance = null


static func __nop(_res: PackedScene, _path: String) -> void:
	pass


static func load_async(path: String, cb: Callable = Main.__nop) -> void:
	if not is_instance_valid(__instance) or not __instance is Main:
		push_error("The demo loader requires an active Main scene")
		return
	var instance: Main = __instance
	instance.__load_async(path, cb)


func __on_load_cases(res: PackedScene, path: String) -> void:
	var inst: Node = res.instantiate()
	
	# Need to set position before "ready"
	if path == __PATH_CHAR_HUMAN:
		var human: CharHuman = inst
		human.position = Vector3(0.0, 0.0, 5.8)
	elif path == __PATH_CHAR_VTOL:
		var vtol: CharVtol = inst
		vtol.position = Vector3(-9.0, 0.0, 5.8)
	elif path == __PATH_CHAR_SPEC:
		var spec: CharSpec = inst
		spec.position = Vector3(10.0, 7.0, 5.8)
	
	__container.add_child(inst)
	
	if path == __PATH_CTRL_RTS:
		__controller_rts = inst
		__controller_rts.switched_controller.connect(__switch_controller)
	
	if path == __PATH_GDTRICKS:
		__load_async(__PATH_GODOTA, __on_load_cases)
		__load_async(__PATH_TEST_CHAMBER, __on_load_cases)
	
	if path == __PATH_CTRL_FPS:
		__controller_fps = inst
		__controller_fps.kind = "human"
		__controller_fps.switched_character.connect(__switch_pawn)
		__controller_fps.switched_controller.connect(__switch_controller)
		__controller_fps.is_focused = true
		
		__load_async(__PATH_CHAR_HUMAN, __on_load_cases)
		__load_async(__PATH_CHAR_VTOL, __on_load_cases)
		__load_async(__PATH_CHAR_SPEC, __on_load_cases)
	
	if path == __PATH_CHAR_HUMAN:
		__char_human = inst
		__controller_fps.possess(__char_human.pawn)
	
	if path == __PATH_CHAR_VTOL:
		__char_vtol = inst
	
	if path == __PATH_CHAR_SPEC:
		__char_spec = inst


func __switch_pawn(char_kind: String) -> void:
	__controller_fps.kind = char_kind
	if char_kind == "vtol":
		__controller_fps.possess(__char_vtol.pawn)
	elif char_kind == "human":
		__controller_fps.possess(__char_human.pawn)
	else:
		__controller_fps.possess(__char_spec.pawn)


func __switch_controller(ctrl_kind: String) -> void:
	__controller_fps.is_focused = ctrl_kind == "fps"
	__controller_rts.is_focused = ctrl_kind == "rts"


# This ensures only one threaded loading runs in background
# Fixes: "ERROR: Another resource is loaded from path ..."
func __load_async_next() -> void:
	var has_items: bool = __load_queue.size() > 0
	if !has_items:
		return
	
	var path: String = __load_queue.keys()[0]
	ResourceLoader.load_threaded_request(path)


func __load_async(path: String, cb: Callable = __nop) -> void:
	if __load_queue.has(path):
		return
	
	__load_queue[path] = cb
	if __load_queue.size() == 1:
		__load_async_next()


func __update_load() -> void:
	var has_items: bool = __load_queue.size() > 0
	if __label_loading.visible != has_items:
		__label_loading.visible = has_items
	
	if !has_items:
		return
	
	var path: String = __load_queue.keys()[0]
	
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	
	var cb: Callable = __load_queue[path]
	__load_queue.erase(path)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res := ResourceLoader.load_threaded_get(path) as PackedScene
		if cb == Main.__nop:
			var inst: Node = res.instantiate()
			__container.add_child(inst)
		else:
			cb.call(res, path)
	
	__load_async_next()


func __get_perf_line(perf_name: String, perf_type: Performance.Monitor) -> String:
	return ("%s: %s" % [perf_name, Performance.get_monitor(perf_type)])


func __update_perf() -> void:
	if !__label_perf.visible:
		return
	
	var text: String = ""
	for perf_name: String in __DISPLAY_MONITORS:
		text += __get_perf_line(perf_name, __DISPLAY_MONITORS[perf_name]) + "\n"
	
	__label_perf.text = text
