@tool
extends Node3D
class_name RailNetwork

@onready var railsNode: Node = %Rails

var _dirty := false

func _ready() -> void:
	if !Engine.is_editor_hint():
		return
	_connect_station_signals()
	set_process(true)

func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	if _dirty:
		_dirty = false
		_regenerate_paths()

func _notification(what: int) -> void:
	if !Engine.is_editor_hint():
		return
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		# Stations may have been added/removed/reordered
		_connect_station_signals()

# --- stations wiring ---

func _connect_station_signals() -> void:
	# Disconnect old
	for s in get_tree().get_nodes_in_group("rail_stations"):
		if s.is_connected("station_changed", Callable(self, "_on_station_changed")):
			s.disconnect("station_changed", Callable(self, "_on_station_changed"))
	# Connect current
	for s in get_tree().get_nodes_in_group("rail_stations"):
		s.connect("station_changed", Callable(self, "_on_station_changed"))
	_dirty = true

func _on_station_changed() -> void:
	print('station')
	_dirty = true

# ---- Core generation ----

func _regenerate_paths() -> void:
	var stations: Array = get_tree().get_nodes_in_group("rail_stations")
	var connections := _collect_connections(stations)  # Array of {from: RailStation, to: RailStation}

	# Index existing RailPaths by connection key
	var existing: Dictionary = {}
	for c in railsNode.get_children():
		if c is RailPath:
			var from_node := c.get_node_or_null(c.from_station)
			var to_node   := c.get_node_or_null(c.to_station)
			var key := _conn_key(from_node, to_node)
			if key != "":
				existing[key] = c

	# Create/update paths for all connections
	for conn in connections:
		var from: RailStation = conn.from
		var to: RailStation   = conn.to
		if from == null or to == null:
			continue

		var key := _conn_key(from, to)
		var railPath: RailPath = existing.get(key, null)

		if railPath == null:
			railPath = RailPath.new()
			railPath.name = key
			railsNode.add_child(railPath)
			if get_tree() != null and get_tree().edited_scene_root != null:
				railPath.owner = get_tree().edited_scene_root

			# IMPORTANT (Option A): store NodePaths RELATIVE TO railPath
			railPath.from_station = railPath.get_path_to(from)
			railPath.to_station   = railPath.get_path_to(to)

		# Only (re)write curve if autogen is allowed
		if railPath.autogen_enabled:
			_write_straight_curve(railPath, from, to)

	# Remove autogen paths for connections that no longer exist
	for c in railsNode.get_children():
		if c is RailPath and c.autogen_enabled:
			var from_node := c.get_node_or_null(c.from_station)
			var to_node   := c.get_node_or_null(c.to_station)
			var k := _conn_key(from_node, to_node)
			if k == "":
				c.queue_free()
				continue
			var still_exists := false
			for conn in connections:
				if _conn_key(conn.from, conn.to) == k:
					still_exists = true
					break
			if !still_exists:
				c.queue_free()

func _collect_connections(stations: Array) -> Array:
	var seen := {}
	var out: Array = []
	for s in stations:
		if !(s is RailStation):
			continue
		for t in s.resolve_next_stations():
			if t == null or t == s:
				continue
			var key = _conn_key(s, t)
			if !seen.has(key):
				seen[key] = true
				out.append({ "from": s, "to": t })
	return out

func _conn_key(a: Node, b: Node) -> String:
	if a == null or b == null:
		return ""
	# Directed: A->B and B->A are distinct
	return "%s__TO__%s" % [a.name, b.name]

func _write_straight_curve(path: RailPath, from: RailStation, to: RailStation) -> void:
	var curve := Curve3D.new()
	var p0 = path.to_local(from.global_transform.origin)
	var p1 = path.to_local(to.global_transform.origin)
	curve.add_point(p0)
	curve.add_point(p1)

	path.curve = curve
	path.transform = Transform3D.IDENTITY

	# Simple editor-visible line (optional convenience)
	var viz := path.get_node_or_null("PathViz") as MeshInstance3D
	if viz == null:
		viz = MeshInstance3D.new()
		viz.name = "PathViz"
		path.add_child(viz)
		if get_tree() != null and get_tree().edited_scene_root != null:
			viz.owner = get_tree().edited_scene_root
	viz.mesh = _make_line_mesh(p0, p1)

func _make_line_mesh(a: Vector3, b: Vector3) -> Mesh:
	var mm := ImmediateMesh.new()
	mm.surface_begin(Mesh.PRIMITIVE_LINES)
	mm.surface_add_vertex(a)
	mm.surface_add_vertex(b)
	mm.surface_end()

	# Unshaded material so it’s visible in the editor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.surface_set_material(0, mat)
	return mm
