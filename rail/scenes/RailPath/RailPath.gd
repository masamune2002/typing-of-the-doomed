@tool
extends Path3D
class_name RailPath

@export var autogen_enabled := true
@export var from_station: NodePath
@export var to_station: NodePath

@export_group("Editor Viz")
@export var show_viz := true:
	set(v):
		show_viz = v
		_refresh_viz()
@export var samples_hint := 32:            # only used when tessellating fallback
	set(v):
		samples_hint = max(2, v)
		_refresh_viz()

var _viz: MeshInstance3D
var _last_hash: int = 0

func _ready() -> void:
	add_to_group("rail_paths")
	if Engine.is_editor_hint():
		_ensure_viz()
		_refresh_viz()
		set_process(true)

func _process(delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	var h := _compute_state_hash()
	if h != _last_hash:
		_last_hash = h
		_refresh_viz()

func _notification(what: int) -> void:
	if !Engine.is_editor_hint():
		return
	# Rebuild if moved/scaled/rotated in editor
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_refresh_viz()

# ---------------- helpers ----------------

func _ensure_viz() -> void:
	# Reuse an existing PathViz from the scene tree if present (avoids
	# accumulating duplicate MeshInstance3D children across reloads).
	if _viz == null or !is_instance_valid(_viz) or _viz.get_parent() != self:
		_viz = get_node_or_null("PathViz") as MeshInstance3D
	if _viz == null:
		_viz = MeshInstance3D.new()
		_viz.name = "PathViz"
		add_child(_viz)
		# Intentionally do NOT set owner — viz is editor-only and should
		# not be serialized into the scene.

	# One-shot cleanup of stray viz duplicates left over by older versions
	# of this script (children named like @MeshInstance3D@NNNNN, plus any
	# extra MeshInstance3Ds that aren't our kept PathViz).
	for child in get_children():
		if child == _viz:
			continue
		if child is MeshInstance3D:
			child.queue_free()

func _compute_state_hash() -> int:
	var s := str(show_viz) + "|" + str(global_transform)
	if curve:
		s += "|" + str(curve.get_point_count())
		for i in curve.get_point_count():
			s += "|" + str(curve.get_point_position(i)) + str(curve.get_point_in(i)) + str(curve.get_point_out(i))
	return s.hash()

func _refresh_viz() -> void:
	_ensure_viz()
	if _viz == null:
		return

	_viz.visible = show_viz
	if !show_viz:
		_viz.mesh = null
		return

	var pts := _get_polyline_points()
	if pts.size() < 2:
		_viz.mesh = null
		return

	_viz.mesh = _make_line_mesh(pts)

func _get_polyline_points() -> PackedVector3Array:
	if curve == null:
		return PackedVector3Array()
	# Prefer baked points if available (stable in 4.x)
	if curve.has_method("get_baked_points"):
		var baked := curve.get_baked_points()
		if baked.size() >= 2:
			return baked
	# Fallback to tessellation
	if curve.has_method("tessellate"):
		var t := curve.tessellate()  # default args are fine for editor viz
		if t.size() >= 2:
			return t
	# Final fallback: first/last
	var out := PackedVector3Array()
	if curve.get_point_count() >= 2:
		out.append(curve.get_point_position(0))
		out.append(curve.get_point_position(curve.get_point_count() - 1))
	return out

func _make_line_mesh(pts: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	# Expand polyline into line segments (v0,v1),(v1,v2),...
	var verts := PackedVector3Array()
	verts.resize((pts.size() - 1) * 2)
	var idx := 0
	for i in range(pts.size() - 1):
		verts[idx] = pts[i]
		verts[idx + 1] = pts[i + 1]
		idx += 2

	arrays[Mesh.ARRAY_VERTEX] = verts

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	# Unshaded material so it’s visible regardless of lighting
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, mat)

	return mesh
