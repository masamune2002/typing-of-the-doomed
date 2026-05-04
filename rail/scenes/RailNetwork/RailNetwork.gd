@tool
extends Node3D
class_name RailNetwork

enum ViewMode { SHOW_ALL, FOCUS_STATION, RAILS_ONLY, STATIONS_ONLY }

@export_group("Editor View")
@export var view_mode: ViewMode = ViewMode.SHOW_ALL:
	set(v):
		view_mode = v
		_apply_view_mode()

var _dirty := false
var _last_focused: RailStation = null

func _ready() -> void:
	if !Engine.is_editor_hint():
		# Ensure everything is visible at runtime regardless of editor view mode
		_reset_all_visible()
		return
	set_process(true)

func _reset_all_visible() -> void:
	var stations_container := get_node_or_null("Stations")
	if stations_container:
		for s in stations_container.get_children():
			s.visible = true
			for r in s.get_children():
				if r is RailPath:
					r.visible = true

func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		return
	_poll_stations()
	if _dirty:
		_dirty = false
		_regenerate_paths()
		_apply_view_mode()
	elif view_mode == ViewMode.FOCUS_STATION:
		var focused := _get_selected_station()
		if focused != _last_focused:
			_last_focused = focused
			_apply_view_mode()

func _notification(what: int) -> void:
	if !Engine.is_editor_hint():
		return
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		# Stations may have been added/removed/reordered — defer to avoid re-entrancy
		_dirty = true

# --- station polling (replaces signals to avoid freed-object errors) ---

var _last_station_hash: int = 0

func _poll_stations() -> void:
	if get_tree() == null:
		return
	var h := _compute_station_hash()
	if h != _last_station_hash:
		_last_station_hash = h
		_dirty = true

func _compute_station_hash() -> int:
	var s := ""
	for station in get_tree().get_nodes_in_group("rail_stations"):
		if not is_instance_valid(station):
			continue
		s += station.name + "|" + str(station.global_transform) + "|"
		for np in station.next_stations:
			s += str(np) + ","
		s += ";"
	return s.hash()

# ---- Core generation ----

func _regenerate_paths() -> void:
	var raw_stations: Array = get_tree().get_nodes_in_group("rail_stations")
	var stations: Array = []
	for s in raw_stations:
		if is_instance_valid(s):
			stations.append(s)
	var connections := _collect_connections(stations)  # Array of {from: RailStation, to: RailStation}

	# Index existing RailPaths by connection key (paths are children of their from-station)
	var existing: Dictionary = {}
	for s in stations:
		for c in s.get_children():
			if c is RailPath:
				var from_node = c.get_node_or_null(c.from_station)
				var to_node   = c.get_node_or_null(c.to_station)
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
			from.add_child(railPath)
			if get_tree() != null and get_tree().edited_scene_root != null:
				railPath.owner = get_tree().edited_scene_root

			# Store NodePaths RELATIVE TO railPath
			railPath.from_station = railPath.get_path_to(from)
			railPath.to_station   = railPath.get_path_to(to)

		# Only (re)write curve if autogen is allowed
		if railPath.autogen_enabled:
			_write_straight_curve(railPath, from, to)

	# Remove autogen paths for connections that no longer exist
	for s in stations:
		for c in s.get_children():
			if c is RailPath and c.autogen_enabled:
				var from_node = c.get_node_or_null(c.from_station)
				var to_node   = c.get_node_or_null(c.to_station)
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

	# RailPath owns its own viz; ask it to refresh after the curve change.
	if path.has_method("_refresh_viz"):
		path._refresh_viz()

# ---- Editor view mode ----

func _get_selected_station() -> RailStation:
	var selection := EditorInterface.get_selection()
	if selection == null:
		return null
	var selected := selection.get_selected_nodes()
	for node in selected:
		# Check the node itself or walk up to find a RailStation ancestor
		var current := node
		while current != null and current != self:
			if current is RailStation:
				return current as RailStation
			current = current.get_parent()
	return null

func _apply_view_mode() -> void:
	if !Engine.is_editor_hint() or !is_inside_tree():
		return

	var stations_container := get_node_or_null("Stations")
	if stations_container == null:
		return

	var all_stations: Array[Node] = []
	for s in stations_container.get_children():
		if s is RailStation:
			all_stations.append(s)

	var all_rails: Array[Node] = []
	for s in all_stations:
		for r in s.get_children():
			if r is RailPath:
				all_rails.append(r)

	match view_mode:
		ViewMode.SHOW_ALL:
			for s in all_stations:
				s.visible = true
			for r in all_rails:
				r.visible = true

		ViewMode.RAILS_ONLY:
			for s in all_stations:
				s.visible = false
			for r in all_rails:
				r.visible = true

		ViewMode.STATIONS_ONLY:
			for s in all_stations:
				s.visible = true
			for r in all_rails:
				r.visible = false

		ViewMode.FOCUS_STATION:
			var focused := _get_selected_station()
			if focused == null:
				# No valid focus — show everything as fallback
				for s in all_stations:
					s.visible = true
				for r in all_rails:
					r.visible = true
				return

			# Collect connected station names (both outgoing and incoming)
			var connected_stations: Dictionary = {}
			connected_stations[focused.name] = true

			# Outgoing: stations in focused.next_stations
			for np in focused.next_stations:
				var next := focused.get_node_or_null(np)
				if next:
					connected_stations[next.name] = true

			# Incoming: any station that lists focused in its next_stations
			for s in all_stations:
				if s == focused:
					continue
				for np in s.next_stations:
					var target := s.get_node_or_null(np)
					if target == focused:
						connected_stations[s.name] = true

			# Apply station visibility
			for s in all_stations:
				s.visible = connected_stations.has(s.name)

			# Apply rail visibility — show only rails touching the focused station
			for r in all_rails:
				var rp: RailPath = r as RailPath
				var from_node = rp.get_node_or_null(rp.from_station)
				var to_node = rp.get_node_or_null(rp.to_station)
				r.visible = (from_node == focused or to_node == focused)
