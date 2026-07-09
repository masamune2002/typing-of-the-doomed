extends Node
class_name SectorLighting

var _flicker_sectors : Array = []

func setup() -> void:
	_flicker_sectors.clear()

	var loader = Game.wadLoader._loader
	var mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if not loader.maps.has(mn):
		return
	var md = loader.maps[mn]
	if not md.has(WadGame.KEY_SECTORS_PARSED):
		return

	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var geom_node = map_node.get_node_or_null(WadGame.NODE_GEOMETRY)
	if geom_node == null:
		return

	var light_sector_types = [1, 2, 3, 7, 8, 12, 13, 17]

	for sec in md[WadGame.KEY_SECTORS_PARSED]:
		if not light_sector_types.has(sec["type"]):
			continue
		var sec_idx : int = sec["index"]
		var sector_node = geom_node.get_node_or_null(WadGame.SECTOR_PREFIX_LOWER + str(sec_idx))
		if sector_node == null:
			continue

		var meshes : Array[MeshInstance3D] = []
		for child in sector_node.get_children():
			if child is MeshInstance3D:
				meshes.append(child)
		if meshes.is_empty():
			continue

		var light_level : float = sec.get("lightLevel", 160.0)
		var dark_level : float = sec.get("darkestNeighValue", 0.0)
		if dark_level >= light_level:
			dark_level = light_level * 0.3
		var bright_val = light_level / 255.0
		var dark_val = dark_level / 255.0

		_flicker_sectors.append({
			"meshes": meshes,
			"bright": bright_val,
			"dark": dark_val,
			"mode": sec["type"],
			"timer": 0.0,
			"on": true,
			"phase": randf() * TAU,
			"current": bright_val,
		})

func clear() -> void:
	_flicker_sectors.clear()

func _apply_sector_brightness(meshes: Array[MeshInstance3D], brightness: float) -> void:
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		for si in mesh.get_surface_override_material_count():
			var mat = mesh.get_surface_override_material(si)
			if mat == null:
				mat = mesh.mesh.surface_get_material(si)
			if mat is StandardMaterial3D or mat is ORMMaterial3D:
				var unique_mat = mat.duplicate() as StandardMaterial3D
				unique_mat.albedo_color = Color(brightness, brightness, brightness, unique_mat.albedo_color.a)
				mesh.set_surface_override_material(si, unique_mat)

func _process(delta: float) -> void:
	for entry in _flicker_sectors:
		var new_val : float = entry["current"]
		entry["timer"] += delta
		match entry["mode"]:
			1, 17:
				if entry["timer"] >= randf_range(0.05, 0.15):
					entry["timer"] = 0.0
					new_val = entry["bright"] if randf() > 0.4 else entry["dark"]
			2, 12:
				if entry["timer"] >= 0.5:
					entry["timer"] = 0.0
					entry["on"] = !entry["on"]
					new_val = entry["bright"] if entry["on"] else entry["dark"]
			3, 13:
				if entry["timer"] >= 1.0:
					entry["timer"] = 0.0
					entry["on"] = !entry["on"]
					new_val = entry["bright"] if entry["on"] else entry["dark"]
			7:
				if entry["timer"] >= randf_range(0.03, 0.1):
					entry["timer"] = 0.0
					new_val = entry["bright"] if randf() > 0.3 else entry["dark"]
			8:
				entry["phase"] += delta * 2.5
				var t = (sin(entry["phase"]) + 1.0) / 2.0
				new_val = entry["dark"] + (entry["bright"] - entry["dark"]) * t
		if new_val != entry["current"]:
			entry["current"] = new_val
			_apply_sector_brightness(entry["meshes"], new_val)
