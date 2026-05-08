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

const OPTIONS_ITEMS = ["MASTER VOLUME", "MUSIC VOLUME", "SFX VOLUME", "HEAD BOB", "WEAPON SWAY", "FULLSCREEN", "VSYNC", "DEBUG", "BACK"]
const DEBUG_ITEMS = ["SHOW THING IDS", "TRACKING", "RETICLE", "SHOW STATIONS", "SHOW RAILS", "SKIP ENCOUNTERS", "SKIP DOORS", "SUPERSPEED", "WASD MOVEMENT", "BACK"]

const COLOR_TITLE := Color(1.0, 0.8, 0.2)
const COLOR_ITEM := Color(1.0, 0.2, 0.2)
const COLOR_SELECTED := Color(1.0, 1.0, 1.0)
const SCALE_TARGET_FRAC_Y := 0.85
const SCALE_TARGET_FRAC_X := 0.90
const SCALE_MIN := 0.5
const SCALE_MAX := 12.0

var _menu_state : MenuState = MenuState.MAIN
var _menu_selection : int = 0
var _level_selection : int = 0
var _slot_selection : int = 0
var _options_selection : int = 0
var _debug_selection : int = 0

var _root : Control = null
var _scaler : Control = null
var _doom_font : Font = null

# Per-state panel containers
var _panels : Dictionary = {}
# Per-state Array[HBoxContainer] of selectable item rows (excludes title rows)
var _items_by_state : Dictionary = {}
# All Label nodes (including titles) for font-reapply when DOOM font loads late
var _all_labels : Array[Label] = []
# All skull TextureRects, kept in a list for animation
var _all_skulls : Array[TextureRect] = []

var _skull_textures : Array[Texture2D] = []
var _skull_frame : int = 0
var _skull_timer : float = 0.0

# Save name editing
var _editing_save_name : bool = false
var _edit_save_name : String = ""
var _cursor_visible : bool = true
var _cursor_timer : float = 0.0
var _slot_data : Array[Dictionary] = []

func _ready() -> void:
	layer = 10
	_buildUI()
	get_viewport().size_changed.connect(_recomputeScale)

# ── Build ────────────────────────────────────────────────────────────────

func _buildUI() -> void:
	_menu_state = MenuState.MAIN
	_menu_selection = 0
	_level_selection = 0
	_slot_selection = 0
	_options_selection = 0
	_debug_selection = 0

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	if not pause_mode:
		var bg := TextureRect.new()
		bg.texture = Game.fetchSprite("TITLEPIC")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(overlay)

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

	# Scaler holds all panels. We size/position/scale it dynamically.
	_scaler = Control.new()
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scaler)

	_all_labels.clear()
	_all_skulls.clear()
	_panels.clear()
	_items_by_state.clear()

	var main_items : Array = MENU_ITEMS_PAUSE if pause_mode else MENU_ITEMS_MAIN
	_panels[MenuState.MAIN] = _buildSimplePanel(main_items, "")
	_panels[MenuState.LEVEL_SELECT] = _buildSimplePanel(_levelLines(), "LEVEL SELECT")
	_panels[MenuState.SAVE_GAME] = _buildSlotPanel("SAVE GAME")
	_panels[MenuState.LOAD_GAME] = _buildSlotPanel("LOAD GAME")
	_panels[MenuState.OPTIONS] = _buildOptionsPanel()
	_panels[MenuState.DEBUG] = _buildDebugPanel()

	for ms in _panels.keys():
		var p : Control = _panels[ms]
		p.visible = (ms == MenuState.MAIN)
		_scaler.add_child(p)

	_registerRows()
	_refreshOptionsLabels()
	_refreshDebugLabels()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_updateMenuHighlight()
	_recomputeScale.call_deferred()

func _levelLines() -> Array[String]:
	var out : Array[String] = []
	for map_name in MAP_NAMES:
		var desc = MAP_DESCRIPTIONS.get(map_name, "")
		out.append(map_name + " - " + desc)
	return out

# Generic panel: optional title, list of selectable item strings.
func _buildSimplePanel(items: Array, title: String) -> VBoxContainer:
	var panel := _makePanel()
	var rows : Array[HBoxContainer] = []
	if title != "":
		panel.add_child(_makeTitleRow(title))
		panel.add_child(_makeSpacer(8))
	for s in items:
		var r := _makeItemRow(String(s))
		panel.add_child(r)
		rows.append(r)
	panel.set_meta("rows", rows)
	return panel

func _buildSlotPanel(title: String) -> VBoxContainer:
	var panel := _makePanel()
	panel.add_child(_makeTitleRow(title))
	panel.add_child(_makeSpacer(8))
	var rows : Array[HBoxContainer] = []
	for i in SaveManager.MAX_SLOTS:
		var r := _makeItemRow("%d. EMPTY" % (i + 1))
		panel.add_child(r)
		rows.append(r)
	panel.set_meta("rows", rows)
	return panel

func _buildOptionsPanel() -> VBoxContainer:
	var panel := _makePanel()
	panel.add_child(_makeTitleRow("OPTIONS"))
	panel.add_child(_makeSpacer(8))
	var rows : Array[HBoxContainer] = []
	for opt_name in OPTIONS_ITEMS:
		var r := _makeItemRow(opt_name)
		panel.add_child(r)
		rows.append(r)
	panel.set_meta("rows", rows)
	return panel

func _buildDebugPanel() -> VBoxContainer:
	var panel := _makePanel()
	panel.add_child(_makeTitleRow("DEBUG"))
	panel.add_child(_makeSpacer(8))
	var rows : Array[HBoxContainer] = []
	for opt_name in DEBUG_ITEMS:
		var r := _makeItemRow(opt_name)
		panel.add_child(r)
		rows.append(r)
	panel.set_meta("rows", rows)
	return panel

func _makePanel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _makeSpacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _makeTitleRow(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _makeLabel(text, COLOR_TITLE)
	row.add_child(label)
	row.set_meta("label", label)
	return row

func _makeItemRow(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var skull := TextureRect.new()
	skull.custom_minimum_size = Vector2(16, 16)
	skull.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull.modulate.a = 0.0
	if _skull_textures.size() > 0:
		skull.texture = _skull_textures[0]
	row.add_child(skull)
	_all_skulls.append(skull)

	var label := _makeLabel(text, COLOR_ITEM)
	row.add_child(label)

	row.set_meta("label", label)
	row.set_meta("skull", skull)
	return row

func _makeLabel(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _doom_font != null:
		label.add_theme_font_override("font", _doom_font)
	_all_labels.append(label)
	return label

# After _buildUI registers panels, the rows for each state need to be
# associated correctly. Override the placeholder mapping done by
# _buildSimplePanel by walking _panels and grabbing the meta.
func _registerRows() -> void:
	_items_by_state.clear()
	for ms in _panels.keys():
		var panel : Control = _panels[ms]
		if panel == null or not panel.has_meta("rows"):
			_items_by_state[ms] = []
			continue
		_items_by_state[ms] = panel.get_meta("rows")

# ── Layout / Scaling ────────────────────────────────────────────────────

func _recomputeScale() -> void:
	if _scaler == null:
		return
	var visible_panel : Control = _panels.get(_menu_state)
	if visible_panel == null:
		return
	var content_min : Vector2 = visible_panel.get_combined_minimum_size()
	if content_min.y <= 0.0 or content_min.x <= 0.0:
		# Layout not settled yet — retry next frame.
		call_deferred("_recomputeScale")
		return
	var vp : Vector2 = get_viewport().get_visible_rect().size
	var s_h : float = (vp.y * SCALE_TARGET_FRAC_Y) / content_min.y
	var s_w : float = (vp.x * SCALE_TARGET_FRAC_X) / content_min.x
	var s : float = clampf(min(s_h, s_w), SCALE_MIN, SCALE_MAX)
	_scaler.size = content_min
	_scaler.pivot_offset = Vector2.ZERO
	_scaler.scale = Vector2(s, s)
	_scaler.position = (vp - content_min * s) * 0.5

# ── Highlight / Selection ───────────────────────────────────────────────

func _getActiveRows() -> Array:
	return _items_by_state.get(_menu_state, [])

func _getActiveSelection() -> int:
	match _menu_state:
		MenuState.MAIN: return _menu_selection
		MenuState.LEVEL_SELECT: return _level_selection
		MenuState.SAVE_GAME, MenuState.LOAD_GAME: return _slot_selection
		MenuState.OPTIONS: return _options_selection
		MenuState.DEBUG: return _debug_selection
	return 0

func _updateMenuHighlight() -> void:
	var rows : Array = _getActiveRows()
	var sel : int = _getActiveSelection()
	for i in rows.size():
		var row : Node = rows[i]
		var label : Label = row.get_meta("label") if row.has_meta("label") else null
		var skull : TextureRect = row.get_meta("skull") if row.has_meta("skull") else null
		if label != null:
			if i == sel:
				label.add_theme_color_override("font_color", COLOR_SELECTED)
			else:
				label.add_theme_color_override("font_color", COLOR_ITEM)
		if skull != null:
			skull.modulate.a = 1.0 if i == sel else 0.0

# ── Submenu switching ───────────────────────────────────────────────────

func _showSubmenu(state: MenuState) -> void:
	for ms in _panels.keys():
		var p : Control = _panels[ms]
		if p != null:
			p.visible = (ms == state)
	_menu_state = state
	match state:
		MenuState.SAVE_GAME:
			_slot_selection = 0
			_refreshSlotLabels()
		MenuState.LOAD_GAME:
			_slot_selection = 0
			_refreshSlotLabels()
		MenuState.OPTIONS:
			_options_selection = 0
			_refreshOptionsLabels()
		MenuState.DEBUG:
			_debug_selection = 0
			_refreshDebugLabels()
	_updateMenuHighlight()
	_recomputeScale.call_deferred()

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

# ── Slot rows ───────────────────────────────────────────────────────────

func _refreshSlotLabels() -> void:
	_slot_data = SaveManager.get_all_slots()
	var rows : Array = _items_by_state.get(_menu_state, [])
	for i in rows.size():
		var label : Label = rows[i].get_meta("label")
		if label != null:
			label.text = _getSlotDisplayText(i)

func _getSlotDisplayText(slot: int) -> String:
	var data = _slot_data[slot] if slot < _slot_data.size() else {}
	if data.is_empty():
		return "%d. EMPTY" % (slot + 1)
	var name_str : String = data.get("name", "UNNAMED")
	var map_str : String = data.get("map_name", "")
	if map_str != "":
		return "%d. %s  %s" % [slot + 1, name_str, map_str]
	return "%d. %s" % [slot + 1, name_str]

# ── Options rows ────────────────────────────────────────────────────────

func _refreshOptionsLabels() -> void:
	var rows : Array = _items_by_state.get(MenuState.OPTIONS, [])
	var target_width : float = _computeOptionsTargetWidth()
	for i in OPTIONS_ITEMS.size():
		if i >= rows.size():
			break
		var label : Label = rows[i].get_meta("label")
		if label != null:
			label.text = _getOptionText(OPTIONS_ITEMS[i], target_width)

func _computeOptionsTargetWidth() -> float:
	var max_w : float = 0.0
	if _doom_font != null:
		for opt_name in OPTIONS_ITEMS:
			if opt_name == "BACK":
				continue
			var w = _doom_font.get_string_size(opt_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			max_w = maxf(max_w, w)
	return max_w * 1.3

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
		"DEBUG":
			return "DEBUG"
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
	_refreshOptionsLabels()
	_updateMenuHighlight()

# ── Debug rows ──────────────────────────────────────────────────────────

func _refreshDebugLabels() -> void:
	var rows : Array = _items_by_state.get(MenuState.DEBUG, [])
	for i in DEBUG_ITEMS.size():
		if i >= rows.size():
			break
		var label : Label = rows[i].get_meta("label")
		if label != null:
			label.text = _getDebugOptionText(DEBUG_ITEMS[i])

func _getDebugOptionText(opt_name: String) -> String:
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
		"SKIP DOORS":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_skip_doors else "OFF")
		"SUPERSPEED":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_superspeed else "OFF")
		"WASD MOVEMENT":
			return opt_name + "  < %s >" % ("ON" if SettingsManager.debug_wasd else "OFF")
		"BACK":
			return "BACK"
	return opt_name

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
		"SKIP DOORS":
			SettingsManager.debug_skip_doors = !SettingsManager.debug_skip_doors
		"SUPERSPEED":
			SettingsManager.debug_superspeed = !SettingsManager.debug_superspeed
		"WASD MOVEMENT":
			SettingsManager.debug_wasd = !SettingsManager.debug_wasd
	_refreshDebugLabels()
	_updateMenuHighlight()

# ── Input ───────────────────────────────────────────────────────────────

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
		_editing_save_name = false
		Game.playSound("DSPISTOL")
		save_requested.emit(_slot_selection, _edit_save_name)
		_refreshSlotLabels()
		_updateMenuHighlight()
		return

	if event.keycode == KEY_ESCAPE or event.is_action("ui_cancel"):
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

	var char_str := event.as_text_key_label()
	if char_str.length() == 1 and _edit_save_name.length() < MAX_SAVE_NAME_LENGTH:
		_edit_save_name += char_str.to_upper()
		_updateEditLabel()

func _updateEditLabel() -> void:
	var rows : Array = _items_by_state.get(MenuState.SAVE_GAME, [])
	if _slot_selection >= rows.size():
		return
	var label : Label = rows[_slot_selection].get_meta("label")
	if label != null:
		var cursor_char = "_" if _cursor_visible else " "
		label.text = "%d. %s%s" % [_slot_selection + 1, _edit_save_name, cursor_char]

# ── Load ─────────────────────────────────────────────────────────────────

func _confirmLoad() -> void:
	var data = _slot_data[_slot_selection] if _slot_selection < _slot_data.size() else {}
	if data.is_empty():
		Game.playSound("DSOOF")
		return
	save_loaded.emit(data)

# ── Per-frame ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Late-arriving DOOM font: re-apply once available.
	if _doom_font == null:
		var f = Game.getDoomFont()
		if f == null:
			f = Game.fetchFont("default")
		if f != null:
			_doom_font = f
			for label in _all_labels:
				if is_instance_valid(label):
					label.add_theme_font_override("font", _doom_font)
			# Refresh formatted texts that depend on font metrics.
			_refreshOptionsLabels()
			_refreshDebugLabels()
			_recomputeScale.call_deferred()

	# Skull animation (drives every row's skull texture; only the selected
	# row is opaque so this is essentially free).
	if _skull_textures.size() >= 2:
		_skull_timer += delta
		if _skull_timer >= 0.5:
			_skull_timer = 0.0
			_skull_frame = (_skull_frame + 1) % _skull_textures.size()
			for skull in _all_skulls:
				if is_instance_valid(skull):
					skull.texture = _skull_textures[_skull_frame]

	# Save name cursor blink
	if _editing_save_name:
		_cursor_timer += delta
		if _cursor_timer >= 0.35:
			_cursor_timer = 0.0
			_cursor_visible = not _cursor_visible
			_updateEditLabel()
