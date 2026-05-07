@tool
extends Node3D
class_name RailMarker

## Base class for any "thing the player walks into on the rail." Owns the
## visual disc, the trigger Area3D, the disc-color fade-in, debug viz,
## one-shot guarding, and a list of conditions that gate firing.
##
## Subclasses override _on_player_entered(player) to define what happens.
## Conditions: by default checked once at entry. EncounterPoint overrides
## the lifecycle to keep polling them until they pass.

@export var conditions : Array[EncounterCondition]= []
@export var one_shot : bool = false
@export var disc_color : Color = Color(0, 0, 0.427451, 1):
	set(v):
		disc_color = v
		_apply_disc_color()

var _has_triggered : bool = false
var enemies : Array[Enemy]

func _ready() -> void:
	if !Engine.is_editor_hint():
		print("[MARKER] %s: _ready at pos=%s" % [name, global_position])
		_snapToFloor.call_deferred()
		_check_initial_overlap.call_deferred()
		if SettingsManager.debug_show_stations:
			_showCollisionDebug()
		else:
			_hideMeshes()
	_apply_disc_color()
	for child in get_children():
		if child is Enemy:
			var enemy : Enemy = child
			enemy.died.connect(_onEnemyDied)
			enemies.append(enemy)

func _check_initial_overlap() -> void:
	var area = get_node_or_null("CollisionArea") as Area3D
	if area == null:
		print("[MARKER] %s: no CollisionArea found" % name)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bodies = area.get_overlapping_bodies()
	var player = Game.getPlayer()
	var player_pos = player.global_position if player != null else Vector3.INF
	var dist = global_position.distance_to(player_pos) if player != null else -1.0
	print("[MARKER] %s: initial_overlap check  pos=%s  player=%s  dist=%.1f  overlapping=%d  bodies=%s" % [
		name, global_position, player_pos, dist, bodies.size(), bodies.map(func(b): return b.name)])
	# Also print collision shape info
	for child in area.get_children():
		if child is CollisionShape3D and child.shape != null:
			print("[MARKER] %s: collision shape=%s  radius=%.1f" % [name, child.shape.get_class(), child.shape.get("radius") if child.shape.get("radius") != null else -1])
	for body in bodies:
		_onCollisionAreaBodyEntered(body)

func _snapToFloor() -> void:
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return
	var from = global_position
	var to = global_position + Vector3.DOWN * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y

func _apply_disc_color() -> void:
	if not is_inside_tree():
		return
	var outer := get_node_or_null("EncounterMesh") as MeshInstance3D
	var inner := get_node_or_null("CollisionArea/CenterMesh") as MeshInstance3D
	if outer != null and outer.mesh != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = disc_color
		outer.material_override = mat
	if inner != null and inner.mesh != null:
		var complement := Color.from_hsv(fmod(disc_color.h + 0.5, 1.0), disc_color.s, disc_color.v)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = complement
		inner.material_override = mat

func _hideMeshes() -> void:
	var outer = get_node_or_null("EncounterMesh")
	if outer:
		outer.hide()
	var inner = get_node_or_null("CenterMesh")
	if inner:
		inner.hide()
	if inner == null:
		inner = get_node_or_null("CollisionArea/CenterMesh")
		if inner:
			inner.hide()

func _showCollisionDebug() -> void:
	var shape_node = get_node_or_null("CollisionArea/CollisionAreaShape") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	var cyl := shape_node.shape as CylinderShape3D
	if cyl == null:
		return
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "CollisionDebugMesh"
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = cyl.radius
	cylinder_mesh.bottom_radius = cyl.radius
	cylinder_mesh.height = cyl.height
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cylinder_mesh.material = mat
	mesh_inst.mesh = cylinder_mesh
	mesh_inst.position = shape_node.position
	add_child(mesh_inst)

func _checkConditionsOnce() -> bool:
	if conditions == null or conditions.size() == 0:
		return true
	for condition in conditions:
		if condition == null:
			continue
		if !condition.check(self):
			return false
	return true

func _onCollisionAreaBodyEntered(body: Node3D) -> void:
	if one_shot and _has_triggered:
		return
	if body is Player:
		_on_player_entered(body)

## Override in subclasses. Default: no-op.
func _on_player_entered(_player: Player) -> void:
	pass

func _onEnemyDied(enemy : Enemy) -> void:
	enemies.erase(enemy)
