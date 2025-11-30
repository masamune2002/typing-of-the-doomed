extends Node3D
class_name WadRuntimeLoader

const loader_scene_path: String = "res://addons/godotWad/WAD_Loader.tscn"

## Logical “game name” used by the loader.
@export var game_name: String = "Doom"

## Internal name used by ENTG / caches.
@export var import_name: String = "doom_runtime"

## Map name inside the WAD (e.g. "MAP01"). Leave empty to auto-pick first map.
@export var map_name: String = "E1M1"

## Optional extra params for the loader (if needed).
@export var extra_params: PackedStringArray = []

var _loader: WAD_Map

func load_wad(wad_path: String, map_idx : int) -> Node3D:
	if loader_scene_path == "":
		push_error("WadRuntimeLoader: loader_scene_path is empty.")
		return

	if wad_path == "":
		push_error("WadRuntimeLoader: wad_path is empty.")
		return

	# 1) Instantiate the loader (like makeUI does in _on_gameList_item_selected)
	_loader = load(loader_scene_path).instantiate()
	add_child(_loader) # many loaders assume they’re in the tree

	# 2) Build the params array (mirrors loaderInit())
	var params: Array = []
	params.append(wad_path)
	for p in extra_params:
		params.append(p)

	_loader.initialize(params, game_name, import_name.to_lower())

	# 3) Decide which map to load
	if map_name == "":
		if _loader.has_method("getAllMaps"):
			var maps : Array = _loader.getAllMaps()
			if maps.size() == 0:
				push_error("WadRuntimeLoader: no maps found in WAD.")
				return
			map_name = maps[map_idx]
		else:
			push_error("WadRuntimeLoader: loader has no getAllMaps(), please set map_name manually.")
			return

	# 4) Build the map node (like itemSelected() but without preview/caches)
	var meta: Dictionary = {}
	var map_node: Node3D = null

	if _loader.has_method("createMap"):
		# Use the 4-arg form that makeUI uses for preview:
		# cur.createMap(txt, curMeta, false, get_tree().get_root())
		map_node = _loader.createMap(map_name, meta, false, get_tree().get_root())
	else:
		push_error("WadRuntimeLoader: loader has no createMap().")
		return

	if map_node == null:
		push_error("WadRuntimeLoader: createMap returned null.")
		return

	# 5) Re-parent the map under this node
	if map_node.get_parent() != null:
		map_node.get_parent().remove_child(map_node)
	add_child(map_node)

	# Optional: position/rotate the map
	map_node.position = Vector3.ZERO
	return map_node
