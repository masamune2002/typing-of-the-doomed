extends Node3D

@export var wad_game : WadGame = preload("res://wads/doom/DoomGame.tres")

const LEVELS_DIR = "res://wads/doom/levels/"

var _current_rail_network: Node3D = null
var _sector_lighting : SectorLighting
var _currentMapIdx : int = 0
var _entity_sector_riders : Array = []
var _title_screen : TitleScreen = null
var _pause_menu : GameMenu = null
var _wad_file_path : String = ""
var _pending_save_data : Dictionary = {}
var _map_origin_offset : Vector3 = Vector3.ZERO  # Offset to center map on player spawn
var _dump_map_name : String = ""  # Set via --dump-map CLI arg

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
	_sector_lighting = SectorLighting.new()
	add_child(_sector_lighting)

	# Check for command-line arguments
	var user_args = OS.get_cmdline_user_args()
	for i in user_args.size():
		if user_args[i] == "--dump-map" and i + 1 < user_args.size():
			_dump_map_name = user_args[i + 1].to_upper()
	# --playthrough [start_map]: chained autoplay through every map that has
	# a RailNetwork level, starting at start_map (default E1M1)
	for i in user_args.size():
		if user_args[i] == "--playthrough":
			SettingsManager.autoplay_chain = true
			var start_map := "E1M1"
			if i + 1 < user_args.size() and not user_args[i + 1].begins_with("--"):
				start_map = user_args[i + 1]
			_startAutoplay(start_map)
			return
	# --dump-map implies --map (load the level to dump its data)
	for i in user_args.size():
		if (user_args[i] == "--map" or user_args[i] == "--dump-map") and i + 1 < user_args.size():
			_startAutoplay(user_args[i + 1])
			return

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

func _startAutoplay(map_name: String) -> void:
	# Enable autoplay mode flags
	SettingsManager.autoplay = true
	SettingsManager.autoplay_map = map_name.to_upper()
	SettingsManager.debug_skip_encounters = true
	SettingsManager.debug_skip_doors = true
	SettingsManager.debug_tracking = true
	# Autoplay validates the route, not survivability: enemies stay live and
	# shooting while the rail never fights back, so damage is disabled.
	SettingsManager.debug_god_mode = true
	print("[AUTOPLAY] Starting map %s with skip_encounters, skip_doors, god_mode, tracking" % SettingsManager.autoplay_map)

	# Find the map index in wad_game.map_names
	var map_idx := -1
	for i in wad_game.map_names.size():
		if wad_game.map_names[i].to_upper() == SettingsManager.autoplay_map:
			map_idx = i
			break
	if map_idx < 0:
		printerr("[AUTOPLAY] ERROR: Map '%s' not found in wad_game.map_names: %s" % [map_name, wad_game.map_names])
		get_tree().quit(1)
		return

	# Find a WAD file
	var wad_path := SettingsManager.last_wad_path
	if wad_path == "" or not FileAccess.file_exists(wad_path):
		var wad_files = _findWadFiles()
		if wad_files.is_empty():
			printerr("[AUTOPLAY] ERROR: No WAD file found")
			get_tree().quit(1)
			return
		wad_path = wad_files[0]

	_wad_file_path = wad_path
	Game.wadLoader.init_wad(_wad_file_path)
	_currentMapIdx = map_idx
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.wadLoader.map_name = wad_game.map_names[_currentMapIdx]
	Game.wadLoader.load_wad(_wad_file_path, 0)

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
	_carry_over_state = {}
	_skip_state_capture = true
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
	_sector_lighting.setup()
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
	if _dump_map_name != "":
		_dumpMapData()
		get_tree().quit()

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
	Game.playSound(DoomGame.SWITCH_ON)
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
	Game.playSound(DoomGame.SWITCH_OFF)
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

	if SettingsManager.autoplay:
		var player = Game.getPlayer()
		var last_station = ""
		if player != null and player.currentEncounter != null:
			last_station = player.currentEncounter.name
		print("[AUTOPLAY] DONE map=%s last_station=%s" % [SettingsManager.autoplay_map, last_station])
		if SettingsManager.autoplay_chain:
			_advancePlaythrough()
			return
		get_tree().quit(0)
		return

	var next_idx = _currentMapIdx + 1

	if next_idx >= wad_game.map_names.size():
		_currentMapIdx = next_idx
		Game.getPlayer().win()
		return

	# Show intermission screen
	_showIntermission(wad_game.map_names[_currentMapIdx], wad_game.map_names[next_idx], next_idx)

func _advancePlaythrough() -> void:
	# Chained autoplay: skip the intermission and load the next map that has
	# a RailNetwork level; end the run when none is left (e.g. E2M1).
	# _loadMap clears Game vars and resets _transitioning when the map loads.
	var next_idx = _currentMapIdx + 1
	if next_idx >= wad_game.map_names.size() \
			or not ResourceLoader.exists(LEVELS_DIR + wad_game.map_names[next_idx] + ".tscn"):
		print("[AUTOPLAY] PLAYTHROUGH COMPLETE last_map=%s" % SettingsManager.autoplay_map)
		get_tree().quit(0)
		return
	_currentMapIdx = next_idx
	var next_map: String = wad_game.map_names[next_idx]
	SettingsManager.autoplay_map = next_map
	print("[AUTOPLAY] Advancing to %s" % next_map)
	_loadMap(next_map)

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
	Game.clearVars()
	_sector_lighting.clear()
	_entity_sector_riders.clear()
	if _nav_region != null:
		_nav_region.queue_free()
		_nav_region = null
	for wall in _blocking_walls:
		wall.queue_free()
	_blocking_walls.clear()

	# Capture player state before resetting (unless restarting after death)
	var old_player = Game.getPlayer()
	if old_player != null and not _skip_state_capture:
		_carry_over_state = old_player.getState()
		# Don't carry over position, rotation, or keys between maps
		_carry_over_state.erase("position")
		_carry_over_state.erase("camera_rot_h")
		_carry_over_state.erase("camera_rot_v")
		_carry_over_state.erase("keys")
	if old_player != null:
		old_player.visible = false
		Game.player = null

	# Remove everything from the EnemyContainer (enemies, items, barrels)
	var container = $EntityContainer
	for child in container.get_children():
		child.queue_free()


	# Remove interactable wrappers
	for node in get_tree().get_nodes_in_group(WadGame.GROUP_INTERACTABLES):
		node.queue_free()

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
		if (flags & DoomGame.THING_FLAG_HARD) == 0:
			continue
		if (flags & DoomGame.THING_FLAG_MULTIPLAYER) != 0:
			continue

		var enemy_def = wad_game.enemies[thing["type"]]
		var enemy = enemy_def["scene"].instantiate()

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
		if (flags & DoomGame.THING_FLAG_HARD) == 0:
			continue
		if (flags & DoomGame.THING_FLAG_MULTIPLAYER) != 0:
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
		if (flags & DoomGame.THING_FLAG_HARD) == 0:
			continue
		if (flags & DoomGame.THING_FLAG_MULTIPLAYER) != 0:
			continue

		var wpn_def = wad_game.weapon_pickup_definitions[thing["type"]]
		var item_def = {
			"name": wpn_def["name"],
			"sprites": wpn_def["sprites"],
			"effect": "weapon",
			"weapon_scene": wpn_def["weapon_scene"],
			"sound": wpn_def.get("sound", DoomGame.WEAPON_PICKUP),
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
		if (flags & DoomGame.THING_FLAG_HARD) == 0:
			continue
		if (flags & DoomGame.THING_FLAG_MULTIPLAYER) != 0:
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
		if (flags & DoomGame.THING_FLAG_HARD) == 0:
			continue
		if (flags & DoomGame.THING_FLAG_MULTIPLAYER) != 0:
			continue

		var def = wad_game.decoration_definitions[thing["type"]]
		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]

		var node = Node3D.new()
		node.name = def["name"] + str(deco_count)
		$EntityContainer.add_child(node)
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

	var player : Player = %DoomPlayer
	player.visible = true
	player.reset()
	player.global_position = _wadToWorld(spawn_pos) + Vector3(0, 1.5, 0)

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

	# Debug: dump all interactable candidates near player spawn
	var _player_spawn_pos := Vector3.ZERO
	var _loader_for_debug = Game.wadLoader._loader
	var _mn_debug = _loader_for_debug.mapName
	if not _loader_for_debug.maps.has(_mn_debug):
		_mn_debug = _mn_debug.to_upper()
	if _loader_for_debug.maps.has(_mn_debug) and _loader_for_debug.maps[_mn_debug].has(WadGame.KEY_THINGS_PARSED):
		for thing in _loader_for_debug.maps[_mn_debug][WadGame.KEY_THINGS_PARSED]:
			if thing["type"] == 1:
				_player_spawn_pos = thing["pos"]
				break

	var interactable_count = 0
	var skipped_no_activate = 0
	var skipped_no_ttype = 0
	var skipped_wrong_ttype = 0
	var skipped_no_pos = 0
	var spawned_lift_sectors : Array[int] = []  # one interactable per lift sector
	for node in all_level_objects:
		var script_path = node.get_script().resource_path if node.get_script() != null else ""
		var is_lift = script_path.ends_with(WadGame.SCRIPT_LIFT)
		var is_stair = script_path.ends_with(WadGame.SCRIPT_STAIRS)
		var is_exit = script_path.ends_with(WadGame.SCRIPT_LEVEL_CHANGE)
		var is_floor = script_path.ends_with("floor.gd")
		if not node.has_method("activate") and not is_lift and not is_stair:
			skipped_no_activate += 1
			continue
		if not node is Node3D:
			continue
		var ttype = node.get(WadGame.PROP_TRIGGER_TYPE)
		if ttype == null:
			skipped_no_ttype += 1
			continue
		var valid_ttypes = [WADG.TTYPE.DOOR, WADG.TTYPE.DOOR1, WADG.TTYPE.SWITCH1, WADG.TTYPE.SWITCHR, WADG.TTYPE.WALK1, WADG.TTYPE.WALKR]
		var nodeKeyType = node.get(WadGame.PROP_KEY_TYPE)
		var isKeyDoor = nodeKeyType != null and nodeKeyType < 4
		if ttype not in valid_ttypes:
			skipped_wrong_ttype += 1
			continue

		# Only one interactable per lift sector
		if is_lift:
			var parent_name_l = node.get_parent().name as String
			if parent_name_l.to_lower().begins_with(WadGame.SECTOR_PREFIX_LOWER):
				var sec_idx_l = parent_name_l.substr(7).to_int()
				if sec_idx_l in spawned_lift_sectors:
					continue
				spawned_lift_sectors.append(sec_idx_l)

		# Calculate world position
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
		interactable.interactable_name = _interactableNameFor(node)
		if is_lift:
			interactable.interactable_type = Interactable.InteractableType.LIFT
		elif is_exit:
			interactable.interactable_type = Interactable.InteractableType.EXIT
		elif is_floor:
			interactable.interactable_type = Interactable.InteractableType.FLOOR
		else:
			interactable.interactable_type = Interactable.InteractableType.DOOR
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
		# For lifts, reposition to the floor mesh once global transforms are ready
		if is_lift:
			var info_l = node.get("info")
			if info_l != null:
				var targets_l = info_l.get("targets", [])
				var map_node_l = node.get_parent().get_parent().get_parent()
				for t in targets_l:
					if str(t).contains("/floor "):
						var tn = map_node_l.get_node_or_null(t)
						if tn != null and tn is Node3D:
							var ia = interactable
							var fn = tn
							(func(): ia.global_position = fn.global_position).call_deferred()
							break
		interactable_count += 1

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
				interactable.interactable_name = _interactableNameFor(door_node)
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

func _interactableNameFor(wad_node: Node) -> String:
	if wad_node == null or wad_node.get_parent() == null:
		return ""
	var parent_name : String = wad_node.get_parent().name
	var lower := parent_name.to_lower()
	if not lower.begins_with(WadGame.SECTOR_PREFIX_LOWER):
		return ""
	var sec_index := parent_name.substr(7).to_int()
	return "sector_%d" % sec_index

# ── Map Data Dump (--dump-map) ──────────────────────────────────────────

func _dumpMapData() -> void:
	var loader = Game.wadLoader._loader
	var mn = _dump_map_name
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if not loader.maps.has(mn):
		print("[DUMP] ERROR: Map '%s' not found" % _dump_map_name)
		return
	var md = loader.maps[mn]

	# Build thing type lookup from wad_game
	var thing_names := {}
	thing_names[1] = "PlayerStart"
	thing_names[2] = "PlayerStart2"
	thing_names[3] = "PlayerStart3"
	thing_names[4] = "PlayerStart4"
	thing_names[11] = "DeathmatchStart"
	thing_names[14] = "TeleportDest"
	for id in wad_game.enemies:
		thing_names[id] = wad_game.enemies[id]["name"]
	for id in wad_game.item_definitions:
		thing_names[id] = wad_game.item_definitions[id]["name"]
	for id in wad_game.weapon_pickup_definitions:
		thing_names[id] = wad_game.weapon_pickup_definitions[id]["name"]
	for id in wad_game.decoration_definitions:
		thing_names[id] = wad_game.decoration_definitions[id]["name"]

	# Sector type descriptions
	var sector_type_names := {
		0: "Normal",
		1: "BlinkRandom",
		2: "Blink0.5s",
		3: "Blink1.0s",
		4: "Damage20+BlinkRandom",
		5: "Damage10",
		7: "Damage5",
		8: "Oscillate",
		9: "Secret",
		10: "DoorClose30s",
		11: "Damage20+End",
		12: "BlinkSync0.5s",
		13: "BlinkSync1.0s",
		14: "DoorOpen300s",
		16: "Damage20",
		17: "Flicker",
	}

	print("[DUMP_START] %s" % mn)

	# ── Bounding box
	var min_dim = md.get("minDim", Vector3.ZERO)
	var max_dim = md.get("maxDim", Vector3.ZERO)
	print("[BOUNDS] min=%s max=%s" % [min_dim, max_dim])

	# ── Vertices
	var verts : PackedVector2Array = md.get("vertexesParsed", PackedVector2Array())
	print("[VERTICES] count=%d" % verts.size())
	for i in verts.size():
		print("[VERT] %d pos=(%s, %s)" % [i, verts[i].x, verts[i].y])

	# ── Sectors
	var sectors : Array = md.get(WadGame.KEY_SECTORS_PARSED, [])
	print("[SECTORS] count=%d" % sectors.size())
	for sec in sectors:
		var type_name = sector_type_names.get(sec["type"], "Unknown(%d)" % sec["type"])
		var tag = sec.get("tagNum", 0)
		var neighbours = sec.get("nieghbourSectors", PackedInt32Array())
		print("[SECTOR] %d floor=%.1f ceil=%.1f light=%d type=%s tag=%d floorTex=%s ceilTex=%s neighbours=%s" % [
			sec["index"], sec["floorHeight"], sec["ceilingHeight"],
			sec["lightLevel"], type_name, tag,
			sec.get("floorTexture", ""), sec.get("ceilingTexture", ""),
			str(neighbours)])

	# ── Sidedefs
	var sides : Array = md.get("sideDefsParsed", [])
	print("[SIDEDEFS] count=%d" % sides.size())
	for side in sides:
		var upper = side.get("upperName", "-")
		var mid = side.get("middleName", "-")
		var lower = side.get("lowerName", "-")
		if upper == "-" and mid == "-" and lower == "-":
			continue  # Skip untextured sidedefs to reduce noise
		print("[SIDEDEF] %d sector=%d upper=%s mid=%s lower=%s" % [
			side["index"], side["sector"], upper, mid, lower])

	# ── Linedefs
	var lines : Array = md.get("lineDefsParsed", [])
	print("[LINEDEFS] count=%d" % lines.size())
	for line in lines:
		var line_type = line.get("type", 0)
		var front_sec = line.get("frontSector", -1)
		var back_sec = line.get("backSector", null)
		var tag = line.get("sectorTag", 0)
		var trigger = line.get("triggerType", "")
		var sv = line["startVert"]
		var ev = line["endVert"]
		var start_pos = verts[sv] if sv < verts.size() else Vector2.ZERO
		var end_pos = verts[ev] if ev < verts.size() else Vector2.ZERO
		if line_type != 0:
			print("[LINEDEF_TRIGGER] %d type=%d tag=%d trigger=%s front_sector=%d back_sector=%s verts=(%d,%d) start=(%s,%s) end=(%s,%s)" % [
				line["index"], line_type, tag, trigger, front_sec,
				str(back_sec) if back_sec != null else "none",
				sv, ev, start_pos.x, start_pos.y, end_pos.x, end_pos.y])
		else:
			# Only print wall lines (one-sided) for geometry context
			if back_sec == null:
				print("[LINEDEF_WALL] %d front_sector=%d verts=(%d,%d) start=(%s,%s) end=(%s,%s)" % [
					line["index"], front_sec, sv, ev,
					start_pos.x, start_pos.y, end_pos.x, end_pos.y])
			else:
				print("[LINEDEF_PORTAL] %d front_sector=%d back_sector=%d verts=(%d,%d)" % [
					line["index"], front_sec, back_sec, sv, ev])

	# ── Sector interactions
	var interactions = md.get(WadGame.KEY_SECTOR_TO_INTERACTION, {})
	print("[INTERACTIONS] sector_count=%d" % interactions.size())
	for sec_idx in interactions:
		for inter in interactions[sec_idx]:
			var ttype = inter.get("triggerType", "")
			var ltype = inter.get("type", 0)
			var line_idx = inter.get("line", -1)
			var npc = inter.get("npcTrigger", "")
			print("[INTERACTION] sector=%d linedef=%d type=%d trigger=%s npc=%s" % [
				sec_idx, line_idx, ltype, ttype, npc])

	# ── Things
	var things : Array = md.get(WadGame.KEY_THINGS_PARSED, [])
	print("[THINGS] count=%d" % things.size())
	for i in things.size():
		var thing = things[i]
		var type_id = thing["type"]
		var name = thing_names.get(type_id, "Unknown(%d)" % type_id)
		var pos = thing["pos"]
		var flags = thing["flags"]
		var angle = thing.get("rot", 0)
		var skill_str = ""
		if flags & 0b1: skill_str += "easy "
		if flags & 0b10: skill_str += "med "
		if flags & 0b100: skill_str += "hard "
		if flags & 0b1000: skill_str += "ambush "
		if flags & 0b10000: skill_str += "multi "
		print("[THING] %d type=%d name=%s pos=(%s, %s, %s) angle=%d flags=[%s]" % [
			i, type_id, name, pos.x, pos.y, pos.z, angle, skill_str.strip_edges()])

	# ── Tag-to-sector mapping
	var tag_map = md.get("tagToSectors", {})
	if tag_map.size() > 0:
		print("[TAG_MAP] count=%d" % tag_map.size())
		for tag in tag_map:
			print("[TAG] %d -> sectors=%s" % [tag, str(tag_map[tag])])

	print("[DUMP_END] %s" % mn)
