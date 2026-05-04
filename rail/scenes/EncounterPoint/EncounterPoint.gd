@tool
extends Node3D
class_name EncounterPoint

@export var startActions : Array[EncounterAction] = []
@export var endActions : Array[EncounterAction] = []
@export var conditions : Array[EncounterCondition]= []
@export var one_shot : bool = false
@export var disc_color : Color = Color(0, 0, 0.427451, 1):
	set(v):
		disc_color = v
		_apply_disc_color()
var _has_triggered : bool = false
var _starting : bool = false
var _ending : bool = false
var conditionsMet : bool
var enemies : Array[Enemy]
var active : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !Engine.is_editor_hint():
		# Snap to floor after physics is ready
		_snapToFloor.call_deferred()
		# Check for bodies already overlapping at spawn
		_check_initial_overlap.call_deferred()
		if SettingsManager.debug_show_stations:
			_showCollisionDebug()
		else:
			_hideMeshes()
	_apply_disc_color()
	var children = get_children()
	for child in children:
		if child is Enemy:
			var enemy : Enemy = child
			enemy.died.connect(_onEnemyDied)
			enemies.append(enemy)

func _check_initial_overlap() -> void:
	var area = get_node_or_null("CollisionArea") as Area3D
	if area == null:
		print("[OVERLAP] %s: no CollisionArea found" % name)
		return
	print("[OVERLAP] %s: area found, monitoring=%s, layer=%d, mask=%d" % [name, area.monitoring, area.collision_layer, area.collision_mask])
	# Need to wait for physics to run before overlaps are available
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bodies = area.get_overlapping_bodies()
	print("[OVERLAP] %s: found %d overlapping bodies" % [name, bodies.size()])
	for body in bodies:
		print("[OVERLAP] %s: overlapping with %s (layer=%d)" % [name, body.name, body.collision_layer])
		_onCollisionAreaBodyEntered(body)

func _snapToFloor() -> void:
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return
	
	var from = global_position
	var to = global_position + Vector3.DOWN * 100.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Adjust mask if floor is on different layer
	
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y

func _apply_disc_color() -> void:
	if not is_inside_tree():
		return
	var outer = get_node_or_null("EncounterMesh")
	var inner = get_node_or_null("CollisionArea/CenterMesh")
	if outer and outer.mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = disc_color
		outer.mesh = outer.mesh.duplicate()
		outer.mesh.material = mat
	if inner and inner.mesh:
		var complement = Color.from_hsv(fmod(disc_color.h + 0.5, 1.0), disc_color.s, disc_color.v)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = complement
		inner.mesh = inner.mesh.duplicate()
		inner.mesh.material = mat

func _hideMeshes():
	var outer = get_node_or_null("EncounterMesh")
	if outer:
		outer.hide()
	var inner = get_node_or_null("CenterMesh")
	if inner:
		inner.hide()
	if not inner:
		inner = get_node_or_null("CollisionArea/CenterMesh")
		if inner:
			inner.hide()

func _showCollisionDebug():
	var shape_node = get_node_or_null("CollisionArea/CollisionAreaShape") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return
	var cyl = shape_node.shape as CylinderShape3D
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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !active or _starting or _ending:
		return
	_checkConditions()
	if conditionsMet:
		endEncounter()

func _checkConditions() -> void:
	if conditions == null || conditions.size() == 0:
		conditionsMet = true
		return
	for condition in conditions:
		if !condition.check(self):
			conditionsMet = false
			return
	conditionsMet = true

func _onCollisionAreaBodyEntered(body: Node3D) -> void:
	if one_shot and _has_triggered:
		return
	if body is Player:
		var player : Player = body
		player.setCurrentEncounter(self)

func _onEnemyDied(enemy : Enemy) -> void:
	enemies.erase(enemy)

func _runActions(actions : Array[EncounterAction]):
	for action in actions:
		if action == null:
			continue
		action._finished = false
		action.run(self)
		if action.blocking && !action.isFinished():
			await action.finished

func startEncounter() -> void:
	_has_triggered = true
	EventBus.startEncounter.emit()
	active = true
	_starting = true
	await _runActions(startActions)
	_starting = false

func endEncounter() -> void:
	_ending = true
	await _runActions(endActions)
	active = false
	_ending = false
