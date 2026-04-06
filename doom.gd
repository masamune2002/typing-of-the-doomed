extends Node3D

var _flicker_sectors : Array = []  # Array of { meshes, bright, dark, mode, timer, on, phase }
var _currentMapIdx : int = 0
var _entity_sector_riders : Array = []  # Array of { node, sector_node, last_h } for platform riding
var _map_select_ui : CanvasLayer = null
var _wad_file_path : String = ""

const FIRST_MAP_IDX = 0
const MAP_NAMES = ["E1M1", "E1M2", "E1M3", "E1M4", "E1M5", "E1M6", "E1M7", "E1M8", "E1M9"]
const PLAYER_SCENE = preload("res://rail/scenes/Player/Player.tscn")

const ENEMY_SCENES = {
	3004: preload("res://rail/scenes/Enemies/Zombieman/Zombieman.tscn"),
	9: preload("res://rail/scenes/Enemies/ShotgunGuy/ShotgunGuy.tscn"),
	3001: preload("res://rail/scenes/Enemies/Imp/Imp.tscn"),
	3002: preload("res://rail/scenes/Enemies/Pinky/Pinky.tscn"),
	3005: preload("res://rail/scenes/Enemies/Cacodemon/Cacodemon.tscn"),
	3003: preload("res://rail/scenes/Enemies/BaronOfHell/BaronOfHell.tscn"),
	3006: preload("res://rail/scenes/Enemies/LostSoul/LostSoul.tscn"),
	16: preload("res://rail/scenes/Enemies/Cyberdemon/Cyberdemon.tscn"),
	7: preload("res://rail/scenes/Enemies/SpiderDemon/SpiderDemon.tscn"),
}

const ENEMY_NAMES = {
	3004: "Zombieman", 9: "ShotgunGuy", 3001: "Imp", 3002: "Pinky",
	3005: "Cacodemon", 3003: "BaronOfHell", 3006: "LostSoul",
	16: "Cyberdemon", 7: "SpiderDemon",
}

const ITEM_SCENE = preload("res://rail/scenes/Items/Item.tscn")
const INTERACTABLE_SCENE = preload("res://rail/scenes/Interactables/Interactable.tscn")
const BARREL_SCENE = preload("res://rail/scenes/Barrels/ExplodingBarrel.tscn")
const BARREL_THING_TYPE = 2035

# Decorations: thing_type -> { "name": str, "sprites": [frame names], "blocking": bool }
const DECORATION_DEFINITIONS = {
	2028: { "name": "FloorLamp",      "sprites": ["COLUA0"],                         "blocking": true },
	2035: { "name": "ExplodingBarrel","sprites": ["BAR1A0", "BAR1B0"],               "blocking": true },
	35:   { "name": "Candelabra",     "sprites": ["CBRAA0"],                         "blocking": true },
	48:   { "name": "TallTechnoPillar","sprites": ["ELECA0"],                        "blocking": true },
	2049: { "name": "TallGreenPillar","sprites": ["COL3A0"],                         "blocking": true },
	2048: { "name": "TallTechColumn", "sprites": ["COL1A0"],                         "blocking": true },
	2046: { "name": "BurningBarrel",  "sprites": ["FCANA0", "FCANB0", "FCANC0"],     "blocking": true },
	30:   { "name": "TallGreenPillar2","sprites": ["COL1A0"],                        "blocking": true },
	31:   { "name": "ShortGreenPillar","sprites": ["COL2A0"],                        "blocking": true },
	32:   { "name": "TallRedPillar",  "sprites": ["COL4A0"],                         "blocking": true },
	33:   { "name": "ShortRedPillar", "sprites": ["COL6A0"],                         "blocking": true },
	34:   { "name": "Candle",         "sprites": ["CANDA0"],                         "blocking": false },
	44:   { "name": "TallBlueTorch",  "sprites": ["TBLUA0", "TBLUB0", "TBLUC0", "TBLUD0"], "blocking": true },
	45:   { "name": "TallGreenTorch", "sprites": ["TGRNA0", "TGRNB0", "TGRNC0", "TGRND0"], "blocking": true },
	46:   { "name": "TallRedTorch",   "sprites": ["Treda0", "TREDB0", "TREDC0", "TREDD0"], "blocking": true },
	55:   { "name": "ShortBlueTorch", "sprites": ["SMBTA0", "SMBTB0", "SMBTC0", "SMBTD0"], "blocking": true },
	56:   { "name": "ShortGreenTorch","sprites": ["SMGTA0", "SMGTB0", "SMGTC0", "SMGTD0"], "blocking": true },
	57:   { "name": "ShortRedTorch",  "sprites": ["SMRTA0", "SMRTB0", "SMRTC0", "SMRTD0"], "blocking": true },
	47:   { "name": "Stalagtite",     "sprites": ["SMITA0"],                         "blocking": true },
	43:   { "name": "BurntTree",      "sprites": ["TRE1A0"],                         "blocking": true },
	54:   { "name": "BigTree",        "sprites": ["TRE2A0"],                         "blocking": true },
	# Gore decorations
	10:   { "name": "BloodyMess",     "sprites": ["PLAYW0"],                         "blocking": false },
	12:   { "name": "BloodyMess2",    "sprites": ["PLAYW0"],                         "blocking": false },
	15:   { "name": "DeadPlayer",     "sprites": ["PLAYN0"],                         "blocking": false },
	18:   { "name": "DeadZombieman",  "sprites": ["POSSN0"],                         "blocking": false },
	19:   { "name": "DeadShotgunGuy", "sprites": ["SPOTN0"],                         "blocking": false },
	20:   { "name": "DeadImp",        "sprites": ["TROOM0"],                         "blocking": false },
	21:   { "name": "DeadDemon",      "sprites": ["SARGN0"],                         "blocking": false },
	22:   { "name": "DeadCacodemon",  "sprites": ["HEADL0"],                         "blocking": false },
	23:   { "name": "DeadLostSoul",   "sprites": ["SKULK0"],                         "blocking": false },
	24:   { "name": "PoolOfFlesh",    "sprites": ["POL5A0"],                         "blocking": false },
	25:   { "name": "ImpaledHuman",   "sprites": ["POL1A0"],                         "blocking": true },
	26:   { "name": "TwitchingImpaled","sprites": ["POL6A0", "POL6B0"],              "blocking": true },
	27:   { "name": "SkullPole",      "sprites": ["POL4A0"],                         "blocking": true },
	28:   { "name": "SkullShishKebab","sprites": ["POL2A0"],                         "blocking": true },
	29:   { "name": "SkullsOnPole",   "sprites": ["POL3A0", "POL3B0"],              "blocking": true },
	49:   { "name": "HangingBody1",   "sprites": ["GOR1A0"],                         "blocking": true },
	50:   { "name": "HangingBody2",   "sprites": ["GOR2A0"],                         "blocking": false },
	51:   { "name": "HangingBody3",   "sprites": ["GOR3A0"],                         "blocking": false },
	52:   { "name": "HangingBody4",   "sprites": ["GOR4A0"],                         "blocking": false },
	53:   { "name": "HangingBody5",   "sprites": ["GOR5A0"],                         "blocking": true },
	73:   { "name": "HangingLeg",     "sprites": ["HDB1A0"],                         "blocking": true },
	74:   { "name": "HangingLeg2",    "sprites": ["HDB2A0"],                         "blocking": false },
	75:   { "name": "HangingVictim",  "sprites": ["HDB3A0"],                         "blocking": false },
	76:   { "name": "HangingArms",    "sprites": ["HDB4A0"],                         "blocking": false },
	77:   { "name": "HangingLeg3",    "sprites": ["HDB5A0"],                         "blocking": false },
	78:   { "name": "HangingLeg4",    "sprites": ["HDB6A0"],                         "blocking": false },
}

const ITEM_DEFINITIONS = {
	2011: { "name": "Stimpack",    "sprites": ["STIMA0"],                                 "effect": "health", "amount": 10,  "overheal": false, "sound": "DSITEMUP" },
	2012: { "name": "Medkit",      "sprites": ["MEDIA0"],                                 "effect": "health", "amount": 25,  "overheal": false, "sound": "DSITEMUP" },
	2013: { "name": "Soulsphere",  "sprites": ["SOULA0", "SOULB0", "SOULC0", "SOULD0"],   "effect": "health", "amount": 100, "overheal": true,  "sound": "DSGETPOW" },
	2014: { "name": "HealthBonus", "sprites": ["BON1A0", "BON1B0", "BON1C0", "BON1D0"],   "effect": "health", "amount": 1,   "overheal": true,  "sound": "DSITEMUP" },
	2015: { "name": "ArmorBonus",  "sprites": ["BON2A0", "BON2B0", "BON2C0", "BON2D0"],   "effect": "armor",  "amount": 1,   "armor_type": "NONE",  "sound": "DSITEMUP" },
	2018: { "name": "GreenArmor",  "sprites": ["ARM1A0", "ARM1B0"],                       "effect": "armor",  "amount": 100, "armor_type": "GREEN", "sound": "DSITEMUP" },
	2019: { "name": "BlueArmor",   "sprites": ["ARM2A0"],                                 "effect": "armor",  "amount": 200, "armor_type": "BLUE",  "sound": "DSGETPOW" },
	# Keys
	5:    { "name": "BlueKeycard",  "sprites": ["BKEYA0", "BKEYB0"],                       "effect": "key", "key": "blue_keycard",    "sound": "DSITEMUP" },
	6:    { "name": "YellowKeycard","sprites": ["YKEYA0", "YKEYB0"],                       "effect": "key", "key": "yellow_keycard",  "sound": "DSITEMUP" },
	13:   { "name": "RedKeycard",   "sprites": ["RKEYA0", "RKEYB0"],                       "effect": "key", "key": "red_keycard",     "sound": "DSITEMUP" },
	40:   { "name": "BlueSkullKey", "sprites": ["BSKUA0", "BSKUB0"],                       "effect": "key", "key": "blue_skull",      "sound": "DSITEMUP" },
	38:   { "name": "YellowSkullKey","sprites": ["YSKUA0", "YSKUB0"],                      "effect": "key", "key": "yellow_skull",    "sound": "DSITEMUP" },
	39:   { "name": "RedSkullKey",  "sprites": ["RSKUA0", "RSKUB0"],                       "effect": "key", "key": "red_skull",       "sound": "DSITEMUP" },
}

func _ready() -> void:
	var loader := WadRuntimeLoader.new()
	add_child(loader)
	loader.mapCreated.connect(_onMapCreated)
	loader.geometry_only = true
	Game.setWadLoader(loader)
	var app_dir = OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir()
	_wad_file_path = app_dir.path_join("../DOOM.wad")
	var wad_file = FileAccess.open(_wad_file_path, FileAccess.READ)
	if !wad_file:
		_wad_file_path = "res://DOOM.wad"

	EventBus.levelExitReached.connect(_onLevelExitReached)
	_showMapSelect()

func _showMapSelect() -> void:
	_map_select_ui = CanvasLayer.new()
	_map_select_ui.layer = 10
	add_child(_map_select_ui)

	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_select_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "EPISODE 1: KNEE-DEEP IN THE DEAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var map_descriptions = {
		"E1M1": "Hangar",
		"E1M2": "Nuclear Plant",
		"E1M3": "Toxin Refinery",
		"E1M4": "Command Control",
		"E1M5": "Phobos Lab",
		"E1M6": "Central Processing",
		"E1M7": "Computer Station",
		"E1M8": "Phobos Anomaly",
		"E1M9": "Military Base (Secret)",
	}

	for i in MAP_NAMES.size():
		var map_name = MAP_NAMES[i]
		var btn := Button.new()
		var desc = map_descriptions.get(map_name, "")
		btn.text = map_name + " - " + desc
		btn.custom_minimum_size = Vector2(350, 40)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_onMapSelected.bind(i))
		vbox.add_child(btn)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _onMapSelected(idx: int) -> void:
	_currentMapIdx = idx
	_map_select_ui.queue_free()
	_map_select_ui = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.wadLoader.map_name = MAP_NAMES[_currentMapIdx]
	Game.wadLoader.load_wad(_wad_file_path, 0)

func _onMapCreated() -> void:
	_spawnPlayer()
	_spawnEnemiesFromWad()
	_spawnDecorationsFromWad()
	_spawnSectorLights()
	_spawnInteractablesFromWad()
	_overrideExitNodes()
	# Start the encounter immediately so all entities activate
	$EncounterPoint.startEncounter()

func _overrideExitNodes() -> void:
	var level_nodes = get_tree().get_nodes_in_group("level")
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var interactables_node = map_node.get_node_or_null("Interactables")
	if interactables_node == null:
		return

	var exit_script = GDScript.new()
	exit_script.source_code = "
extends Node3D

var yeilding = false
var overlappingBodies: Array[Node] = []
var walkOverBodies: Array = []
@export var triggerType: WADG.TTYPE
@export var secret: bool = false

func _ready():
	set_physics_process(false)

func bin(body):
	pass

func bout(body):
	pass

func bodyIn(body):
	pass

func activate():
	EventBus.levelExitReached.emit()

func walkOverTrigger(body):
	pass
"
	exit_script.reload()

	for sector_node in interactables_node.get_children():
		for child in sector_node.get_children():
			if child.get_script() != null and child.get_script().resource_path.ends_with("levelChange.gd"):
				# Preserve state the node already has
				var old_trigger = child.get("triggerType")
				var old_secret = child.get("secret")
				var old_bodies = child.get("overlappingBodies").duplicate()
				var old_walk = child.get("walkOverBodies").duplicate()
				child.set_script(exit_script)
				child.triggerType = old_trigger
				child.secret = old_secret
				child.overlappingBodies = old_bodies
				child.walkOverBodies = old_walk
				print("[Exit] Overrode levelChange node in ", sector_node.name)

var _transitioning : bool = false

func _onLevelExitReached() -> void:
	if _transitioning:
		return
	_transitioning = true
	_currentMapIdx += 1
	if _currentMapIdx >= MAP_NAMES.size():
		print("No more levels!")
		Game.getPlayer().win()
		return
	_loadMap(MAP_NAMES[_currentMapIdx])

func _loadMap(map_name: String) -> void:
	print("Loading map: ", map_name)

	# Clean up old entities
	_flicker_sectors.clear()
	_entity_sector_riders.clear()

	# Remove old player
	var old_player = Game.getPlayer()
	if old_player != null:
		old_player.queue_free()
		Game.player = null

	# Remove everything from the EnemyContainer (enemies, items, barrels)
	var container = $EncounterPoint/EnemyContainer
	for child in container.get_children():
		child.queue_free()

	# Reset encounter point
	var encounter_point = $EncounterPoint
	encounter_point.active = false
	encounter_point.conditionsMet = false
	encounter_point.enemies.clear()
	encounter_point.startActions.clear()
	encounter_point.conditions.clear()
	encounter_point.endActions.clear()

	# Remove interactable wrappers
	for node in get_tree().get_nodes_in_group("Interactables"):
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

	# Remove old level geometry
	var level_nodes = get_tree().get_nodes_in_group("level")
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
	if not map_data.has("thingsParsed"):
		return

	var things = map_data["thingsParsed"]
	var encounter_point = $EncounterPoint
	var container = encounter_point.get_node("EnemyContainer")
	var enemy_nodes: Array[Node] = []
	var name_counts = {}

	for thing in things:
		if not ENEMY_SCENES.has(thing["type"]):
			continue

		# Filter by Ultraviolence difficulty (bit 2) and exclude multiplayer-only (bit 4)
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue	

		var scene = ENEMY_SCENES[thing["type"]]
		var enemy = scene.instantiate()

		# Generate unique name
		var base_name = ENEMY_NAMES[thing["type"]]
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		enemy.name = base_name + str(name_counts[base_name])

		container.add_child(enemy)
		enemy_nodes.append(enemy)

		# Resolve Y position using the WAD's floor height lookup
		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		enemy.global_position = pos
		_registerEntitySectorRider(enemy, pos)

	# Spawn items from WAD data
	var item_count = 0
	for thing in things:
		if not ITEM_DEFINITIONS.has(thing["type"]):
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var item_def = ITEM_DEFINITIONS[thing["type"]]
		var item = ITEM_SCENE.instantiate()
		item.itemDefinition = item_def

		var base_name = item_def["name"]
		if not name_counts.has(base_name):
			name_counts[base_name] = 0
		name_counts[base_name] += 1
		item.name = base_name + str(name_counts[base_name])

		container.add_child(item)
		item_count += 1

		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		item.global_position = pos
		_registerEntitySectorRider(item, pos)

	# Spawn barrels from WAD data
	var barrel_count = 0
	for thing in things:
		if thing["type"] != BARREL_THING_TYPE:
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
		barrel.name = base_name + str(name_counts[base_name])

		container.add_child(barrel)

		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]
		barrel.global_position = pos
		_registerEntitySectorRider(barrel, pos)
		barrel_count += 1

	if enemy_nodes.size() == 0:
		return

	# Set up encounter: activate all enemies and track defeat
	var activate_action = ActivateEnemiesAction.new()
	var defeat_condition = EnemiesDefeatedCondition.new()
	var paths: Array[NodePath] = []
	for enemy in enemy_nodes:
		paths.append(encounter_point.get_path_to(enemy))
	activate_action.enemiesToActivate = paths
	defeat_condition.enemies = paths

	var start_actions: Array[EncounterAction] = [activate_action]
	var end_conditions: Array[EncounterCondition] = [defeat_condition]
	encounter_point.startActions = start_actions
	encounter_point.conditions = end_conditions

	var print_action = PrintAction.new()
	print_action.stringToPrint = "Finished encounter"
	var end_actions: Array[EncounterAction] = [print_action]
	encounter_point.endActions = end_actions

	print("Spawned ", enemy_nodes.size(), " enemies, ", item_count, " items, and ", barrel_count, " barrels from WAD data")

func _spawnDecorationsFromWad() -> void:
	var loader = Game.wadLoader._loader
	var map_name = loader.mapName
	if not loader.maps.has(map_name):
		map_name = map_name.to_upper()
	if not loader.maps.has(map_name):
		return
	var map_data = loader.maps[map_name]
	if not map_data.has("thingsParsed"):
		return

	var things = map_data["thingsParsed"]
	var deco_count = 0

	for thing in things:
		if thing["type"] == BARREL_THING_TYPE:
			continue  # Barrels are spawned as interactive entities, not decorations
		if not DECORATION_DEFINITIONS.has(thing["type"]):
			continue
		var flags = thing["flags"]
		if (flags & 0b100) == 0:
			continue
		if (flags & 0b10000) != 0:
			continue

		var def = DECORATION_DEFINITIONS[thing["type"]]
		var pos = thing["pos"]
		var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
		if pos.y == -INF and floor_info.has("height"):
			pos.y = floor_info["height"]

		var node = Node3D.new()
		node.name = def["name"] + str(deco_count)
		add_child(node)
		node.global_position = pos
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
			sprite.position.y = (tex.get_height() / 2.0) * sprite.pixel_size
		else:
			node.queue_free()
			continue

		# Add light for light-emitting decorations
		var light_defs = {
			2028: { "color": Color(1.0, 1.0, 0.8), "energy": 8.0, "range": 12.0 },   # Floor lamp
			35:   { "color": Color(1.0, 0.9, 0.6), "energy": 8.0, "range": 12.0 },   # Candelabra
			34:   { "color": Color(1.0, 0.85, 0.5), "energy": 3.0, "range": 6.0 },   # Candle
			2046: { "color": Color(1.0, 0.6, 0.2), "energy": 8.0, "range": 10.0 },   # Burning barrel
			44:   { "color": Color(0.4, 0.5, 1.0), "energy": 6.0, "range": 10.0 },   # Tall blue torch
			45:   { "color": Color(0.3, 1.0, 0.3), "energy": 6.0, "range": 10.0 },   # Tall green torch
			46:   { "color": Color(1.0, 0.3, 0.2), "energy": 6.0, "range": 10.0 },   # Tall red torch
			55:   { "color": Color(0.4, 0.5, 1.0), "energy": 4.0, "range": 8.0 },    # Short blue torch
			56:   { "color": Color(0.3, 1.0, 0.3), "energy": 4.0, "range": 8.0 },    # Short green torch
			57:   { "color": Color(1.0, 0.3, 0.2), "energy": 4.0, "range": 8.0 },    # Short red torch
		}
		if light_defs.has(thing["type"]):
			var ld = light_defs[thing["type"]]
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
				var anim_script = "
extends Sprite3D
var _frames : Array[Texture2D] = []
var _frame_idx : int = 0
var _timer : float = 0.0
const FRAME_DURATION = 8.0 / 35.0
func setup(f): _frames = f
func _process(delta):
	if _frames.size() < 2: return
	_timer += delta
	if _timer >= FRAME_DURATION:
		_timer = 0.0
		_frame_idx = (_frame_idx + 1) % _frames.size()
		texture = _frames[_frame_idx]
"
				var script = GDScript.new()
				script.source_code = anim_script
				script.reload()
				sprite.set_script(script)
				sprite.setup(frames)

		deco_count += 1

	print("Spawned ", deco_count, " decorations from WAD data")

func _spawnSectorLights() -> void:
	var loader = Game.wadLoader._loader
	var mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if not loader.maps.has(mn):
		return
	var md = loader.maps[mn]
	if not md.has("sectorsParsed"):
		return

	var level_nodes = get_tree().get_nodes_in_group("level")
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	var geom_node = map_node.get_node_or_null("Geometry")
	if geom_node == null:
		return

	var light_sector_types = [1, 2, 3, 7, 8, 12, 13, 17]

	for sec in md["sectorsParsed"]:
		if not light_sector_types.has(sec["type"]):
			continue
		var sec_idx : int = sec["index"]
		var sector_node = geom_node.get_node_or_null("sector " + str(sec_idx))
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

	print("Spawned ", _flicker_sectors.size(), " sector flicker lights")

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
	if not map_data.has("thingsParsed"):
		return

	var spawn_pos = Vector3.ZERO
	for thing in map_data["thingsParsed"]:
		if thing["type"] == 1:
			spawn_pos = thing["pos"]
			var floor_info = loader.thingParser.getFloorHeightAtPoint(spawn_pos)
			if spawn_pos.y == -INF and floor_info.has("height"):
				spawn_pos.y = floor_info["height"]
			break

	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn_pos + Vector3(0, 1.5, 0)
	print("Positioned player at ", spawn_pos)

func _spawnInteractablesFromWad() -> void:
	# Find the level/map node to access sector polygon data
	var level_nodes = get_tree().get_nodes_in_group("level")
	# Filter out old level nodes queued for deletion during map transitions
	level_nodes = level_nodes.filter(func(n): return not n.is_queued_for_deletion())
	print("[Interactables] level nodes found: ", level_nodes.size())
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[-1]

	var has_poly_data = map_node.has_meta("sectorPolyArr")
	print("[Interactables] has sectorPolyArr: ", has_poly_data)
	var sector_poly_arr: Array = map_node.get_meta("sectorPolyArr") if has_poly_data else []

	# Get parsed sector data for floor heights (used as fallback for nodes without sectorInfo)
	var sectors_parsed: Array = []
	var loader = Game.wadLoader._loader
	var mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if loader.maps.has(mn) and loader.maps[mn].has("sectorsParsed"):
		sectors_parsed = loader.maps[mn]["sectorsParsed"]

	# Gather interactable candidates from levelObject group AND sector children with activate
	var all_level_objects : Array[Node] = []
	for obj in get_tree().get_nodes_in_group("levelObject"):
		if not obj.is_queued_for_deletion():
			all_level_objects.append(obj)
	# Also scan Interactables parent for nodes with activate not in the group (e.g. levelChange/exit)
	var interactables_node = map_node.get_node_or_null("Interactables")
	if interactables_node:
		for sector_node in interactables_node.get_children():
			for child in sector_node.get_children():
				if child.has_method("activate") and not child.is_in_group("levelObject"):
					all_level_objects.append(child)
	print("[Interactables] total candidate nodes: ", all_level_objects.size())

	var interactable_count = 0
	var skipped_no_activate = 0
	var skipped_no_ttype = 0
	var skipped_wrong_ttype = 0
	var skipped_no_pos = 0
	for node in all_level_objects:
		var is_lift = node.get_script() != null and node.get_script().resource_path.ends_with("lift.gd")
		if not node.has_method("activate") and not is_lift:
			skipped_no_activate += 1
			continue
		if not node is Node3D:
			continue
		var ttype = node.get("triggerType")
		if ttype == null:
			skipped_no_ttype += 1
			continue
		var valid_ttypes = [WADG.TTYPE.DOOR, WADG.TTYPE.DOOR1, WADG.TTYPE.SWITCH1, WADG.TTYPE.SWITCHR, WADG.TTYPE.WALK1, WADG.TTYPE.WALKR]
		# Also include walk-over triggers if they require a key
		var nodeKeyType = node.get("keyType")
		var isKeyDoor = nodeKeyType != null and nodeKeyType < 4
		if ttype not in valid_ttypes:
			skipped_wrong_ttype += 1
			print("[Interactables] skipped node ", node.name, " ttype=", ttype, " keyType=", nodeKeyType)
			continue

		# Calculate world position from sector polygon centroid
		var world_pos = _getInteractablePosition(node, sector_poly_arr, sectors_parsed)
		if world_pos == null:
			skipped_no_pos += 1
			print("[Interactables] skipped node ", node.name, " - no position (parent: ", node.get_parent().name, ")")
			continue

		# For switch-type triggers, position at the switch linedef instead of the target sector
		if ttype == WADG.TTYPE.SWITCH1 or ttype == WADG.TTYPE.SWITCHR:
			var switch_pos = _getSwitchPosition(node, world_pos.y)
			if switch_pos != null:
				world_pos = switch_pos

		var interactable = INTERACTABLE_SCENE.instantiate()
		interactable.wadNode = node
		# Check if door requires a key (KEY enum: RED=0, GREEN=1, BLUE=2, YELLOW=3, 9=none)
		var keyType = node.get("keyType")
		if keyType != null and keyType < 4:
			match keyType:
				0: interactable.requiredKey = "red_keycard"
				2: interactable.requiredKey = "blue_keycard"
				3: interactable.requiredKey = "yellow_keycard"
			print("[Interactables] key door: keyType=", keyType, " requiredKey=", interactable.requiredKey)
			# Use door mesh XZ position but keep floor height for Y
			var door_pos = _getDoorMeshPosition(node)
			if door_pos != null:
				world_pos.x = door_pos.x
				world_pos.z = door_pos.z
				print("[Interactables] key door mesh position: ", world_pos)
		add_child(interactable)
		interactable.global_position = world_pos
		interactable_count += 1
		print("[Interactables] spawned at ", world_pos, " for ", node.name, " ttype=", ttype)

	print("[Interactables] Summary: spawned=", interactable_count, " no_activate=", skipped_no_activate, " no_ttype=", skipped_no_ttype, " wrong_ttype=", skipped_wrong_ttype, " no_pos=", skipped_no_pos)

	# Spawn interactables for secret sectors that don't already have a door/switch
	var spawned_sectors : Array[int] = []
	for node in all_level_objects:
		if node.has_method("activate"):
			var parent_name = node.get_parent().name as String
			if parent_name.begins_with("Sector "):
				spawned_sectors.append(parent_name.substr(7).to_int())

	mn = loader.mapName
	if not loader.maps.has(mn):
		mn = mn.to_upper()
	if loader.maps.has(mn):
		var md = loader.maps[mn]
		# Build set of sectors already targeted by sectorToInteraction
		var targeted_sectors : Array[int] = []
		if md.has("sectorToInteraction"):
			for sec_key in md["sectorToInteraction"]:
				targeted_sectors.append(sec_key)
		if md.has("sectorsParsed"):
			for sec in md["sectorsParsed"]:
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
				var y : float = sec.get("floorHeight", 0.0)
				var world_pos = Vector3(centroid.x, y, centroid.y)

				# Find the door node for this sector if it exists in the Interactables tree
				var door_node : Node3D = null
				if interactables_node:
					var sector_parent = interactables_node.get_node_or_null("Sector " + str(sec_idx))
					if sector_parent:
						for child in sector_parent.get_children():
							if child.has_method("activate"):
								door_node = child
								break

				# If no door node exists, look for an adjacent door sector
				if door_node == null:
					var geom_node = map_node.get_node_or_null("Geometry")
					if geom_node:
						var sec_node = geom_node.get_node_or_null("sector " + str(sec_idx))
						if sec_node:
							# Use sector geometry position as fallback
							pass

				var interactable = INTERACTABLE_SCENE.instantiate()
				interactable.wadNode = door_node
				add_child(interactable)
				interactable.global_position = world_pos
				interactable_count += 1
				print("[Interactables] spawned SECRET at ", world_pos, " for sector ", sec_idx, " (has wadNode: ", door_node != null, ")")

func _getInteractablePosition(node: Node3D, sector_poly_arr: Array, sectors_parsed: Array = []) -> Variant:
	# Parse sector index from parent node name (e.g. "Sector 42")
	var parent_name = node.get_parent().name as String
	if not parent_name.begins_with("Sector "):
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
	var sector_info = node.get("sectorInfo")
	var y = 0.0
	if sector_info != null and sector_info.has("floorHeight"):
		y = sector_info["floorHeight"]
	elif sec_index < sectors_parsed.size():
		y = sectors_parsed[sec_index].get("floorHeight", 0.0)

	return Vector3(centroid.x, y, centroid.y)

func _getSwitchPosition(node: Node3D, fallback_y: float) -> Variant:
	# Find the trigger linedef position from passer child nodes
	for child in node.get_children():
		if child.has_meta("lineStart") and child.has_meta("lineEnd"):
			var line_start: Vector2 = child.get_meta("lineStart")
			var line_end: Vector2 = child.get_meta("lineEnd")
			var mid = (line_start + line_end) / 2.0
			# Get map scale to convert to world coords
			var level_nodes = get_tree().get_nodes_in_group("level")
			if level_nodes.is_empty():
				return null
			var map_node = level_nodes[0]
			var map_scale = map_node.scale
			var world_x = mid.x * map_scale.x
			var world_z = mid.y * map_scale.z
			# Look up floor height at the switch location, not the target sector
			var y = fallback_y
			var info = WADG.getSectorInfoForPoint(map_node, Vector2(world_x, world_z))
			if info != null and info.has("floorHeight"):
				y = info["floorHeight"]
			return Vector3(world_x, y, world_z)
	return null

func _getDoorMeshPosition(door_node: Node3D) -> Variant:
	# Try to find the door's visual position from its target mesh nodes
	var targets = door_node.get("targets")
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
			total_pos += target_node.global_position
			count += 1
	if count == 0:
		return null
	return total_pos / count

func _registerEntitySectorRider(entity: Node3D, pos: Vector3) -> void:
	var loader = Game.wadLoader._loader
	var floor_info = loader.thingParser.getFloorHeightAtPoint(pos)
	if not floor_info.has("sector") or floor_info["sector"] == null:
		return
	var sector_idx = floor_info["sector"]
	var level_nodes = get_tree().get_nodes_in_group("level")
	if level_nodes.is_empty():
		return
	var map_node = level_nodes[0]
	# curH is set on interactable parent nodes under Interactables/Sector XX (capital S)
	var interact_node = map_node.get_node_or_null("Interactables/Sector " + str(sector_idx))
	if interact_node == null or not interact_node.has_meta("curH"):
		return
	var cur_h = interact_node.get_meta("curH")
	_entity_sector_riders.append({"node": entity, "sector_node": interact_node, "last_h": cur_h})

func _physics_process(delta: float) -> void:
	var i = _entity_sector_riders.size() - 1
	while i >= 0:
		var entry = _entity_sector_riders[i]
		if not is_instance_valid(entry["node"]) or not is_instance_valid(entry["sector_node"]):
			_entity_sector_riders.remove_at(i)
			i -= 1
			continue
		var cur_h = entry["sector_node"].get_meta("curH")
		var diff = cur_h - entry["last_h"]
		if abs(diff) > 0.001:
			entry["node"].global_position.y += diff
			entry["last_h"] = cur_h
		i -= 1
