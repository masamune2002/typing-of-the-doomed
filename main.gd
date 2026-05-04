extends Node3D

@export var wad_game : WadGame = preload("res://wads/doom/DoomGame.tres")

const LEVELS_DIR = "res://levels/"

var _current_rail_network: Node3D = null
var _flicker_sectors : Array = []
var _currentMapIdx : int = 0
var _entity_sector_riders : Array = []
var _title_screen : TitleScreen = null
var _pause_menu : GameMenu = null
var _wad_file_path : String = ""
var _pending_save_data : Dictionary = {}
var _map_origin_offset : Vector3 = Vector3.ZERO  # Offset to center map on player spawn

# Level stats tracking
var _level_total_enemies : int = 0
var _level_killed_enemies : int = 0
var _level_total_items : int = 0
var _level_collected_items : int = 0
var _level_total_secrets : int = 0
var _level_found_secrets : int = 0
var _level_start_time : float = 0.0
var _intermission_screen : Control = null

# Generic scene preloads (Rail framework, not game-specific)
const TITLE_SCREEN_SCENE = preload("res://rail/scenes/UI/TitleScreen/TitleScreen.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/UI/GameMenu/GameMenu.tscn")
const LEVEL_EXIT_SCRIPT = preload("res://scenes/LevelExit/LevelExit.gd")
const ITEM_SCENE = preload("res://scenes/Items/Item.tscn")
const INTERACTABLE_SCENE = preload("res://scenes/Interactables/Interactable.tscn")
const BARREL_SCENE = preload("res://scenes/Barrels/ExplodingBarrel.tscn")

# Entity sector rider dict keys
const RIDER_NODE = "node"
const RIDER_SECTOR_NODE = "sector_node"
const RIDER_LAST_H = "last_h"

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.mapCreated.connect(_onMapCreated)
	loader.geometry_only = true
	Game.setWadLoader(loader)
	Game.setWadGame(wad_game)
	EventBus.levelExitReached.connect(_onLevelExitReached)

	# Try last used WAD path first
	var last_path = SettingsManager.last_wad_path
	if last_path != "" and FileAccess.file_exists(last_path):
		_initWithWad(last_path)
		return

	var wad_files = _findWadFiles()
	if wad_files.size() == 1:
		_initWithWad(wad_files[0])
	elif wad_files.size() == 0:
		_showWadPicker([])
	else:
		_showWadPicker(wad_files)

func _findWadFiles() -> Array[String]:
	var found : Array[String] = []
	# Check next to the executable
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	var parent_dir = app_dir.path_join("..")
	var dir = DirAccess.open(parent_dir)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.to_lower().ends_with(".wad") and not dir.current_is_dir():
				found.append(parent_dir.path_join(file_name))
			file_name = dir.get_next()
	# Check res:// as fallback
	var res_dir = DirAccess.open("res://")
	if res_dir != null:
		res_dir.list_dir_begin()
		var file_name = res_dir.get_next()
		while file_name != "":
			if file_name.to_lower().ends_with(".wad") and not res_dir.current_is_dir():
				var res_path = "res://" + file_name
				if res_path not in found:
					found.append(res_path)
			file_name = res_dir.get_next()
	return found

var _wad_picker : WadPicker = null

func _showWadPicker(wad_files: Array[String]) -> void:
	_wad_picker = WadPicker.new()
	add_child(_wad_picker)
	if wad_files.is_empty():
		_wad_picker.showNoWadsMessage()
	else:
		for wad_path in wad_files:
			var display_name = wad_path.get_file()
			_wad_picker.addWadOption(wad_path, display_name)
	_wad_picker.addBrowseButton()
	_wad_picker.wad_selected.connect(_onWadSelected)

func _onWadSelected(wad_path: String) -> void:
	if _wad_picker != null:
		_wad_picker.queue_free()
		_wad_picker = null
	_initWithWad(wad_path)

func _initWithWad(wad_path: String) -> void:
	_wad_file_path = wad_path
	SettingsManager.last_wad_path = wad_path
	SettingsManager.save_settings()
	Game.wadLoader.init_wad(_wad_file_path)
	_showTitleScreen()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause_menu == null and _title_screen == null:
		var player = Game.getPlayer()
		if player != null and player._alive:
			player._clearFireTarget()
			showPauseMenu()
			get_viewport().set_input_as_handled()

func _showTitleScreen() -> void:
	_title_screen = TITLE_SCREEN_SCENE.instantiate()
	_title_screen.game_started.connect(_startGame)
	_title_screen.save_loaded.connect(_onSaveLoaded)
	add_child(_title_screen)

func _startGame(map_idx: int) -> void:
	_currentMapIdx = map_idx
	if _title_screen != null:
		_title_screen.queue_free()
		_title_screen = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.wadLoader.map_name = wad_game.map_names[_currentMapIdx]
	Game.wadLoader.load_wad(_wad_file_path, 0)

func _onMapCreated() -> void:
	_clearWadEntities()
	_centerMapOnPlayerSpawn()
	_spawnPlayer()
	_spawnEnemiesFromWad()
	_spawnDecorationsFromWad()
	_spawnSectorLights()
	_spawnInteractablesFromWad()
	_overrideExitNodes()
	_addBlockingLineCollisions()
	_buildNavigationMesh()
	_loadRailNetwork(Game.wadLoader.map_name)
	# Activate all entities
	EventBus.startEncounter.emit()
	for child in $EntityContainer.get_children():
		if child is Enemy:
			child.activate()
	_pending_save_data = {}
	_resetLevelStats()

func _clearWadEntities() -> void:
	# Remove any entities the WAD addon created despite geometry_only mode.
	# We spawn our own enemies/items/decorations from WAD thing data instead.
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	for level_node in level_nodes:
		var entities_node = level_node.get_node_or_null(WadGame.NODE_ENTITIES)
		if entities_node == null:
			continue
		for child in entities_node.get_children():
			child.queue_free()
	# Also remove any WAD-spawned enemies/pickups that ended up in other groups
	for node in get_tree().get_nodes_in_group("enemy"):
		if not node.is_queued_for_deletion():
			node.queue_free()
	for node in get_tree().get_nodes_in_group("pickup"):
		if not node.is_queued_for_deletion():
			node.queue_free()
	for node in get_tree().get_nodes_in_group("collectable"):
		if not node.is_queued_for_deletion():
			node.queue_free()

func _onNpcDied(_enemy: Node, npc_name: String, level_node: Node) -> void:
	if level_node != null and is_instance_valid(level_node) and level_node.has_method("registerDeath"):
		level_node.registerDeath(npc_name)

var _blocking_walls : Array[StaticBody3D] = []
var _nav_region : NavigationRegion3D = null

func _addBlockingLineCollisions() -> void:
	# Add collision to two-sided linedefs with the ML_BLOCKING flag.
	# The WAD addon skips collision for all two-sided lines, but some
	# (like window bars, railings) should still block the player.
	for wall in _blocking_walls:
		wall.queue_free()
	_blocking_walls.clear()

	var loader = Game.wadLoader._loader
	var mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if not loader.maps.has(mn):
		return
	var md = loader.maps[mn]
	if not md.has("lineDefsParsed") or not md.has("vertexesParsed") or not md.has(WadGame.KEY_SECTORS_PARSED):
		return

	var linedefs = md["lineDefsParsed"]
	var verts = md["vertexesParsed"]
	var sectors = md[WadGame.KEY_SECTORS_PARSED]

	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var map_scale = map_node.scale

	for line in linedefs:
		var flags = line.get("flags", 0)
		var is_blocking = (flags & 1) != 0  # ML_BLOCKING
		var is_two_sided = (flags & 4) != 0  # ML_TWOSIDED
		if not is_blocking or not is_two_sided:
			continue

		var sv = verts[line["startVert"]]
		var ev = verts[line["endVert"]]
		var start = Vector2(sv.x * map_scale.x, sv.y * map_scale.z)
		var end = Vector2(ev.x * map_scale.x, ev.y * map_scale.z)

		# Get floor and ceiling heights from the front sector
		var front_sec_idx = line.get("frontSector", -1)
		if front_sec_idx < 0 or front_sec_idx >= sectors.size():
			continue
		var front_sec = sectors[front_sec_idx]
		var floor_h = front_sec.get(WadGame.KEY_FLOOR_HEIGHT, 0.0)
		var ceil_h = front_sec.get("ceilingHeight", floor_h + 4.0)

		# Create a thin wall collision shape
		var mid = (start + end) / 2.0
		var length = start.distance_to(end)
		if length < 0.01:
			continue
		var angle = atan2(end.y - start.y, end.x - start.x)
		var height = ceil_h - floor_h
		if height <= 0:
			continue

		var body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = _wadToWorld(Vector3(mid.x, floor_h + height / 2.0, mid.y))
		body.rotation.y = -angle

		var shape = BoxShape3D.new()
		shape.size = Vector3(length, height, 0.1)
		var col = CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)

		add_child(body)
		_blocking_walls.append(body)

func _buildNavigationMesh() -> void:
	# Remove old navigation region
	if _nav_region != null:
		_nav_region.queue_free()
		_nav_region = null

	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var geom_node = map_node.get_node_or_null(WadGame.NODE_GEOMETRY)
	if geom_node == null:
		return

	_nav_region = NavigationRegion3D.new()
	add_child(_nav_region)

	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_height = 1.2
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 50.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.2
	# Parse source geometry from floor meshes
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = WadGame.GROUP_LEVEL

	_nav_region.navigation_mesh = nav_mesh
	_nav_region.bake_navigation_mesh()

func _loadRailNetwork(map_name: String) -> void:
	if _current_rail_network != null:
		_current_rail_network.queue_free()
		_current_rail_network = null

	var scene_path = LEVELS_DIR + map_name + ".tscn"
	if not ResourceLoader.exists(scene_path):
		push_warning("No RailNetwork scene found for map: %s (looked at %s)" % [map_name, scene_path])
		return

	var scene = load(scene_path)
	if scene == null:
		push_error("Failed to load RailNetwork scene: %s" % scene_path)
		return

	_current_rail_network = scene.instantiate()
	add_child(_current_rail_network)

	# Position at player spawn ground height
	var player = Game.getPlayer()
	if player != null:
		_current_rail_network.global_position.y = player.global_position.y - 1.5 + 0.05

func _overrideExitNodes() -> void:
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var interactables_node = map_node.get_node_or_null(WadGame.NODE_INTERACTABLES)
	if interactables_node == null:
		return

	var exit_script = LEVEL_EXIT_SCRIPT

	for sector_node in interactables_node.get_children():
		for child in sector_node.get_children():
			if child.get_script() != null and child.get_script().resource_path.ends_with(WadGame.SCRIPT_LEVEL_CHANGE):
				# Preserve state the node already has
				var old_trigger = child.get(WadGame.PROP_TRIGGER_TYPE)
				var old_secret = child.get(WadGame.PROP_SECRET)
				var old_bodies = child.get(WadGame.PROP_OVERLAPPING_BODIES).duplicate()
				var old_walk = child.get(WadGame.PROP_WALK_OVER_BODIES).duplicate()
				child.set_script(exit_script)
				child.set(WadGame.PROP_TRIGGER_TYPE, old_trigger)
				child.set(WadGame.PROP_SECRET, old_secret)
				child.set(WadGame.PROP_OVERLAPPING_BODIES, old_bodies)
				child.set(WadGame.PROP_WALK_OVER_BODIES, old_walk)
				pass

var _transitioning : bool = false

func restartCurrentMap() -> void:
	EventBus.stopWait.emit()
	_carry_over_state = {}
	_skip_state_capture = true
	_loadMap(wad_game.map_names[_currentMapIdx])

func showPauseMenu() -> void:
	if _pause_menu != null:
		return
	Game.playSound("DSSWTCHN")
	EventBus.wait.emit()
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	_pause_menu.pause_mode = true
	_pause_menu.resumed.connect(_resumeGame)
	_pause_menu.game_started.connect(_pauseMenuLevelSelected)
	_pause_menu.save_loaded.connect(_onSaveLoaded)
	_pause_menu.save_requested.connect(_onSaveRequested)
	add_child(_pause_menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resumeGame() -> void:
	Game.playSound("DSSWTCHX")
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.stopWait.emit()

func _pauseMenuLevelSelected(map_idx: int) -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_currentMapIdx = map_idx
	EventBus.stopWait.emit()
	_loadMap(wad_game.map_names[_currentMapIdx])

func _onSaveRequested(slot: int, save_name: String) -> void:
	var player = Game.getPlayer()
	if player != null:
		var dead_entities := _getDeadEntityNames()
		SaveManager.save_game(slot, save_name, _currentMapIdx, player, dead_entities)

func _getDeadEntityNames() -> Array:
	var dead : Array = []
	var container = $EntityContainer
	for child in container.get_children():
		if child is Enemy and (!child.alive or child.dying):
			dead.append(str(child.name))
		elif child is Item and !child.alive:
			dead.append(str(child.name))
		elif child is ExplodingBarrel and !child.alive:
			dead.append(str(child.name))
	return dead

func _onSaveLoaded(save_data: Dictionary) -> void:
	_pending_save_data = save_data
	_currentMapIdx = save_data.get("map_idx", 0)
	var from_title = _title_screen != null
	# Close menus
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	if _title_screen != null:
		_title_screen.queue_free()
		_title_screen = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.stopWait.emit()
	if from_title:
		# First load — need full WAD load, not just map swap
		Game.wadLoader.map_name = wad_game.map_names[_currentMapIdx]
		Game.wadLoader.load_wad(_wad_file_path, 0)
	else:
		_loadMap(wad_game.map_names[_currentMapIdx])

func isPaused() -> bool:
	return _pause_menu != null

func _onLevelExitReached() -> void:
	if _transitioning:
		return
	_transitioning = true
	var next_idx = _currentMapIdx + 1

	if next_idx >= wad_game.map_names.size():
		_currentMapIdx = next_idx
		Game.getPlayer().win()
		return

	# Show intermission screen
	_showIntermission(wad_game.map_names[_currentMapIdx], wad_game.map_names[next_idx], next_idx)

func _resetLevelStats() -> void:
	_level_killed_enemies = 0
	_level_collected_items = 0
	_level_found_secrets = 0
	_level_start_time = Time.get_ticks_msec() / 1000.0
	# Count totals from spawned entities
	_level_total_enemies = 0
	_level_total_items = 0
	_level_total_secrets = 0
	for child in $EntityContainer.get_children():
		if child is Enemy:
			_level_total_enemies += 1
	# Connect kill signal for this level
	if not EventBus.enemyKilled.is_connected(_onLevelEnemyKilled):
		EventBus.enemyKilled.connect(_onLevelEnemyKilled)

func _onLevelEnemyKilled(_enemy: Enemy) -> void:
	_level_killed_enemies += 1

func _showIntermission(finished_map: String, next_map: String, next_idx: int) -> void:
	var elapsed = Time.get_ticks_msec() / 1000.0 - _level_start_time
	var kills_pct = (float(_level_killed_enemies) / max(_level_total_enemies, 1)) * 100.0
	var items_pct = 0.0  # TODO: track item pickups
	var secrets_pct = 0.0  # TODO: track secrets

	# Pause gameplay
	EventBus.wait.emit()

	# Play intermission music
	_playIntermissionMusic()

	# Create intermission screen
	if _intermission_screen != null:
		_intermission_screen.queue_free()
	_intermission_screen = IntermissionScreen.new()
	add_child(_intermission_screen)
	# Derive episode from map name (E1M* = 0, E2M* = 1, etc.)
	var episode = 0
	if finished_map.length() >= 2 and finished_map.begins_with("E"):
		episode = finished_map.substr(1, 1).to_int() - 1
	_intermission_screen.show_stats(finished_map, next_map, kills_pct, items_pct, secrets_pct, elapsed, episode)
	_intermission_screen.continue_pressed.connect(func():
		_intermission_screen.queue_free()
		_intermission_screen = null
		_stopIntermissionMusic()
		_currentMapIdx = next_idx
		_loadMap(wad_game.map_names[_currentMapIdx])
	)

func _playIntermissionMusic() -> void:
	var resource_manager = Game.wadLoader._loader.get_node_or_null("ResourceManager")
	if resource_manager == null:
		return
	var midi_data = resource_manager.fetchMidiOrMus("D_INTER")
	if midi_data == null:
		return
	var midi_player = ENTG.fetchMidiPlayer(get_tree())
	if midi_player == null:
		return
	ENTG.setMidiPlayerData(midi_player, midi_data)
	if not midi_player.is_inside_tree():
		get_tree().get_root().add_child(midi_player)
	midi_player.play()

func _stopIntermissionMusic() -> void:
	var midi_player = ENTG.fetchMidiPlayer(get_tree())
	if midi_player != null:
		midi_player.stop()

var _carry_over_state : Dictionary = {}
var _skip_state_capture : bool = false

func _loadMap(map_name: String) -> void:
	# Clean up old entities
	_flicker_sectors.clear()
	_entity_sector_riders.clear()
	if _nav_region != null:
		_nav_region.queue_free()
		_nav_region = null
	for wall in _blocking_walls:
		wall.queue_free()
	_blocking_walls.clear()

	# Capture player state before removing (unless restarting after death)
	var old_player = Game.getPlayer()
	if old_player != null and not _skip_state_capture:
		_carry_over_state = old_player.getState()
		# Don't carry over position, rotation, or keys between maps
		_carry_over_state.erase("position")
		_carry_over_state.erase("camera_rot_h")
		_carry_over_state.erase("camera_rot_v")
		_carry_over_state.erase("keys")
		old_player.queue_free()
		Game.player = null

	# Remove everything from the EnemyContainer (enemies, items, barrels)
	var container = $EntityContainer
	for child in container.get_children():
		child.queue_free()


	# Remove interactable wrappers
	for node in get_tree().get_nodes_in_group(WadGame.GROUP_INTERACTABLES):
		node.queue_free()

	# Remove spawned decorations
	var deco_prefixes = ["FloorLamp", "Candelabra", "Candle", "Tall", "Short", "Burnt",
		"Big", "Burning", "Stalagtite", "Bloody", "Dead", "Pool", "Impaled",
		"Twitching", "Skull", "Hanging"]
	for child in get_children():
		for prefix in deco_prefixes:
			if child.name.begins_with(prefix):
				child.queue_free()
				break

	# Free current rail network
	if _current_rail_network != null:
		_current_rail_network.queue_free()
		_current_rail_network = null

	# Remove old level geometry
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	for node in level_nodes:
		node.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Load the new map
	_transitioning = false
	Game.wadLoader.load_map(map_name)
	# mapCreated signal will trigger _onMapCreated which spawns everything

func _spawnEnemiesFromWad() -> void:
	var loader = Game.wadLoader._loader
	var map_name = loader.mapName
	if not loader.maps.has(map_name):
		map_name = map_name.to_upper()
	if not loader.maps.has(map_name):
		return
	var map_data = loader.maps[map_name]
	if not map_data.has(WadGame.KEY_THINGS_PARSED):
		return

	# Build set of dead entity names from pending save data
	var dead_set := {}
	if not _pending_save_data.is_empty():
		for entity_name in _pending_save_data.get("dead_entities", []):
			dead_set[entity_name] = true

	# Find the level node to register births/deaths for NPC triggers (E1M8 barons, etc.)
	var level_node: Node = null
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	if not level_nodes.is_empty():
		level_node = level_nodes[-1]

	var things = map_data[WadGame.KEY_THINGS_PARSED]
	var container = $EntityContainer
	var enemy_nodes: Array[Node] = []
	var name_counts = {}

	for thing in things:
		if not wad_game.enemies.has(thing["type"]):
			continue

		# Filter by Ultraviolence difficulty (bit 2) and exclude multiplayer-only (bit 4)
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var enemy_def = wad_game.enemies[thing["type"]]
		var enemy = enemy_def["scene"].instantiate()
		enemy.numHealthBars = enemy_def.get("health_bars", 1)

		# Generate unique name
		var base_name = enemy_def["name"]
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		var entity_name = base_name + str(name_counts[base_name])
		enemy.name = entity_name

		container.add_child(enemy)
		enemy_nodes.append(enemy)

		# Set enemy to corpse state when loading a save
		if dead_set.has(entity_name):
			enemy.setDead()

		# Register with WAD NPC trigger system (e.g. E1M8 baron death → floor lower)
		var npc_name = enemy_def.get("npc_trigger", "")
		if npc_name != "" and level_node != null and level_node.has_method("registerBirth"):
			level_node.registerBirth(npc_name)
			enemy.died.connect(_onNpcDied.bind(npc_name, level_node))

		# Resolve Y position using the WAD's floor height lookup
		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		enemy.global_position = _wadToWorld(pos)
		_registerEntitySectorRider(enemy, pos)

	# Spawn items from WAD data
	var item_count = 0
	for thing in things:
		if not wad_game.item_definitions.has(thing["type"]):
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var item_def = wad_game.item_definitions[thing["type"]]
		var item = ITEM_SCENE.instantiate()
		item.itemDefinition = item_def

		var base_name = item_def["name"]
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		var entity_name = base_name + str(name_counts[base_name])
		item.name = entity_name

		# Skip collected items when loading a save
		if dead_set.has(entity_name):
			item.queue_free()
			continue

		container.add_child(item)
		item_count += 1

		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		item.global_position = _wadToWorld(pos)
		_registerEntitySectorRider(item, pos)

	# Spawn weapon pickups from WAD data
	for thing in things:
		if not wad_game.weapon_pickup_definitions.has(thing["type"]):
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var wpn_def = wad_game.weapon_pickup_definitions[thing["type"]]
		var item_def = {
			"name": wpn_def["name"],
			"sprites": wpn_def["sprites"],
			"effect": "weapon",
			"weapon_scene": wpn_def["weapon_scene"],
			"sound": wpn_def.get("sound", "DSWPNUP"),
		}
		var item = ITEM_SCENE.instantiate()
		item.itemDefinition = item_def

		var base_name = wpn_def["name"]
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		var entity_name = base_name + str(name_counts[base_name])
		item.name = entity_name

		if dead_set.has(entity_name):
			item.queue_free()
			continue

		container.add_child(item)
		item_count += 1

		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		item.global_position = _wadToWorld(pos)
		_registerEntitySectorRider(item, pos)

	# Spawn barrels from WAD data
	var barrel_count = 0
	for thing in things:
		if thing["type"] != wad_game.barrel_thing_type:
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var barrel = BARREL_SCENE.instantiate()
		var base_name = "ExplodingBarrel"
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		var entity_name = base_name + str(name_counts[base_name])
		barrel.name = entity_name

		# Skip destroyed barrels when loading a save
		if dead_set.has(entity_name):
			barrel.queue_free()
			continue

		container.add_child(barrel)

		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		barrel.global_position = _wadToWorld(pos)
		_registerEntitySectorRider(barrel, pos)
		barrel_count += 1

	pass

func _spawnDecorationsFromWad() -> void:
	var loader = Game.wadLoader._loader
	var map_name = loader.mapName
	if not loader.maps.has(map_name):
		map_name = map_name.to_upper()
	if not loader.maps.has(map_name):
		return
	var map_data = loader.maps[map_name]
	if not map_data.has(WadGame.KEY_THINGS_PARSED):
		return

	var things = map_data[WadGame.KEY_THINGS_PARSED]
	var deco_count = 0

	for thing in things:
		if thing["type"] == wad_game.barrel_thing_type:
			continue  # Barrels are spawned as interactive entities, not decorations
		if not wad_game.decoration_definitions.has(thing["type"]):
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var def = wad_game.decoration_definitions[thing["type"]]
		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]

		var node = Node3D.new()
		node.name = def["name"] + str(deco_count)
		add_child(node)
		node.global_position = _wadToWorld(pos)
		_registerEntitySectorRider(node, pos)

		# Create sprite
		var sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.pixel_size = 0.04
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		node.add_child(sprite)

		# Load texture from WAD
		var tex = Game.fetchSprite(def["sprites"][0])
		if tex != null:
			sprite.texture = tex
			sprite.position.y = (tex.get_height() / 2.0) * sprite.pixel_size - 0.01
		else:
			node.queue_free()
			continue

		# Add light for light-emitting decorations
		if wad_game.decoration_lights.has(thing["type"]):
			var ld = wad_game.decoration_lights[thing["type"]]
			var light = OmniLight3D.new()
			light.light_color = ld["color"]
			light.light_energy = ld["energy"]
			light.omni_range = ld["range"]
			light.shadow_enabled = false
			light.omni_attenuation = 1.5
			light.light_bake_mode = Light3D.BAKE_DISABLED
			light.position.y = sprite.position.y + (tex.get_height() / 2.0) * sprite.pixel_size
			node.add_child(light)

		# Animate if multiple frames
		if def["sprites"].size() > 1:
			var frames : Array[Texture2D] = []
			for spr_name in def["sprites"]:
				var t = Game.fetchSprite(spr_name)
				if t != null:
					frames.append(t)
			if frames.size() > 1:
				sprite.set_script(wad_game.animated_sprite_script)
				sprite.setup(frames)

		deco_count += 1

	pass

func _spawnSectorLights() -> void:
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

		# Collect all MeshInstance3D children and their materials
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

	pass

func _apply_sector_brightness(meshes: Array[MeshInstance3D], brightness: float) -> void:
	var color = Color(brightness, brightness, brightness, 1.0)
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

func _spawnPlayer() -> void:
	var loader = Game.wadLoader._loader
	var map_name = loader.mapName
	if not loader.maps.has(map_name):
		map_name = map_name.to_upper()
	if not loader.maps.has(map_name):
		return
	var map_data = loader.maps[map_name]
	if not map_data.has(WadGame.KEY_THINGS_PARSED):
		return

	var spawn_pos = Vector3.ZERO
	for thing in map_data[WadGame.KEY_THINGS_PARSED]:
		# Thing type 1 is the player
		if thing["type"] == wad_game.thing_type_player_start:
			spawn_pos = thing["pos"]
			var floor_info = loader.thingParser.getFloorHeightAtPoint(spawn_pos)
			if spawn_pos.y == -INF and floor_info.has("height"):
				spawn_pos.y = floor_info["height"]
			break

	var player = wad_game.player_scene.instantiate()
	add_child(player)
	player.global_position = _wadToWorld(spawn_pos) + Vector3(0, 1.5, 0)
	pass

	# Apply saved state if loading a save (don't clear _pending_save_data yet —
	# _spawnEnemiesFromWad needs it for dead entity filtering)
	if not _pending_save_data.is_empty():
		var pd = _pending_save_data.get("player", {})
		if pd.has("position"):
			var pos = pd["position"]
			player.global_position = Vector3(pos["x"], pos["y"], pos["z"])
		player.restoreState(pd)
	# Carry over state from previous level (health, armor, weapons)
	elif not _carry_over_state.is_empty():
		player.restoreState(_carry_over_state)
		_carry_over_state = {}
	_skip_state_capture = false

func _centerMapOnPlayerSpawn() -> void:
	# Compute the player spawn position so we can offset everything to world origin.
	var loader = Game.wadLoader._loader
	var map_name = loader.mapName
	if not loader.maps.has(map_name):
		map_name = map_name.to_upper()
	if not loader.maps.has(map_name):
		_map_origin_offset = Vector3.ZERO
		return
	var map_data = loader.maps[map_name]
	if not map_data.has(WadGame.KEY_THINGS_PARSED):
		_map_origin_offset = Vector3.ZERO
		return

	var spawn_pos = Vector3.ZERO
	for thing in map_data[WadGame.KEY_THINGS_PARSED]:
		if thing["type"] == wad_game.thing_type_player_start:
			spawn_pos = thing["pos"]
			var floor_info = loader.thingParser.getFloorHeightAtPoint(spawn_pos)
			if spawn_pos.y == -INF and floor_info.has("height"):
				spawn_pos.y = floor_info["height"]
			break

	_map_origin_offset = spawn_pos

	# Shift the WadRuntimeLoader node so the level geometry (which gets reparented
	# under it at position zero) ends up centered on world origin.
	# We offset the loader parent rather than the level node itself because the
	# WadRuntimeLoader resets the level node's position to zero after this signal.
	var wad_loader_node = Game.wadLoader as Node3D
	if wad_loader_node != null:
		wad_loader_node.global_position = -_map_origin_offset

## Convert a raw WAD position to world position (accounting for map centering).
func _wadToWorld(pos: Vector3) -> Vector3:
	return pos - _map_origin_offset

func _spawnInteractablesFromWad() -> void:
	# Find the level/map node to access sector polygon data
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	# Filter out old level nodes queued for deletion during map transitions
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	pass
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[-1]

	var has_poly_data = map_node.has_meta("sectorPolyArr")
	pass
	var sector_poly_arr: Array = map_node.get_meta("sectorPolyArr") if has_poly_data else []

	# Get parsed sector data for floor heights (used as fallback for nodes without sectorInfo)
	var sectors_parsed: Array = []
	var loader = Game.wadLoader._loader
	var mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if loader.maps.has(mn) and loader.maps[mn].has(WadGame.KEY_SECTORS_PARSED):
		sectors_parsed = loader.maps[mn][WadGame.KEY_SECTORS_PARSED]

	# Gather interactable candidates from levelObject group AND sector children with activate
	var all_level_objects : Array[Node] = []
	for obj in get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL_OBJECT):
		if not obj.is_queued_for_deletion():
			all_level_objects.append(obj)
	# Also scan Interactables parent for nodes with activate not in the group (e.g. levelChange/exit)
	var interactables_node = map_node.get_node_or_null(WadGame.NODE_INTERACTABLES)
	if interactables_node:
		for sector_node in interactables_node.get_children():
			for child in sector_node.get_children():
				if child.has_method("activate") and not child.is_in_group(WadGame.GROUP_LEVEL_OBJECT):
					all_level_objects.append(child)
	pass

	var interactable_count = 0
	var skipped_no_activate = 0
	var skipped_no_ttype = 0
	var skipped_wrong_ttype = 0
	var skipped_no_pos = 0
	for node in all_level_objects:
		var is_lift = node.get_script() != null and node.get_script().resource_path.ends_with(WadGame.SCRIPT_LIFT)
		var is_stair = node.get_script() != null and node.get_script().resource_path.ends_with(WadGame.SCRIPT_STAIRS)
		if not node.has_method("activate") and not is_lift and not is_stair:
			skipped_no_activate += 1
			continue
		if not node is Node3D:
			continue
		var ttype = node.get(WadGame.PROP_TRIGGER_TYPE)
		if ttype == null:
			skipped_no_ttype += 1
			continue
		var valid_ttypes = [WADG.TTYPE.DOOR, WADG.TTYPE.DOOR1, WADG.TTYPE.SWITCH1, WADG.TTYPE.SWITCHR]
		var nodeKeyType = node.get(WadGame.PROP_KEY_TYPE)
		var isKeyDoor = nodeKeyType != null and nodeKeyType < 4
		if ttype not in valid_ttypes:
			skipped_wrong_ttype += 1
			continue

		# Calculate world position from sector polygon centroid
		var world_pos = _getInteractablePosition(node, sector_poly_arr, sectors_parsed)
		if world_pos == null:
			skipped_no_pos += 1
			continue
		# For switch-type triggers, position at the switch linedef instead of the target sector
		if ttype == WADG.TTYPE.SWITCH1 or ttype == WADG.TTYPE.SWITCHR:
			var switch_pos = _getSwitchPosition(node, world_pos.y)
			if switch_pos != null:
				world_pos = switch_pos

		var interactable = INTERACTABLE_SCENE.instantiate()
		interactable.wadNode = node
		interactable.interactable_name = node.name
		# Check if door requires a key (KEY enum: RED=0, GREEN=1, BLUE=2, YELLOW=3, 9=none)
		var keyType = node.get(WadGame.PROP_KEY_TYPE)
		if keyType != null and wad_game.key_type_to_id.has(keyType):
			interactable.requiredKey = wad_game.key_type_to_id[keyType]
			# Use door mesh XZ position but keep floor height for Y
			var door_pos = _getDoorMeshPosition(node)
			if door_pos != null:
				world_pos.x = door_pos.x
				world_pos.z = door_pos.z
				pass
		add_child(interactable)
		interactable.global_position = _wadToWorld(world_pos)
		interactable_count += 1
		pass

	# Spawn interactables for secret sectors that don't already have a door/switch
	var spawned_sectors : Array[int] = []
	for node in all_level_objects:
		if node.has_method("activate"):
			var parent_name = node.get_parent().name as String
			if parent_name.begins_with(WadGame.SECTOR_PREFIX_UPPER):
				spawned_sectors.append(parent_name.substr(7).to_int())

	mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if loader.maps.has(mn):
		var md = loader.maps[mn]
		# Build set of sectors already targeted by sectorToInteraction
		var targeted_sectors : Array[int] = []
		if md.has(WadGame.KEY_SECTOR_TO_INTERACTION):
			for sec_key in md[WadGame.KEY_SECTOR_TO_INTERACTION]:
				targeted_sectors.append(sec_key)
		if md.has(WadGame.KEY_SECTORS_PARSED):
			for sec in md[WadGame.KEY_SECTORS_PARSED]:
				# Sector type 9 = secret in DOOM
				if sec["type"] != 9:
					continue
				var sec_idx : int = sec["index"]
				if spawned_sectors.has(sec_idx) or targeted_sectors.has(sec_idx):
					continue
				# Find position from sector polygon
				if sec_idx < 0 or sec_idx >= sector_poly_arr.size():
					continue
				var polygon : PackedVector2Array = sector_poly_arr[sec_idx]
				if polygon.is_empty():
					continue
				var centroid = Vector2.ZERO
				for point in polygon:
					centroid += point
				centroid /= polygon.size()
				var y : float = sec.get(WadGame.KEY_FLOOR_HEIGHT, 0.0)
				var world_pos = Vector3(centroid.x, y, centroid.y)

				# Find the door node for this sector if it exists in the Interactables tree
				var door_node : Node3D = null
				if interactables_node:
					var sector_parent = interactables_node.get_node_or_null(WadGame.SECTOR_PREFIX_UPPER + str(sec_idx))
					if sector_parent:
						for child in sector_parent.get_children():
							if child.has_method("activate"):
								door_node = child
								break

				# If no door node exists, look for an adjacent door sector
				if door_node == null:
					var geom_node = map_node.get_node_or_null(WadGame.NODE_GEOMETRY)
					if geom_node:
						var sec_node = geom_node.get_node_or_null(WadGame.SECTOR_PREFIX_LOWER + str(sec_idx))
						if sec_node:
							# Use sector geometry position as fallback
							pass

				if door_node == null:
					continue
				var interactable = INTERACTABLE_SCENE.instantiate()
				interactable.wadNode = door_node
				interactable.interactable_name = door_node.name
				add_child(interactable)
				interactable.global_position = _wadToWorld(world_pos)
				interactable_count += 1

func _getInteractablePosition(node: Node3D, sector_poly_arr: Array, sectors_parsed: Array = []) -> Variant:
	# Parse sector index from parent node name (e.g. "Sector 42")
	var parent_name = node.get_parent().name as String
	var parent_lower = parent_name.to_lower()
	if not parent_lower.begins_with(WadGame.SECTOR_PREFIX_LOWER):
		return null
	var sec_index = parent_name.substr(7).to_int()

	if sec_index < 0 or sec_index >= sector_poly_arr.size():
		return null

	var polygon: PackedVector2Array = sector_poly_arr[sec_index]
	if polygon.is_empty():
		return null

	# Compute centroid of the sector polygon
	var centroid = Vector2.ZERO
	for point in polygon:
		centroid += point
	centroid /= polygon.size()

	# Use sectorInfo floor height for Y position, fall back to parsed sector data
	var sector_info = node.get(WadGame.PROP_SECTOR_INFO)
	var y = 0.0
	if sector_info != null and sector_info.has(WadGame.KEY_FLOOR_HEIGHT):
		y = sector_info[WadGame.KEY_FLOOR_HEIGHT]
	elif sec_index < sectors_parsed.size():
		y = sectors_parsed[sec_index].get(WadGame.KEY_FLOOR_HEIGHT, 0.0)

	return Vector3(centroid.x, y, centroid.y)

func _getSwitchPosition(node: Node3D, fallback_y: float) -> Variant:
	# Find the trigger linedef position from passer child nodes.
	# Prefer children with a SWITCH trigger type — some nodes have multiple
	# passer children from different linedefs (walk-over, door, switch) and we
	# need the one that corresponds to the actual switch linedef.
	var best_child : Node = null
	for child in node.get_children():
		if child.has_meta(WadGame.PROP_LINE_START) and child.has_meta(WadGame.PROP_LINE_END):
			if best_child == null:
				best_child = child
			# Prefer the child whose triggerType is SWITCH1 or SWITCHR
			if child.has_meta(WadGame.PROP_TRIGGER_TYPE):
				var tt = child.get_meta(WadGame.PROP_TRIGGER_TYPE)
				if tt == WADG.TTYPE.SWITCH1 or tt == WADG.TTYPE.SWITCHR:
					best_child = child
					break
	if best_child == null:
		return null
	var line_start: Vector2 = best_child.get_meta(WadGame.PROP_LINE_START)
	var line_end: Vector2 = best_child.get_meta(WadGame.PROP_LINE_END)
	var mid = (line_start + line_end) / 2.0
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	if level_nodes.is_empty():
		return null
	var map_node = level_nodes[0]
	var map_scale = map_node.scale
	var world_x = mid.x * map_scale.x
	var world_z = mid.y * map_scale.z
	# DOOM doesn't check height for switch interactions. The switch linedef sits
	# on the boundary between two sectors that may have different floor heights.
	# Sample both sides of the linedef and use the lower floor — that's the side
	# the player stands on.
	var line_dir = (line_end - line_start).normalized()
	var normal = Vector2(-line_dir.y, line_dir.x)
	var offset_a = mid + normal * 0.5
	var offset_b = mid - normal * 0.5
	var y = fallback_y
	var info_a = WADG.getSectorInfoForPoint(map_node, Vector2(offset_a.x * map_scale.x, offset_a.y * map_scale.z))
	var info_b = WADG.getSectorInfoForPoint(map_node, Vector2(offset_b.x * map_scale.x, offset_b.y * map_scale.z))
	var y_a = info_a[WadGame.KEY_FLOOR_HEIGHT] if info_a != null and info_a.has(WadGame.KEY_FLOOR_HEIGHT) else fallback_y
	var y_b = info_b[WadGame.KEY_FLOOR_HEIGHT] if info_b != null and info_b.has(WadGame.KEY_FLOOR_HEIGHT) else fallback_y
	# The target sector (fallback_y) is what the switch affects. The player stands
	# on the OTHER side. Pick whichever floor height is further from the target.
	if abs(y_a - fallback_y) >= abs(y_b - fallback_y):
		y = y_a
	else:
		y = y_b
	return Vector3(world_x, y, world_z)

func _getDoorMeshPosition(door_node: Node3D) -> Variant:
	# Try to find the door's visual position from its target mesh nodes.
	# Returns a WAD-space position (before map centering offset).
	var targets = door_node.get(WadGame.PROP_TARGETS)
	if targets == null or targets.size() == 0:
		return null
	var map_parent = door_node.get_parent().get_parent().get_parent()
	if map_parent == null:
		return null
	var total_pos = Vector3.ZERO
	var count = 0
	for target_path in targets:
		var target_node = map_parent.get_node_or_null(target_path)
		if target_node != null and target_node is Node3D:
			# Convert global position back to WAD space
			total_pos += target_node.global_position + _map_origin_offset
			count += 1
	if count == 0:
		return null
	return total_pos / count

func _registerEntitySectorRider(entity: Node3D, pos: Vector3) -> void:
	var loader = Game.wadLoader._loader
	var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
	if not floor_info.has(WadGame.KEY_SECTOR) or floor_info[WadGame.KEY_SECTOR] == null:
		return
	var sector_idx = floor_info[WadGame.KEY_SECTOR]
	var level_nodes = get_tree().get_nodes_in_group(WadGame.GROUP_LEVEL)
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	# curH is set on interactable parent nodes under Interactables/Sector XX (capital S)
	var interact_node = map_node.get_node_or_null(WadGame.INTERACTABLES_SECTOR_PATH + str(sector_idx))
	if interact_node == null or not interact_node.has_meta(WadGame.PROP_CUR_H):
		return
	var cur_h = interact_node.get_meta(WadGame.PROP_CUR_H)
	_entity_sector_riders.append({RIDER_NODE: entity, RIDER_SECTOR_NODE: interact_node, RIDER_LAST_H: cur_h})

func _physics_process(delta: float) -> void:
	var i = _entity_sector_riders.size() - 1
	while i >= 0:
		var entry = _entity_sector_riders[i]
		if not is_instance_valid(entry[RIDER_NODE]) or not is_instance_valid(entry[RIDER_SECTOR_NODE]):
			_entity_sector_riders.remove_at(i)
			i -= 1
			continue
		var cur_h = entry[RIDER_SECTOR_NODE].get_meta(WadGame.PROP_CUR_H)
		var diff = cur_h - entry[RIDER_LAST_H]
		if abs(diff) > 0.001:
			entry[RIDER_NODE].global_position.y += diff
			entry[RIDER_LAST_H] = cur_h
		i -= 1
