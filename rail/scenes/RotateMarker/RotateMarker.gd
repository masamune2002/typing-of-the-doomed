@tool
extends RailMarker
class_name RotateMarker

## A floor arrow that rotates the player's camera to face the arrow's
## forward direction (-Z) when the player walks over it.
##
## Conditions: checked once when the player enters. If they fail, the
## marker does nothing and resets (next entry re-checks). This differs
## from EncounterPoint, which polls conditions while the player owns
## the encounter.

@export_range(0.05, 5.0, 0.05) var rotation_duration : float = 0.35
@export var also_pitch : bool = false
@export_range(-89, 89) var pitch_degrees : float = 0.0

func _ready() -> void:
	super._ready()
	_ensure_arrow_mesh()

func _ensure_arrow_mesh() -> void:
	var mesh_node := get_node_or_null("EncounterMesh") as MeshInstance3D
	if mesh_node == null:
		return
	mesh_node.mesh = _build_arrow_mesh()
	_apply_disc_color()

func _build_arrow_mesh() -> ArrayMesh:
	# Flat arrow lying on the XZ plane, pointing along -Z (Godot forward).
	# Shape: a rectangular shaft and a wider triangular head.
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()

	var y := 0.01  # tiny lift to avoid z-fighting with the floor

	# Shaft rectangle: x ± 0.10, z from +0.30 (back) to -0.05 (front-of-shaft)
	var shaft_back_l   := Vector3(-0.10, y,  0.30)
	var shaft_back_r   := Vector3( 0.10, y,  0.30)
	var shaft_front_l  := Vector3(-0.10, y, -0.05)
	var shaft_front_r  := Vector3( 0.10, y, -0.05)

	# Head triangle: base across x ± 0.25 at z = -0.05, tip at z = -0.40
	var head_base_l    := Vector3(-0.25, y, -0.05)
	var head_base_r    := Vector3( 0.25, y, -0.05)
	var head_tip       := Vector3( 0.00, y, -0.40)

	verts.append(shaft_back_l)    # 0
	verts.append(shaft_back_r)    # 1
	verts.append(shaft_front_l)   # 2
	verts.append(shaft_front_r)   # 3
	verts.append(head_base_l)     # 4
	verts.append(head_base_r)     # 5
	verts.append(head_tip)        # 6

	for _i in 7:
		normals.append(Vector3.UP)

	# Shaft: two triangles, CCW from above (y up)
	indices.append_array([0, 2, 1,   1, 2, 3])
	# Head: one triangle
	indices.append_array([4, 6, 5])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _on_player_entered(player: Player) -> void:
	if !_checkConditionsOnce():
		return
	_has_triggered = true
	# Aim at a point one unit ahead of the marker along its -Z direction,
	# at the player's eye height so pitch isn't perturbed unintentionally.
	var forward := -global_transform.basis.z.normalized()
	var look_target := global_position + forward * 5.0
	look_target.y = player.global_position.y + 1.0
	player.lookAtPosition(look_target, rotation_duration)
	if also_pitch:
		var yaw_delta := 0.0  # already handled by lookAtPosition
		player.rotateByDegrees(yaw_delta, pitch_degrees, rotation_duration)
