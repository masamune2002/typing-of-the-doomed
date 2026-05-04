extends CanvasLayer
class_name GameMenu

signal game_started(map_idx: int)
signal resumed
signal save_loaded(save_data: Dictionary)
signal save_requested(slot: int, save_name: String)

var pause_mode : bool = false

enum MenuState { MAIN, LEVEL_SELECT, SAVE_GAME, LOAD_GAME, OPTIONS, DEBUG }

const MENU_ITEMS_MAIN = ["NEW GAME", "LOAD GAME", "LEVEL SELECT", "OPTIONS", "QUIT GAME"]
const MENU_ITEMS_PAUSE = ["RESUME GAME", "SAVE GAME", "LOAD GAME", "LEVEL SELECT", "OPTIONS", "QUIT GAME"]
const MAP_NAMES = ["E1M1", "E1M2", "E1M3", "E1M4", "E1M5", "E1M6", "E1M7", "E1M8", "E1M9"]
const MAP_DESCRIPTIONS = {
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
const MAX_SAVE_NAME_LENGTH = 24

var _menu_state : MenuState = MenuState.MAIN
var _menu_selection : int = 0
var _level_selection : int = 0
var _slot_selection : int = 0
var _skull_textures : Array[Texture2D] = []
var _skull_frame : int = 0
var _skull_timer : float = 0.0
var _skull_node : TextureRect = null
var _main_menu_items : Array[Control] = []
var _level_menu_items : Array[Control] = []
var _slot_menu_items : Array[Control] = []
var _main_menu_vbox : VBoxContainer = null
var _main_menu_center : Control = null
var _level_select_vbox : VBoxContainer = null
var _level_select_center : Control = null
var _slot_vbox : VBoxContainer = null
var _slot_center : Control = null
var _options_vbox : VBoxContainer = null
var _options_center : Control = null
var _options_items : Array[Control] = []
var _options_selection : int = 0
var _options_value_labels : Array[Label] = []
var _debug_vbox : VBoxContainer = null
var _debug_center : Control = null
var _debug_items : Array[Control] = []
var _debug_selection : int = 0
var _debug_value_labels : Array[Label] = []
var _root : Control = null
var _doom_font : Font = null

const OPTIONS_ITEMS = ["MASTER VOLUME", "MUSIC VOLUME", "SFX VOLUME", "HEAD BOB", "WEAPON SWAY", "FULLSCREEN", "VSYNC", "DEBUG", "BACK"]
const DEBUG_ITEMS = ["SHOW THING IDS", "TRACKING", "RETICLE", "SHOW STATIONS", "SHOW RAILS", "SKIP ENCOUNTERS", "WASD MOVEMENT", "BACK"]

# Save name editing
var _editing_save_name : bool = false
var _edit_save_name : String = ""
var _cursor_visible : bool = true
var _cursor_timer : float = 0.0
var _slot_data : Array[Dictionary] = []

func _ready() -> void:
	layer = 10
	_buildUI()

func _buildUI() -> void:
	_menu_state = MenuState.MAIN
	_menu_selection = 0
	_level_selection = 0
	_slot_selection = 0

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var root := _root

	if not pause_mode:
		var bg := TextureRect.new()
		bg.texture = Game.fetchSprite("TITLEPIC")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

	_doom_font = Game.getDoomFont()
	if _doom_font == null:
		_doom_font = Game.fetchFont("default")

	_skull_textures.clear()
	var s1 = Game.fetchSprite("M_SKULL1")
	var s2 = Game.fetchSprite("M_SKULL2")
	if s1 != null:
		_skull_textures.append(s1)
	if s2 != null:
		_skull_textures.append(s2)

	_skull_node = TextureRect.new()
	if _skull_textures.size() > 0:
		_skull_node.texture = _skull_textures[0]
	_skull_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skull_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_skull_node.custom_minimum_size = Vector2(160, 160)
	root.add_child(_skull_node)

	# Main menu
	_main_menu_center = _createCenteredVBoxContainer(8)
	root.add_child(_main_menu_center)
	_main_menu_vbox = _main_menu_center.get_meta("vbox")

	_main_menu_items.clear()
	var menu_items = MENU_ITEMS_PAUSE if pause_mode else MENU_ITEMS_MAIN
	for text in menu_items:
		var item := _createScaledLabel(text, _doom_font, 8.0, Color(1.0, 0.2, 0.2))
		_main_menu_vbox.add_child(item)
		_main_menu_items.append(item)

	# Level select submenu
	_level_select_center = _createCenteredVBoxContainer(8, 0.22)
	_level_select_center.visible = false
	root.add_child(_level_select_center)
	_level_select_vbox = _level_select_center.get_meta("vbox")

	var level_title := _createScaledLabel("LEVEL SELECT", _doom_font, 6.0, Color(1.0, 0.8, 0.2))
	_level_select_vbox.add_child(level_title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_level_select_vbox.add_child(spacer)

	_level_menu_items.clear()
	for i in MAP_NAMES.size():
		var map_name = MAP_NAMES[i]
		var desc = MAP_DESCRIPTIONS.get(map_name, "")
		var item := _createScaledLabel(map_name + " - " + desc, _doom_font, 5.0, Color(1.0, 0.2, 0.2))
		_level_select_vbox.add_child(item)
		_level_menu_items.append(item)

	# Save/Load slot submenu
	_slot_center = _createCenteredVBoxContainer(4)
	_slot_center.visible = false
	root.add_child(_slot_center)
	_slot_vbox = _slot_center.get_meta("vbox")

	# Options submenu
	_options_center = _createCenteredVBoxContainer(8, 0.22)
	_options_center.visible = false
	root.add_child(_options_center)
	_options_vbox = _options_center.get_meta("vbox")
	_buildOptionsItems()

	# Debug submenu
	_debug_center = _createCenteredVBoxContainer(8, 0.22)
	_debug_center.visible = false
	root.add_child(_debug_center)
	_debug_vbox = _debug_center.get_meta("vbox")
	_buildDebugItems()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_updateMenuHighlight()

func _buildSlotItems(title_text: String) -> void:
	# Clear old slot items
	for child in _slot_vbox.get_children():
		child.queue_free()
	_slot_menu_items.clear()

	var title := _createScaledLabel(title_text, _doom_font, 6.0, Color(1.0, 0.8, 0.2))
	_slot_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_slot_vbox.add_child(spacer)

	_slot_data = SaveManager.get_all_slots()
	for i in SaveManager.MAX_SLOTS:
		var slot_text := _getSlotDisplayText(i)
		var item := _createScaledLabel(slot_text, _doom_font, 5.5, Color(1.0, 0.2, 0.2))
		_slot_vbox.add_child(item)
		_slot_menu_items.append(item)

func _getSlotDisplayText(slot: int) -> String:
	var data = _slot_data[slot] if slot < _slot_data.size() else {}
	if data.is_empty():
		return "%d. EMPTY" % (slot + 1)
	var name_str : String = data.get("name", "UNNAMED")
	var map_str : String = data.get("map_name", "")
	if map_str != "":
		return "%d. %s  %s" % [slot + 1, name_str, map_str]
	return "%d. %s" % [slot + 1, name_str]

func _buildOptionsItems() -> void:
	for child in _options_vbox.get_children():
		child.queue_free()
	_options_items.clear()
	_options_value_labels.clear()

	var title := _createScaledLabel("OPTIONS", _doom_font, 6.0, Color(1.0, 0.8, 0.2))
	_options_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_options_vbox.add_child(spacer)

	# Find widest option name in pixels and add some padding
	var max_name_width := 0.0
	if _doom_font != null:
		for opt_name in OPTIONS_ITEMS:
			if opt_name == "BACK":
				continue
			var w = _doom_font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			max_name_width = maxf(max_name_width, w)
	var target_width = max_name_width * 1.3

	for i in OPTIONS_ITEMS.size():
		var opt_name = OPTIONS_ITEMS[i]
		var full_text = _getOptionText(opt_name, target_width)
		var item := _createScaledLabel(full_text, _doom_font, 5.0, Color(1.0, 0.2, 0.2))
		_options_vbox.add_child(item)
		_options_items.append(item)
		var label := _getLabel(item)
		_options_value_labels.append(label)

func _getOptionText(opt_name: String, target_width: float) -> String:
	var value_str := ""
	match opt_name:
		"MASTER VOLUME":
			value_str = "< %d%% >" % int(SettingsManager.master_volume * 100)
		"MUSIC VOLUME":
			value_str = "< %d%% >" % int(SettingsManager.music_volume * 100)
		"SFX VOLUME":
			value_str = "< %d%% >" % int(SettingsManager.sfx_volume * 100)
		"HEAD BOB":
			value_str = "< %d%% >" % int(SettingsManager.head_bob * 100)
		"WEAPON SWAY":
			value_str = "< %d%% >" % int(SettingsManager.weapon_sway * 100)
		"FULLSCREEN":
			value_str = "< %s >" % ("ON" if SettingsManager.fullscreen else "OFF")
		"VSYNC":
			value_str = "< %s >" % ("ON" if SettingsManager.vsync else "OFF")
		"BACK":
			return "BACK"
	if _doom_font == null:
		return opt_name + "  " + value_str
	var name_width = _doom_font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var dot_width = _doom_font.get_string_size(".", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var dots = ""
	var current_width = name_width
	while current_width + dot_width < target_width:
		dots += "."
		current_width += dot_width
	return opt_name + dots + " " + value_str

func _updateOptionsValues() -> void:
	_buildOptionsItems()
	_updateMenuHighlight()

func _adjustOption(direction: int) -> void:
	var opt_name = OPTIONS_ITEMS[_options_selection]
	match opt_name:
		"MASTER VOLUME":
			SettingsManager.set_master_volume(SettingsManager.master_volume + direction * 0.05)
		"MUSIC VOLUME":
			SettingsManager.set_music_volume(SettingsManager.music_volume + direction * 0.05)
		"SFX VOLUME":
			SettingsManager.set_sfx_volume(SettingsManager.sfx_volume + direction * 0.05)
		"HEAD BOB":
			SettingsManager.set_head_bob(SettingsManager.head_bob + direction * 0.05)
		"WEAPON SWAY":
			SettingsManager.set_weapon_sway(SettingsManager.weapon_sway + direction * 0.05)
		"FULLSCREEN":
			SettingsManager.set_fullscreen(!SettingsManager.fullscreen)
		"VSYNC":
			SettingsManager.set_vsync(!SettingsManager.vsync)
	_updateOptionsValues()

func _buildDebugItems() -> void:
	for child in _debug_vbox.get_children():
		child.queue_free()
	_debug_items.clear()
	_debug_value_labels.clear()

	var title := _createScaledLabel("DEBUG", _doom_font, 6.0, Color(1.0, 0.8, 0.2))
	_debug_vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_debug_vbox.add_child(spacer)

	var max_name_width := 0.0
	if _doom_font != null:
		for opt_name in DEBUG_ITEMS:
			if opt_name == "BACK":
				continue
			var w = _doom_font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			max_name_width = maxf(max_name_width, w)
	var target_width = max_name_width * 1.3

	for i in DEBUG_ITEMS.size():
		var opt_name = DEBUG_ITEMS[i]
		var full_text = _getDebugOptionText(opt_name, target_width)
		var item := _createScaledLabel(full_text, _doom_font, 5.0, Color(1.0, 0.2, 0.2))
		_debug_vbox.add_child(item)
		_debug_items.append(item)
		var label := _getLabel(item)
		_debug_value_labels.append(label)

func _getDebugOptionText(opt_name: String, _target_width: float) -> String:
	match opt_name:
		"SHOW THING IDS":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_show_thing_ids else "OFF")
		"TRACKING":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_tracking else "OFF")
		"RETICLE":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_reticle else "OFF")
		"SHOW STATIONS":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_show_stations else "OFF")
		"SHOW RAILS":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_show_rails else "OFF")
		"SKIP ENCOUNTERS":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_skip_encounters else "OFF")
		"WASD MOVEMENT":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_wasd else "OFF")
		"BACK":
			return "BACK"
	return opt_name

func _updateDebugValues() -> void:
	_buildDebugItems()
	_updateMenuHighlight()

func _adjustDebugOption(direction: int) -> void:
	var opt_name = DEBUG_ITEMS[_debug_selection]
	match opt_name:
		"SHOW THING IDS":
			SettingsManager.debug_show_thing_ids = !SettingsManager.debug_show_thing_ids
		"TRACKING":
			SettingsManager.debug_tracking = !SettingsManager.debug_tracking
		"RETICLE":
			SettingsManager.debug_reticle = !SettingsManager.debug_reticle
		"SHOW STATIONS":
			SettingsManager.debug_show_stations = !SettingsManager.debug_show_stations
		"SHOW RAILS":
			SettingsManager.debug_show_rails = !SettingsManager.debug_show_rails
		"SKIP ENCOUNTERS":
			SettingsManager.debug_skip_encounters = !SettingsManager.debug_skip_encounters
		"WASD MOVEMENT":
			SettingsManager.debug_wasd = !SettingsManager.debug_wasd
	_updateDebugValues()

func _refreshSlotLabels() -> void:
	_slot_data = SaveManager.get_all_slots()
	for i in _slot_menu_items.size():
		var label := _getLabel(_slot_menu_items[i])
		if label:
			label.text = _getSlotDisplayText(i)

func _createCenteredVBoxContainer(separation: int, anchor_x: float = 0.3) -> Control:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	vbox.anchor_left = anchor_x
	vbox.anchor_right = anchor_x
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.grow_horizontal = Control.GROW_DIRECTION_END
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_child(vbox)
	container.set_meta("vbox", vbox)
	return container

func _createScaledLabel(text: String, font: Font, label_scale: float, color: Color) -> Control:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.scale = Vector2(label_scale, label_scale)
	var unscaled_size = Vector2.ZERO
	if font != null:
		unscaled_size.x = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		unscaled_size.y = font.get_height(16)
	if unscaled_size == Vector2.ZERO:
		unscaled_size = label.get_combined_minimum_size()
	if unscaled_size == Vector2.ZERO:
		unscaled_size = Vector2(text.length() * 10, 16)
	var scaled_height = unscaled_size.y * label_scale
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(0, scaled_height)
	wrapper.add_child(label)
	label.position = Vector2.ZERO
	return wrapper

func _getLabel(wrapper: Control) -> Label:
	if wrapper is Label:
		return wrapper as Label
	for child in wrapper.get_children():
		if child is Label:
			return child as Label
	return null

func _getActiveItems() -> Array[Control]:
	match _menu_state:
		MenuState.MAIN: return _main_menu_items
		MenuState.LEVEL_SELECT: return _level_menu_items
		MenuState.SAVE_GAME, MenuState.LOAD_GAME: return _slot_menu_items
		MenuState.OPTIONS: return _options_items
		MenuState.DEBUG: return _debug_items
	return _main_menu_items

func _getActiveSelection() -> int:
	match _menu_state:
		MenuState.MAIN: return _menu_selection
		MenuState.LEVEL_SELECT: return _level_selection
		MenuState.SAVE_GAME, MenuState.LOAD_GAME: return _slot_selection
		MenuState.OPTIONS: return _options_selection
		MenuState.DEBUG: return _debug_selection
	return 0

func _updateMenuHighlight() -> void:
	var items := _getActiveItems()
	var selection := _getActiveSelection()
	for i in items.size():
		var label := _getLabel(items[i])
		if label == null:
			continue
		if i == selection:
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		else:
			label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _updateSkullPosition() -> void:
	if _skull_node == null:
		return
	var items := _getActiveItems()
	var selection := _getActiveSelection()
	if items.size() == 0 or selection >= items.size():
		return
	var selected = items[selection]
	if !is_instance_valid(selected):
		return
	var item_rect = selected.get_global_rect()
	_skull_node.position = Vector2(
		item_rect.position.x - 220,
		item_rect.position.y + (item_rect.size.y - 160) / 2
	)

func _showSubmenu(state: MenuState) -> void:
	_main_menu_center.visible = false
	_level_select_center.visible = false
	_slot_center.visible = false
	_options_center.visible = false
	_debug_center.visible = false
	_menu_state = state
	match state:
		MenuState.MAIN:
			_main_menu_center.visible = true
		MenuState.LEVEL_SELECT:
			_level_select_center.visible = true
		MenuState.SAVE_GAME:
			_slot_selection = 0
			_buildSlotItems("SAVE GAME")
			_slot_center.visible = true
		MenuState.LOAD_GAME:
			_slot_selection = 0
			_buildSlotItems("LOAD GAME")
			_slot_center.visible = true
		MenuState.OPTIONS:
			_options_selection = 0
			_updateOptionsValues()
			_options_center.visible = true
		MenuState.DEBUG:
			_debug_selection = 0
			_updateDebugValues()
			_debug_center.visible = true
	_updateMenuHighlight()

func _returnToMain() -> void:
	Game.playSound("DSPSTOP")
	_editing_save_name = false
	if _menu_state == MenuState.DEBUG:
		SettingsManager.save_settings()
		_showSubmenu(MenuState.OPTIONS)
		return
	if _menu_state == MenuState.OPTIONS:
		SettingsManager.save_settings()
	_showSubmenu(MenuState.MAIN)

func _input(event: InputEvent) -> void:
	# While editing a save name, intercept all key input
	if _editing_save_name:
		if event is InputEventKey and event.pressed and not event.echo:
			_handleSaveNameInput(event)
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		if _menu_state != MenuState.MAIN:
			_returnToMain()
		elif pause_mode:
			resumed.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_up"):
		_menuUp()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_menuDown()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and _menu_state == MenuState.OPTIONS:
		Game.playSound("DSPSTOP")
		_adjustOption(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") and _menu_state == MenuState.OPTIONS:
		Game.playSound("DSPSTOP")
		_adjustOption(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") and _menu_state == MenuState.DEBUG:
		Game.playSound("DSPSTOP")
		_adjustDebugOption(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") and _menu_state == MenuState.DEBUG:
		Game.playSound("DSPSTOP")
		_adjustDebugOption(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		Game.playSound("DSPISTOL")
		_menuConfirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if _menu_state != MenuState.MAIN:
			_returnToMain()
		elif pause_mode:
			resumed.emit()
		get_viewport().set_input_as_handled()

func _menuUp() -> void:
	Game.playSound("DSPSTOP")
	match _menu_state:
		MenuState.MAIN:
			var items = MENU_ITEMS_PAUSE if pause_mode else MENU_ITEMS_MAIN
			_menu_selection = (_menu_selection - 1 + items.size()) % items.size()
		MenuState.LEVEL_SELECT:
			_level_selection = (_level_selection - 1 + MAP_NAMES.size()) % MAP_NAMES.size()
		MenuState.SAVE_GAME, MenuState.LOAD_GAME:
			_slot_selection = (_slot_selection - 1 + SaveManager.MAX_SLOTS) % SaveManager.MAX_SLOTS
		MenuState.OPTIONS:
			_options_selection = (_options_selection - 1 + OPTIONS_ITEMS.size()) % OPTIONS_ITEMS.size()
		MenuState.DEBUG:
			_debug_selection = (_debug_selection - 1 + DEBUG_ITEMS.size()) % DEBUG_ITEMS.size()
	_updateMenuHighlight()

func _menuDown() -> void:
	Game.playSound("DSPSTOP")
	match _menu_state:
		MenuState.MAIN:
			var items = MENU_ITEMS_PAUSE if pause_mode else MENU_ITEMS_MAIN
			_menu_selection = (_menu_selection + 1) % items.size()
		MenuState.LEVEL_SELECT:
			_level_selection = (_level_selection + 1) % MAP_NAMES.size()
		MenuState.SAVE_GAME, MenuState.LOAD_GAME:
			_slot_selection = (_slot_selection + 1) % SaveManager.MAX_SLOTS
		MenuState.OPTIONS:
			_options_selection = (_options_selection + 1) % OPTIONS_ITEMS.size()
		MenuState.DEBUG:
			_debug_selection = (_debug_selection + 1) % DEBUG_ITEMS.size()
	_updateMenuHighlight()

func _menuConfirm() -> void:
	match _menu_state:
		MenuState.MAIN:
			_mainMenuConfirm()
		MenuState.LEVEL_SELECT:
			game_started.emit(_level_selection)
		MenuState.SAVE_GAME:
			_startSaveNameEdit()
		MenuState.LOAD_GAME:
			_confirmLoad()
		MenuState.OPTIONS:
			_optionsConfirm()
		MenuState.DEBUG:
			_debugConfirm()

func _mainMenuConfirm() -> void:
	if pause_mode:
		# RESUME GAME, SAVE GAME, LOAD GAME, LEVEL SELECT, OPTIONS, QUIT GAME
		match _menu_selection:
			0: resumed.emit()
			1: _showSubmenu(MenuState.SAVE_GAME)
			2: _showSubmenu(MenuState.LOAD_GAME)
			3: _showSubmenu(MenuState.LEVEL_SELECT)
			4: _showSubmenu(MenuState.OPTIONS)
			5: get_tree().quit()
	else:
		# NEW GAME, LOAD GAME, LEVEL SELECT, OPTIONS, QUIT GAME
		match _menu_selection:
			0: game_started.emit(0)
			1: _showSubmenu(MenuState.LOAD_GAME)
			2: _showSubmenu(MenuState.LEVEL_SELECT)
			3: _showSubmenu(MenuState.OPTIONS)
			4: get_tree().quit()

func _optionsConfirm() -> void:
	if OPTIONS_ITEMS[_options_selection] == "BACK":
		_returnToMain()
	elif OPTIONS_ITEMS[_options_selection] == "DEBUG":
		_showSubmenu(MenuState.DEBUG)
	else:
		_adjustOption(1)

func _debugConfirm() -> void:
	if DEBUG_ITEMS[_debug_selection] == "BACK":
		_returnToMain()
	else:
		_adjustDebugOption(1)

# ── Save name editing ────────────────────────────────────────────────────

func _startSaveNameEdit() -> void:
	_editing_save_name = true
	_cursor_visible = true
	_cursor_timer = 0.0
	# Pre-fill with existing name or current map name
	var existing = _slot_data[_slot_selection] if _slot_selection < _slot_data.size() else {}
	if not existing.is_empty():
		_edit_save_name = existing.get("name", "")
	else:
		var main_scene = get_tree().current_scene
		if main_scene and "MAP_NAMES" in main_scene and "_currentMapIdx" in main_scene:
			_edit_save_name = main_scene.MAP_NAMES[main_scene._currentMapIdx]
		else:
			_edit_save_name = ""
	_updateEditLabel()

func _handleSaveNameInput(event: InputEventKey) -> void:
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		# Confirm save
		_editing_save_name = false
		Game.playSound("DSPISTOL")
		save_requested.emit(_slot_selection, _edit_save_name)
		_refreshSlotLabels()
		_updateMenuHighlight()
		return

	if event.keycode == KEY_ESCAPE or event.is_action("ui_cancel"):
		# Cancel editing
		_editing_save_name = false
		Game.playSound("DSPSTOP")
		_refreshSlotLabels()
		_updateMenuHighlight()
		return

	if event.keycode == KEY_BACKSPACE:
		if _edit_save_name.length() > 0:
			_edit_save_name = _edit_save_name.substr(0, _edit_save_name.length() - 1)
			_updateEditLabel()
		return

	# Printable character
	var char_str := event.as_text_key_label()
	if char_str.length() == 1 and _edit_save_name.length() < MAX_SAVE_NAME_LENGTH:
		_edit_save_name += char_str.to_upper()
		_updateEditLabel()

func _updateEditLabel() -> void:
	if _slot_selection >= _slot_menu_items.size():
		return
	var label := _getLabel(_slot_menu_items[_slot_selection])
	if label:
		var cursor_char = "_" if _cursor_visible else " "
		label.text = "%d. %s%s" % [_slot_selection + 1, _edit_save_name, cursor_char]

# ── Load ─────────────────────────────────────────────────────────────────

func _confirmLoad() -> void:
	var data = _slot_data[_slot_selection] if _slot_selection < _slot_data.size() else {}
	if data.is_empty():
		Game.playSound("DSOOF")
		return
	save_loaded.emit(data)

# ── Process ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Skull animation
	if _skull_node != null and _skull_textures.size() >= 2:
		_skull_timer += delta
		if _skull_timer >= 0.5:
			_skull_timer = 0.0
			_skull_frame = (_skull_frame + 1) % _skull_textures.size()
			_skull_node.texture = _skull_textures[_skull_frame]
	_updateSkullPosition()

	# Save name cursor blink
	if _editing_save_name:
		_cursor_timer += delta
		if _cursor_timer >= 0.35:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
			_updateEditLabel()
