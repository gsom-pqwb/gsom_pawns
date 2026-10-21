@tool
@icon("./pawn.svg")
extends Node
class_name GsomPawn

## The GsomPawn framework core.
##
## GsomPawn node is designed for actors that can be controlled by players or AI.
## A pawn is the physical representation of a player or AI entity within the world.
## The pawn determines how the entity interacts with the world in terms of
## collisions and other physical interactions.
## Some types of games may not have a visible player mesh or avatar within the game.
## Regardless, the Pawn still represents the physical location, rotation, etc. of
## a player or entity within the game.
## You will need a Controller to possess a pawn and generate input signals for it.


## The pawn has finished the '_physics_process' logic. This is the right time
## to use the position to update cameras or other stuff.
## The argument is pawn's global position.
signal moved(global_pos: Vector3)

## The body changed its linear speed - only emits if [code]track_accel_linear[/code].
## Argument [code]dv[/code] is how much the velocity changed during this frame.
## Argument [code]dvdt[/code] is actual acceleration - divided by the timestep.
signal accelerated_linear(dv: Vector3, dvdt: Vector3)

## The body changed its angular speed - only emits if [code]track_accel_angular[/code].
## Argument [code]dv[/code] is how much the velocity changed during this frame.
## Argument [code]dvdt[/code] is actual acceleration - divided by the timestep.
signal accelerated_angular(dv: Vector3, dvdt: Vector3)

## The relative position of the head changed.
signal moved_head(head_y: float)

## The body has produced an event with optional data.
signal triggered(trigger_name: String, value: Variant)


const __SCENE_DEFAULT: PackedScene = preload("./default_scene.tscn")

var __scene: PackedScene = __SCENE_DEFAULT
## Scene that will be instantiated for this pawn
@export var scene: PackedScene = __SCENE_DEFAULT:
	get:
		return __scene
	set(v):
		__scene = v
		__assign_scene()


## How quickly the "head" moves towards the target position (m/s).
@export var head_speed: float = 1.0


## If the pawn needs to track its linear acceleration.
@export var track_accel_linear: bool = false


## If the pawn needs to track its angular acceleration.
@export var track_accel_angular: bool = false


## If the pawn needs to track its linear velocity.
@export var has_velocity_linear: bool = false


## If the pawn needs to track its angular velocity.
@export var has_velocity_angular: bool = false


## Get the global position of the body.
var position: Vector3 = Vector3.ZERO:
	get:
		return __body.global_position


var __cached_vell := Vector3.ZERO
## Linear velocity vector, only updated if [code]has_velocity_linear[/code].
var linear_velocity: Vector3 = Vector3.ZERO:
	get:
		return __cached_vell


var __cached_vela := Vector3.ZERO
## Angular velocity vector, only updated if [code]has_velocity_angular[/code].
var angular_velocity: Vector3 = Vector3.ZERO:
	get:
		return __cached_vela


# Cache the child physics body after instantiation
var __body: Node3D = null
## Get the cached physical body object as instantiated from [code]scene[/code].
var body: Node3D = null:
	get:
		return __body


## Set this value to define the intended head height of the body.
## When this value is set from [code]_ready[/code], it will be applied
## immediately without animation.
var head_y_target: float = 0.0:
	set(value):
		head_y_target = value
		if not __head_started:
			__head_y = value

var __head_started: bool = false
var __head_y: float = 0.0
## Get the animated head/eye/camera position Y.
##
## This value is animated towards [code]head_y_target[/code]
## with the speed of [code]head_speed[/code] (meters per second).
var head_y: float = __head_y:
	get:
		return __head_y


var __info: Dictionary[String, Dictionary] = {}
var __parent: Node3D = null


func _ready() -> void:
	__parent = get_parent() as Node3D
	if !__parent:
		push_error("Parent must be a Node3D.")
	
	__assign_scene()


func __assign_scene() -> void:
	if !__parent:
		return
	
	if __body:
		remove_child(__body)
		__body.queue_free()
	
	if !__scene:
		push_error("The `scene` is not set.")
		__scene = __SCENE_DEFAULT
		
	__body = __scene.instantiate()
	if !(__body is Node3D):
		push_error("The `scene` must be a Node3D.")
		__scene = __SCENE_DEFAULT
		__body = __scene.instantiate()
	__head_started = false
	add_child(__body)
	
	__head_y = head_y_target
	__body.global_position = __parent.global_position


## Set an arbitrary info field in an info group.
##
## Such as [code]"actions", "jump", true[/code], or [code]"env", "surface", "wood"[/code].
## The info can be read and written by any party to determine the state and evolution
## of the model.
##
## Suggested groups:
## * actions - processed input from controllers: where to go, how fast, etc.
## * envs - pawn surrounding environment: surface, sound filters, wind, gravity.
## * states - pawn internal state: crouch, swim, ladder.
## * traits - pawn specific abilities, items and levels: hp, boosts, inventory.
func set_info(group_name: String, field_name: String, value: Variant) -> void:
	if !__info.has(group_name):
		__info[group_name] = {}
	__info[group_name][field_name] = value


## Clear an info group by name, or wipe all groups if name is empty.
func reset_info(group_name: String = "") -> void:
	if !group_name:
		__info.clear()
		return
	
	if !__info.has(group_name):
		return
	
	__info[group_name].clear()


## Produce an event from this pawn with optional data.
func trigger(trigger_name: String, value: Variant = null) -> void:
	triggered.emit(trigger_name, value)


## Fetch an info field by group name and field name.
##
## If the field has never been set or [code]reset_info[/code] has just been called,
## this method returns [code]default_value[/code].
func get_info(group_name: String, field_name: String, default_value: Variant = null) -> Variant:
	if !__info.has(group_name):
		return default_value
	
	var group: Dictionary = __info[group_name]
	if !group.has(field_name):
		return default_value
	
	return group[field_name]


## Check if the input info exists.
func has_info(group_name: String, field_name: String) -> bool:
	if !__info.has(group_name):
		return false
	
	return __info[group_name].has(field_name)


## Erase the input value.
func erase_info(group_name: String, field_name: String) -> bool:
	if !__info.has(group_name):
		return false
	
	var group: Dictionary = __info[group_name]
	if !group.has(field_name):
		return false
	
	return group.erase(field_name)


## Shortcut for [code]set_info("actions", field_name, value)[/code]
func set_action(field_name: String, value: Variant) -> void:
	set_info("actions", field_name, value)

## Shortcut for [code]reset_info("actions")[/code]
func reset_actions() -> void:
	reset_info("actions")

## Shortcut for [code]get_info("actions", field_name, default_value)[/code]
func get_action(field_name: String, default_value: Variant = null) -> Variant:
	return get_info("actions", field_name, default_value)

## Shortcut for [code]has_info("actions", field_name)[/code]
func has_action(field_name: String) -> bool:
	return has_info("actions", field_name)

## Shortcut for [code]erase_info("actions", field_name)[/code]
func erase_action(field_name: String) -> bool:
	return erase_info("actions", field_name)


## Shortcut for [code]set_info("envs", field_name, value)[/code]
func set_env(field_name: String, value: Variant) -> void:
	set_info("envs", field_name, value)

## Shortcut for [code]reset_info("envs")[/code]
func reset_envs() -> void:
	reset_info("envs")

## Shortcut for [code]get_info("envs", field_name, default_value)[/code]
func get_env(field_name: String, default_value: Variant = null) -> Variant:
	return get_info("envs", field_name, default_value)

## Shortcut for [code]has_info("envs", field_name)[/code]
func has_env(field_name: String) -> bool:
	return has_info("envs", field_name)

## Shortcut for [code]erase_info("envs", field_name)[/code]
func erase_env(field_name: String) -> bool:
	return erase_info("envs", field_name)


## Shortcut for [code]set_info("states", field_name, value)[/code]
func set_state(field_name: String, value: Variant) -> void:
	set_info("states", field_name, value)

## Shortcut for [code]reset_info("states")[/code]
func reset_states() -> void:
	reset_info("states")

## Shortcut for [code]get_info("states", field_name, default_value)[/code]
func get_state(field_name: String, default_value: Variant = null) -> Variant:
	return get_info("states", field_name, default_value)

## Shortcut for [code]has_info("states", field_name)[/code]
func has_state(field_name: String) -> bool:
	return has_info("states", field_name)

## Shortcut for [code]erase_info("states", field_name)[/code]
func erase_state(field_name: String) -> bool:
	return erase_info("states", field_name)


## Shortcut for [code]set_info("traits", field_name, value)[/code]
func set_trait(field_name: String, value: Variant) -> void:
	set_info("traits", field_name, value)

## Shortcut for [code]reset_info("traits")[/code]
func reset_traits() -> void:
	reset_info("traits")

## Shortcut for [code]get_info("traits", field_name, default_value)[/code]
func get_trait(field_name: String, default_value: Variant = null) -> Variant:
	return get_info("traits", field_name, default_value)

## Shortcut for [code]has_info("traits", field_name)[/code]
func has_trait(field_name: String) -> bool:
	return has_info("traits", field_name)

## Shortcut for [code]erase_info("traits", field_name)[/code]
func erase_trait(field_name: String) -> bool:
	return erase_info("traits", field_name)


func __check_handler(handler: GsomPawnHandler) -> bool:
	if handler.disabled:
		return false
	
	for env_name: String in handler.include_envs:
		if !has_env(env_name):
			return false
	
	for env_name: String in handler.exclude_envs:
		if has_env(env_name):
			return false
	
	for state_name: String in handler.include_states:
		if !has_state(state_name):
			return false
	
	for state_name: String in handler.exclude_states:
		if has_state(state_name):
			return false
	
	return true

func __do_integrate_handler(handler: GsomPawnHandler, state: PhysicsDirectBodyState3D) -> void:
	if __check_handler(handler):
		handler._do_integrate(self, state)


## Framework method, should be called by [code]scene[/code] instance on [code]_integrate_forces[/code].
func do_integrate(state: PhysicsDirectBodyState3D) -> void:
	for child: Node in get_children():
		if child is GsomPawnHandler:
			var handler: GsomPawnHandler = child
			__do_integrate_handler(handler, state)


func __do_process_handler(handler: GsomPawnHandler, dt: float) -> void:
	if __check_handler(handler):
		handler._do_process(self, dt)


## Framework method, should be called by [code]scene[/code] instance on [code]_process[/code].
func do_process(dt: float) -> void:
	for child: Node in get_children():
		if child is GsomPawnHandler:
			var handler: GsomPawnHandler = child
			__do_process_handler(handler, dt)


func __do_physics_handler(handler: GsomPawnHandler, dt: float) -> void:
	if __check_handler(handler):
		handler._do_physics(self, dt)


## Framework method, should be called by [code]scene[/code] instance on [code]_physics_process[/code].
func do_physics(dt: float) -> void:
	for child: Node in get_children():
		if child is GsomPawnHandler:
			var handler: GsomPawnHandler = child
			__do_physics_handler(handler, dt)
	
	if track_accel_linear and has_velocity_linear:
		@warning_ignore("unsafe_property_access")
		var dvell: Vector3 = (__body.linear_velocity - __cached_vell)
		if dvell.length_squared() > 0.0001:
			accelerated_linear.emit(dvell, dvell / dt)
	
	if has_velocity_linear:
		@warning_ignore("unsafe_property_access")
		__cached_vell = __body.linear_velocity
	
	if track_accel_angular and has_velocity_angular:
		@warning_ignore("unsafe_property_access")
		var dvela: Vector3 = (__body.angular_velocity - __cached_vela)
		if dvela.length_squared() > 0.0001:
			accelerated_angular.emit(dvela, dvela / dt)
	
	if has_velocity_angular:
		@warning_ignore("unsafe_property_access")
		__cached_vela = __body.angular_velocity
	
	__parent.global_position = __body.global_position
	moved.emit(__body.global_position)


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	
	__head_started = true
	if __head_y == head_y_target:
		return
	
	if head_y_target > __head_y:
		__head_y = minf(__head_y + head_speed * dt, head_y_target)
	else:
		__head_y = maxf(__head_y - head_speed * dt, head_y_target)
	
	moved_head.emit(__head_y)


func _physics_process(_dt: float) -> void:
	if Engine.is_editor_hint():
		__body.global_position = __parent.global_position
