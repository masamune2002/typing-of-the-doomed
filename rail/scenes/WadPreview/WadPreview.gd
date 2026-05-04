@tool
extends Node3D
class_name WadPreview

@export_file("*.wad") var wad_path: String = ""
@export var map_name: String = "E1M1"
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

func _clear() -> void:
	if _loader != null:
		_loader.queue_free()
		_loader = null
	# Also clean up any leftover children from previous loads
	for child in get_children():
		if child is WadRuntimeLoader:
			child.queue_free()
