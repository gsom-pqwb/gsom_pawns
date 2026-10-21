@icon("./pawn_env.svg")
extends Node
class_name GsomPawnEnv

## Environment description for GsomPawn
##
## Attach an env to Area3D. Depending on behavior,
## it will apply and/or remove an env field on all entering and/or exiting pawns.
## The default env data is [code]{}[/code], empty dictionary.

## Types of pawn env behavior.
enum EnvBehavior {
	## Only apply the Env when pawn enters the area, do nothing on exit.
	ENTER_APPLY,
	## Only remove the Env when pawn enters the area, do nothing on exit.
	ENTER_REMOVE,
	## Default: apply on entry, restore another overlapping source or remove on exit.
	ENTER_APPLY_EXIT_REMOVE,
	## Inverse: remove when pawn enters, apply on exit.
	ENTER_REMOVE_EXIT_APPLY,
	## Only apply the Env when pawn exits the area, do nothing on enter.
	EXIT_APPLY,
	## Only remove the Env when pawn exits the area, do nothing on enter.
	EXIT_REMOVE,
}


## Env info field name to edit.
@export var env_name: String = ""

## Env value to be assigned. Default is [code]{}[/code], empty dictionary.
@export var env_value: Dictionary = {}

## When the Env should be applied and removed.
@export var behavior: EnvBehavior = EnvBehavior.ENTER_APPLY_EXIT_REMOVE

## Doesn't do anything, when disabled.
@export var disabled: bool = false


## Pawn info group containing weak environment sources, ordered by last entry.
const SOURCES: String = "gsom_env_sources"

var __area: WeakRef
var __pawns: Dictionary[int, WeakRef] = {}
var __bodies: Dictionary[int, WeakRef] = {}


func _enter_tree() -> void:
	attach()


func _exit_tree() -> void:
	__detach()
	for pawn_id: int in __pawns.keys():
		__on_body_exiting(pawn_id)


## Active sources for the default enter/apply, exit/remove behavior.
## The last source supplies the current environment value.
static func sources_of(pawn: GsomPawn, field_name: String) -> Array[GsomPawnEnv]:
	var sources: Array[GsomPawnEnv] = []
	var refs: Array[WeakRef] = []
	refs.assign(pawn.get_info(SOURCES, field_name, []))
	for source_ref: WeakRef in refs:
		var source: GsomPawnEnv = source_ref.get_ref() as GsomPawnEnv
		if is_instance_valid(source):
			sources.append(source)
	return sources


func __store_sources(pawn: GsomPawn, sources: Array[GsomPawnEnv]) -> void:
	if sources.is_empty():
		pawn.erase_info(SOURCES, env_name)
		pawn.erase_env(env_name)
		return
	var refs: Array[WeakRef] = []
	for source: GsomPawnEnv in sources:
		refs.append(weakref(source))
	pawn.set_info(SOURCES, env_name, refs)
	pawn.set_env(env_name, sources.back().env_value)


func __on_body_exiting(pawn_id: int) -> void:
	if not __pawns.has(pawn_id):
		return
	var pawn: GsomPawn = __pawns[pawn_id].get_ref() as GsomPawn
	if is_instance_valid(pawn):
		_erase_env(pawn)
	else:
		__untrack(pawn_id)


func __untrack(pawn_id: int) -> void:
	var body: Node3D = __bodies[pawn_id].get_ref() as Node3D if __bodies.has(pawn_id) else null
	var callback: Callable = __on_body_exiting.bind(pawn_id)
	if is_instance_valid(body) and body.tree_exiting.is_connected(callback):
		body.tree_exiting.disconnect(callback)
	__bodies.erase(pawn_id)
	__pawns.erase(pawn_id)


func _ready() -> void:
	attach()


func __detach() -> void:
	var area: Area3D = __area.get_ref() as Area3D if __area != null else null
	if is_instance_valid(area):
		if area.body_entered.is_connected(__on_entered):
			area.body_entered.disconnect(__on_entered)
		if area.body_exited.is_connected(__on_exited):
			area.body_exited.disconnect(__on_exited)
	__area = null


## Called automatically on tree entry; also safe to call explicitly.
func attach() -> void:
	__detach()
	var parent: Node = get_parent()
	if parent is not Area3D:
		return
	
	var parent_area: Area3D = parent
	__area = weakref(parent_area)
	if not parent_area.body_entered.is_connected(__on_entered):
		parent_area.body_entered.connect(__on_entered)
	if not parent_area.body_exited.is_connected(__on_exited):
		parent_area.body_exited.connect(__on_exited)


## Called to assign the env value.
##
## Override this for custom envs.
func _apply_env(pawn: GsomPawn) -> void:
	if behavior != EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
		pawn.set_env(env_name, env_value)
		return
	var sources: Array[GsomPawnEnv] = sources_of(pawn, env_name)
	sources.erase(self)
	sources.append(self)
	__store_sources(pawn, sources)
	var pawn_id: int = pawn.get_instance_id()
	if not __pawns.has(pawn_id):
		__pawns[pawn_id] = weakref(pawn)
		__bodies[pawn_id] = weakref(pawn.body)
		pawn.body.tree_exiting.connect(__on_body_exiting.bind(pawn_id))


## Called to remove the env value.
##
## Override this for custom envs.
func _erase_env(pawn: GsomPawn) -> void:
	if behavior != EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
		pawn.erase_env(env_name)
		return
	__untrack(pawn.get_instance_id())
	var sources: Array[GsomPawnEnv] = sources_of(pawn, env_name)
	if not sources.has(self):
		return
	sources.erase(self)
	__store_sources(pawn, sources)


func __on_entered(body: Node3D) -> void:
	if disabled:
		return
	
	if behavior == EnvBehavior.EXIT_APPLY or behavior == EnvBehavior.EXIT_REMOVE:
		return
	
	var pawn: GsomPawn = body.get_parent() as GsomPawn
	if !pawn:
		return
	
	if behavior == EnvBehavior.ENTER_APPLY or behavior == EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
		_apply_env(pawn)
		return
	
	if behavior == EnvBehavior.ENTER_REMOVE or behavior == EnvBehavior.ENTER_REMOVE_EXIT_APPLY:
		_erase_env(pawn)
		return


func __on_exited(body: Node3D) -> void:
	if disabled and behavior != EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
		return
	
	if behavior == EnvBehavior.ENTER_APPLY or behavior == EnvBehavior.ENTER_REMOVE:
		return
	
	var pawn: GsomPawn = body.get_parent() as GsomPawn
	if !pawn:
		return
	
	if behavior == EnvBehavior.EXIT_APPLY or behavior == EnvBehavior.ENTER_REMOVE_EXIT_APPLY:
		_apply_env(pawn)
		return
	
	if behavior == EnvBehavior.EXIT_REMOVE or behavior == EnvBehavior.ENTER_APPLY_EXIT_REMOVE:
		_erase_env(pawn)
		return
