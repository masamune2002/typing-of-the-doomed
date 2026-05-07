@tool
extends Node3D
class_name WadPreview

@export_file("*.wad") var wad_path: String = ""
@export var map_name: String = "E1M1"
@export var show_doors: bool = true
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

var _loader: WadRuntimeLoader
var _door_labels: Array[Label3D] = []

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
	print("WadPreview: loaded %s, offset by %s" % [map_name, spawn_pos])

	if show_doors:
		_create_door_labels()

func _create_door_labels() -> void:
	var door_script = load("res://addons/godotWad/src/interactables/door.gd")
	var lift_script = load("res://addons/godotWad/src/interactables/lift.gd")
	var floor_script = load("res://addons/godotWad/src/interactables/floor.gd")
	var exit_script = load("res://addons/godotWad/src/interactables/levelChange.gd")

	# Find all interactable nodes under Interactables
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
		# Determine the type of interactable in this sector
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

		# Extract sector number from name ("Sector 42" -> "42")
		var sector_name: String = sector_node.name
		var sector_num = sector_name.replace("Sector ", "")

		# Position at sector geometry AABB center
		var label_pos = Vector3.ZERO
		if geom != null:
			var geom_sector = geom.get_node_or_null("sector " + sector_num)
			if geom_sector != null and geom_sector is Node3D:
				label_pos = _get_combined_aabb(geom_sector).get_center()

		var label = Label3D.new()
		label.text = prefix + sector_num
		label.font_size = 64
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = color
		label.position = label_pos + Vector3(0, 1.5, 0)
		_loader.add_child(label)
		_door_labels.append(label)

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

func _clear() -> void:
	_door_labels.clear()
	if _loader != null:
		_loader.queue_free()
		_loader = null
	# Also clean up any leftover children from previous loads
	for child in get_children():
		if child is WadRuntimeLoader:
			child.queue_free()
