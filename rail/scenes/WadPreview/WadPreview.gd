@tool
extends Node3D
class_name WadPreview

@export_file("*.wad") var wad_path: String = ""
@export var map_name: String = "E1M1"

@export_group("Labels")
@export var show_doors: bool = true:
	set(v):
		show_doors = v
		_apply_label_visibility()
@export var show_lifts: bool = true:
	set(v):
		show_lifts = v
		_apply_label_visibility()
@export var show_floors: bool = true:
	set(v):
		show_floors = v
		_apply_label_visibility()
@export var show_exits: bool = true:
	set(v):
		show_exits = v
		_apply_label_visibility()
@export var show_triggers: bool = true:
	set(v):
		show_triggers = v
		_apply_label_visibility()
@export var show_switches: bool = true:
	set(v):
		show_switches = v
		_apply_label_visibility()

@export_group("Enemies")
@export var show_enemies_difficulty_1: bool = false:
	set(v):
		show_enemies_difficulty_1 = v
		_apply_label_visibility()
@export var show_enemies_difficulty_2: bool = false:
	set(v):
		show_enemies_difficulty_2 = v
		_apply_label_visibility()
@export var show_enemies_difficulty_3: bool = false:
	set(v):
		show_enemies_difficulty_3 = v
		_apply_label_visibility()
@export var show_enemies_difficulty_4: bool = false:
	set(v):
		show_enemies_difficulty_4 = v
		_apply_label_visibility()
@export var show_enemies_difficulty_5: bool = false:
	set(v):
		show_enemies_difficulty_5 = v
		_apply_label_visibility()

@export_group("Actions")
@export var load_geometry: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_load()
		load_geometry = false
@export var clear_geometry: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_clear()
		clear_geometry = false
@export var generate_enemy_markers: bool = false:
	set(v):
		if v and Engine.is_editor_hint():
			_generate_enemy_markers()
		generate_enemy_markers = false

var _loader: WadRuntimeLoader
var _labels_by_type: Dictionary = {}  # "D" -> Array[Label3D], "L" -> ..., etc.
var _enemy_things: Array = []  # Stores parsed enemy things with difficulty info
var _spawn_offset: Vector3 = Vector3.ZERO  # Offset applied to center map

func _ready() -> void:
	if !Engine.is_editor_hint():
		return
	# Load the preview automatically when a WAD is available; the
	# Load Geometry button stays for manual reloads.
	_auto_load.call_deferred()

func _auto_load() -> void:
	if _loader != null:
		return
	if wad_path == "" or !FileAccess.file_exists(wad_path):
		var found := _find_project_wad()
		if found == "":
			return
		wad_path = found
	_load()

func _find_project_wad() -> String:
	var dir := DirAccess.open("res://")
	if dir == null:
		return ""
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if !dir.current_is_dir() and f.to_lower().ends_with(".wad"):
			return "res://" + f
		f = dir.get_next()
	return ""

const DIFFICULTY_COLORS := [
	Color(0.6, 1.0, 0.6),    # Difficulty 1 - light green
	Color(0.6, 0.8, 1.0),    # Difficulty 2 - light blue
	Color(1.0, 1.0, 0.6),    # Difficulty 3 - light yellow
	Color(1.0, 0.7, 0.5),    # Difficulty 4 - light orange
	Color(1.0, 0.6, 0.6),    # Difficulty 5 - light red
]

func _load() -> void:
	_clear()

	if wad_path == "":
		push_warning("WadPreview: wad_path is empty")
		return
	if map_name == "":
		push_warning("WadPreview: map_name is empty")
		return


	_loader = WadRuntimeLoader.new()
	_loader.geometry_only = true
	_loader.map_name = map_name
	add_child(_loader)

	# Build per-sector meshes in the preview. The loader's default
	# meshSimplify/merge pass folds same-height floors into anonymous
	# MeshInstances directly under Geometry, so individual sectors (e.g.
	# E1M8's spawn closet, sector 9) end up with collision-only nodes and
	# no inspectable floor. Both knobs are exported by the loader — this
	# mirrors what its own (unused) createMapPreview() does internally.
	_loader.init_wad(wad_path)
	if _loader._loader != null:
		_loader._loader.meshSimplify = false
		_loader._loader.mergeMesh = _loader._loader.MERGE.DISABLED

	_loader.mapCreated.connect(_on_map_created)
	_loader.load_wad(wad_path, 0)

func _on_map_created() -> void:
	if _loader == null or _loader._loader == null:
		return

	# Center geometry on player spawn (same logic as main.gd._centerMapOnPlayerSpawn)
	var inner = _loader._loader
	var mn = inner.mapName
	if not inner.maps.has(mn):
		mn = mn.to_upper()
	if not inner.maps.has(mn):
		return

	var map_data = inner.maps[mn]
	if not map_data.has(WadGame.KEY_THINGS_PARSED):
		return

	var spawn_pos = Vector3.ZERO
	for thing in map_data[WadGame.KEY_THINGS_PARSED]:
		if thing["type"] == 1: # Player start
			spawn_pos = thing["pos"]
			var floor_info = inner.thingParser.getFloorHeightAtPoint(spawn_pos)
			if spawn_pos.y == -INF and floor_info.has("height"):
				spawn_pos.y = floor_info["height"]
			break

	_loader.global_position = -spawn_pos
	_spawn_offset = spawn_pos
	_create_interactable_labels()
	_create_trigger_labels()
	_create_switch_labels()
	_create_enemy_labels(map_data)
	_apply_label_visibility()

func _create_interactable_labels() -> void:
	var door_script = load("res://addons/godotWad/src/interactables/door.gd")
	var lift_script = load("res://addons/godotWad/src/interactables/lift.gd")
	var floor_script = load("res://addons/godotWad/src/interactables/floor.gd")
	var exit_script = load("res://addons/godotWad/src/interactables/levelChange.gd")

	var map_node: Node3D = null
	for child in _loader.get_children():
		if child is Node3D and child.has_node("Interactables"):
			map_node = child
			break
	if map_node == null:
		return

	var interactables = map_node.get_node("Interactables")
	var geom = map_node.get_node_or_null("Geometry")

	for sector_node in interactables.get_children():
		if not sector_node is Node3D:
			continue
		var prefix := ""
		var color := Color.WHITE
		for child in sector_node.get_children():
			var s = child.get_script()
			if s == door_script:
				prefix = "D"
				color = Color.YELLOW
				break
			elif s == lift_script:
				prefix = "L"
				color = Color.CYAN
				break
			elif s == floor_script:
				prefix = "F"
				color = Color.GREEN
				break
			elif s == exit_script:
				prefix = "E"
				color = Color.MAGENTA
				break
		if prefix == "":
			continue

		var sector_name: String = sector_node.name
		var sector_num = sector_name.replace("Sector ", "")

		var label_pos = Vector3.ZERO
		if geom != null:
			var geom_sector = geom.get_node_or_null("sector " + sector_num)
			if geom_sector != null and geom_sector is Node3D:
				label_pos = _get_combined_aabb(geom_sector).get_center()

		var label = _make_label(prefix + sector_num, color)
		label.position = label_pos + Vector3(0, 1.5, 0)
		_loader.add_child(label)
		_add_label(prefix, label)

func _create_trigger_labels() -> void:
	var walk_trigger_script = load("res://addons/godotWad/src/interactables/walkTrigger.gd")

	var map_node: Node3D = null
	for child in _loader.get_children():
		if child is Node3D and child.has_node("Geometry"):
			map_node = child
			break
	if map_node == null:
		return

	var geom = map_node.get_node("Geometry")

	for sector_node in geom.get_children():
		if not sector_node is Node3D:
			continue
		for child in sector_node.get_children():
			if child.get_script() != walk_trigger_script:
				continue
			var sector_num = sector_node.name.replace("sector ", "")
			var col_shape = child.get_child(0) as CollisionShape3D
			var box_half_y := 0.0
			if col_shape != null and col_shape.shape is BoxShape3D:
				box_half_y = col_shape.shape.extents.y
			var floor_pos = child.global_position - Vector3(0, box_half_y, 0) - _loader.global_position
			var label = _make_label("T" + sector_num, Color.ORANGE_RED)
			label.position = floor_pos + Vector3(0, 0.5, 0)
			_loader.add_child(label)
			_add_label("T", label)

func _create_switch_labels() -> void:
	var range_trigger_script = load("res://addons/godotWad/src/interactables/rangeTrigger.gd")

	var map_node: Node3D = null
	for child in _loader.get_children():
		if child is Node3D and child.has_node("Geometry"):
			map_node = child
			break
	if map_node == null:
		return

	var geom = map_node.get_node("Geometry")

	for sector_node in geom.get_children():
		if not sector_node is Node3D:
			continue
		for child in sector_node.get_children():
			if child.get_script() != range_trigger_script:
				continue
			if not child.has_meta("triggerType"):
				continue
			var ttype = child.get_meta("triggerType")
			if ttype != WADG.TTYPE.SWITCH1 and ttype != WADG.TTYPE.SWITCHR:
				continue
			var sector_num = sector_node.name.replace("sector ", "")
			var col_shape = child.get_child(0) as CollisionShape3D
			var box_half_y := 0.0
			if col_shape != null and col_shape.shape is BoxShape3D:
				box_half_y = col_shape.shape.extents.y
			var floor_pos = child.global_position - Vector3(0, box_half_y, 0) - _loader.global_position
			var label = _make_label("S" + sector_num, Color.DEEP_SKY_BLUE)
			label.position = floor_pos + Vector3(0, 0.5, 0)
			_loader.add_child(label)
			_add_label("S", label)

func _create_enemy_labels(map_data: Dictionary) -> void:
	_enemy_things.clear()
	var things_sheet: gsheet = load("res://addons/godotWad/resources/things.tres")
	if things_sheet == null:
		push_warning("WadPreview: Could not load things.tres")
		return

	# Build set of enemy type IDs (category == "npcs")
	var enemy_types: Dictionary = {}  # type_id -> name
	for id_str in things_sheet.getRowKeys():
		var row = things_sheet.getRow(id_str)
		if row.has("category") and row["category"] == "npcs" and row.has("name"):
			enemy_types[int(id_str)] = row["name"]

	var things: Array = map_data[WadGame.KEY_THINGS_PARSED]
	var inner = _loader._loader

	var enemy_count := 0
	for thing_idx in things.size():
		var thing = things[thing_idx]
		var type_id: int = thing["type"]
		if not enemy_types.has(type_id):
			continue

		var flags: int = thing.get("flags", 0)
		var is_easy: bool = (flags & 0b1) != 0
		var is_medium: bool = (flags & 0b10) != 0
		var is_hard: bool = (flags & 0b100) != 0
		var is_multiplayer: bool = (flags & 0b10000) != 0
		if is_multiplayer:
			continue

		var pos: Vector3 = thing["pos"]
		if pos.y == -INF:
			var floor_info = inner.thingParser.getFloorHeightAtPoint(pos)
			if floor_info.has("height"):
				pos.y = floor_info["height"]
			else:
				pos.y = 0.0

		var enemy_name: String = enemy_types[type_id]

		# Determine which difficulties this enemy appears in
		# DOOM: skill 1&2 = easy flag, skill 3 = medium flag, skill 4&5 = hard flag
		var difficulties: Array[int] = []
		if is_easy:
			difficulties.append(1)
			difficulties.append(2)
		if is_medium:
			difficulties.append(3)
		if is_hard:
			difficulties.append(4)
			difficulties.append(5)

		# Store for marker generation later
		_enemy_things.append({
			"name": enemy_name,
			"pos": pos,
			"difficulties": difficulties,
		})

		# Create a label for each difficulty this enemy belongs to
		# Labels are children of _loader, which is already offset by -spawn_pos,
		# so use raw pos (not pos - _spawn_offset) to avoid double-offset.
		var label_text := "%s_%d" % [enemy_name.replace(" ", "_").to_lower(), thing_idx]
		for diff in difficulties:
			var color: Color = DIFFICULTY_COLORS[diff - 1]
			var label = _make_label(label_text, color)
			label.position = pos + Vector3(0, 1.0, 0)
			_loader.add_child(label)
			var type_key = "E%d" % diff
			_add_label(type_key, label)

		enemy_count += 1


func _make_label(text: String, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	return label

func _add_label(type_key: String, label: Label3D) -> void:
	if not _labels_by_type.has(type_key):
		_labels_by_type[type_key] = []
	_labels_by_type[type_key].append(label)

func _apply_label_visibility() -> void:
	var visibility := {
		"D": show_doors,
		"L": show_lifts,
		"F": show_floors,
		"E": show_exits,
		"T": show_triggers,
		"S": show_switches,
		"E1": show_enemies_difficulty_1,
		"E2": show_enemies_difficulty_2,
		"E3": show_enemies_difficulty_3,
		"E4": show_enemies_difficulty_4,
		"E5": show_enemies_difficulty_5,
	}
	for type_key in _labels_by_type:
		var vis: bool = visibility.get(type_key, true)
		for label in _labels_by_type[type_key]:
			if is_instance_valid(label):
				label.visible = vis

func _get_combined_aabb(node: Node3D) -> AABB:
	var aabb = AABB()
	var first = true
	for child in node.get_children():
		if child is MeshInstance3D:
			var child_aabb = child.get_aabb()
			child_aabb.position += child.position
			if first:
				aabb = child_aabb
				first = false
			else:
				aabb = aabb.merge(child_aabb)
	if first:
		aabb.position = node.global_position
	return aabb

func _generate_enemy_markers() -> void:
	if _enemy_things.is_empty():
		push_warning("WadPreview: No enemy data. Load geometry first with enemy checkboxes enabled.")
		return

	var shown_difficulties: Array[int] = []
	if show_enemies_difficulty_1: shown_difficulties.append(1)
	if show_enemies_difficulty_2: shown_difficulties.append(2)
	if show_enemies_difficulty_3: shown_difficulties.append(3)
	if show_enemies_difficulty_4: shown_difficulties.append(4)
	if show_enemies_difficulty_5: shown_difficulties.append(5)

	if shown_difficulties.is_empty():
		push_warning("WadPreview: No difficulty checkboxes are enabled.")
		return

	var marker_scene: PackedScene = load("res://rail/scenes/RailMarker/RailMarker.tscn")
	if marker_scene == null:
		push_warning("WadPreview: Could not load RailMarker scene.")
		return

	var markers_node := Node3D.new()
	markers_node.name = "EnemyMarkers"
	add_child(markers_node)
	markers_node.owner = get_tree().edited_scene_root

	var count := 0
	for enemy in _enemy_things:
		var dominated_by_shown := false
		for diff in enemy["difficulties"]:
			if shown_difficulties.has(diff):
				dominated_by_shown = true
				break
		if not dominated_by_shown:
			continue

		# Use the color of the lowest shown difficulty this enemy belongs to
		var lowest_diff := 5
		for diff in enemy["difficulties"]:
			if shown_difficulties.has(diff) and diff < lowest_diff:
				lowest_diff = diff

		var marker: Node3D = marker_scene.instantiate()
		marker.name = "Marker_%s_%d" % [enemy["name"].replace(" ", ""), count]
		marker.position = enemy["pos"] - _spawn_offset
		marker.disc_color = DIFFICULTY_COLORS[lowest_diff - 1]
		markers_node.add_child(marker)
		marker.owner = get_tree().edited_scene_root
		count += 1


func _clear() -> void:
	_labels_by_type.clear()
	if _loader != null:
		_loader.queue_free()
		_loader = null
	for child in get_children():
		if child is WadRuntimeLoader:
			child.queue_free()
