extends GsomPawnTrigger
class_name Teleport

@export var tag: String = ""
@export var dest: String = ""


# Keep the own script type out of the persistent default container.
static var __teleports: Array[Node] = []


func _ready() -> void:
	__teleports.append(self)
	self.attach()


func _exit_tree() -> void:
	__teleports.erase(self)


static func find_by_tag(dest_tag: String) -> Teleport:
	for entry: Node in __teleports:
		if not is_instance_valid(entry) or not entry is Teleport:
			push_error("Invalid teleport registry entry")
			return null
		var tp: Teleport = entry
		if tp.tag == dest_tag:
			return tp
	return null


static func find_target_by_tag(dest_tag: String) -> Node3D:
	var dest_teleport: Teleport = find_by_tag(dest_tag)
	if !dest_teleport:
		return null
	
	var parent_3d := dest_teleport.get_parent() as Node3D
	if !parent_3d:
		return null
	
	return parent_3d


func _trigger_enter(pawn: GsomPawn) -> void:
	var parent_3d: Node3D = find_target_by_tag(dest)
	if !parent_3d:
		push_warning("Teleport - destination is not found or not in Node3D.")
		return
	
	pawn.trigger("teleport", { "pos": parent_3d.global_position })
	
	__try_play_sound()


func __try_play_sound() -> void:
	for child: Node in get_children():
		if child.has_method("play"):
			child.call("play")
			break
