extends Control
class_name IntermissionScreen

signal continue_pressed

# DOOM intermission number sprites
var _num_textures : Array[Texture2D] = []
var _minus_texture : Texture2D = null
var _colon_texture : Texture2D = null
var _percent_texture : Texture2D = null

# Intermission state
enum Phase { STATS, NEXT_LEVEL }
var _phase : Phase = Phase.STATS
var _tally_timer : float = 0.0
var _tally_speed : float = 1.0  # percent per tick
var _tally_done : bool = false
var _tally_sound_timer : float = 0.0

var _target_kills : float = 0.0
var _target_items : float = 0.0
var _target_secrets : float = 0.0
var _current_kills : float = 0.0
var _current_items : float = 0.0
var _current_secrets : float = 0.0
var _time_secs : float = 0.0
var _par_secs : float = 0.0

var _finished_map_name : String = ""
var _next_map_name : String = ""
var _episode : int = 0

# UI elements
var _bg : TextureRect
var _finished_label : TextureRect
var _entering_label : TextureRect
var _map_name_label : Control
var _next_map_label : Control
var _kills_header : TextureRect
var _items_header : TextureRect
var _secrets_header : TextureRect
var _time_header : TextureRect
var _kills_value : Control
var _items_value : Control
var _secrets_value : Control
var _time_value : Control
var _doom_font : Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_loadGraphics()

func _loadGraphics() -> void:
	# Number textures
	_num_textures.resize(10)
	for i in 10:
		_num_textures[i] = Game.fetchSprite("WINUM%d" % i)
	_minus_texture = Game.fetchSprite("WIMINUS")
	_colon_texture = Game.fetchSprite("WICOLON")
	_percent_texture = Game.fetchSprite("WIPCNT")
	_doom_font = Game.getDoomFont()

func show_stats(finished_map: String, next_map: String, kills_pct: float, items_pct: float, secrets_pct: float, time_secs: float, episode: int = 0) -> void:
	_finished_map_name = finished_map
	_next_map_name = next_map
	_episode = episode
	_target_kills = kills_pct
	_target_items = items_pct
	_target_secrets = secrets_pct
	_current_kills = 0.0
	_current_items = 0.0
	_current_secrets = 0.0
	_time_secs = time_secs
	_tally_done = false
	_phase = Phase.STATS

	_buildUI()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _buildUI() -> void:
	# Clear old children
	for child in get_children():
		child.queue_free()

	var screen_h := get_viewport().get_visible_rect().size.y
	var screen_w := get_viewport().get_visible_rect().size.x
	# Scale factor: DOOM renders at 320x200, scale everything relative to screen
	var ui_scale := screen_h / 200.0

	# Background — use episode map (WIMAP0 for ep1) if available, fall back to INTERPIC
	_bg = TextureRect.new()
	var bg_tex = Game.fetchSprite("WIMAP%d" % _episode)
	if bg_tex == null:
		bg_tex = Game.fetchSprite("INTERPIC")
	if bg_tex != null:
		_bg.texture = bg_tex
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bg)

	# Overlay container for absolute positioning
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	if _phase == Phase.STATS:
		# "Finished" header — DOOM Y ~2
		_finished_label = _createWadGraphic("WIF", ui_scale)
		if _finished_label != null:
			_finished_label.position = Vector2((screen_w - _finished_label.custom_minimum_size.x) / 2.0, 2 * ui_scale)
			overlay.add_child(_finished_label)

		# Finished map name — DOOM Y ~24
		_map_name_label = _createScaledLabel(_finished_map_name, Color(1.0, 0.2, 0.2), ui_scale)
		_map_name_label.position = Vector2((screen_w - _map_name_label.custom_minimum_size.x) / 2.0, 24 * ui_scale)
		overlay.add_child(_map_name_label)

		# Stats — DOOM positions: kills Y~50, items Y~78, secrets Y~106, time Y~136
		var stat_left := 50.0 * ui_scale
		var val_right := screen_w - 50.0 * ui_scale

		var kills_hdr := _createWadGraphic("WIOSTK", ui_scale)
		if kills_hdr != null:
			kills_hdr.position = Vector2(stat_left, 50 * ui_scale)
			overlay.add_child(kills_hdr)
		_kills_value = _createScaledLabel("0%%", Color.WHITE, ui_scale)
		_kills_value.position = Vector2(val_right - _kills_value.custom_minimum_size.x, 50 * ui_scale)
		overlay.add_child(_kills_value)

		var items_hdr := _createWadGraphic("WIOSTI", ui_scale)
		if items_hdr != null:
			items_hdr.position = Vector2(stat_left, 78 * ui_scale)
			overlay.add_child(items_hdr)
		_items_value = _createScaledLabel("0%%", Color.WHITE, ui_scale)
		_items_value.position = Vector2(val_right - _items_value.custom_minimum_size.x, 78 * ui_scale)
		overlay.add_child(_items_value)

		var secrets_hdr := _createWadGraphic("WISCRT2", ui_scale)
		if secrets_hdr != null:
			secrets_hdr.position = Vector2(stat_left, 106 * ui_scale)
			overlay.add_child(secrets_hdr)
		_secrets_value = _createScaledLabel("0%%", Color.WHITE, ui_scale)
		_secrets_value.position = Vector2(val_right - _secrets_value.custom_minimum_size.x, 106 * ui_scale)
		overlay.add_child(_secrets_value)

		var time_hdr := _createWadGraphic("WITIME", ui_scale)
		if time_hdr != null:
			time_hdr.position = Vector2(stat_left, 136 * ui_scale)
			overlay.add_child(time_hdr)
		_time_value = _createScaledLabel(_formatTime(_time_secs), Color.WHITE, ui_scale)
		_time_value.position = Vector2(val_right - _time_value.custom_minimum_size.x, 136 * ui_scale)
		overlay.add_child(_time_value)

	elif _phase == Phase.NEXT_LEVEL and _next_map_name != "":
		# "Entering" header — DOOM Y ~50
		_entering_label = _createWadGraphic("WIENTER", ui_scale)
		if _entering_label != null:
			_entering_label.position = Vector2((screen_w - _entering_label.custom_minimum_size.x) / 2.0, 50 * ui_scale)
			overlay.add_child(_entering_label)

		# Next map name — DOOM Y ~76
		_next_map_label = _createScaledLabel(_next_map_name, Color(1.0, 0.2, 0.2), ui_scale)
		_next_map_label.position = Vector2((screen_w - _next_map_label.custom_minimum_size.x) / 2.0, 76 * ui_scale)
		overlay.add_child(_next_map_label)

func _createWadGraphic(sprite_name: String, ui_scale: float = 1.0) -> TextureRect:
	var tex = Game.fetchSprite(sprite_name)
	if tex == null:
		return null
	var rect = TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	rect.custom_minimum_size = Vector2(tex.get_width() * ui_scale, tex.get_height() * ui_scale)
	return rect

func _createScaledLabel(text: String, color: Color, ui_scale: float) -> Control:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _doom_font != null:
		label.add_theme_font_override("font", _doom_font)
	# DOOM intermission text is ~7px tall at 200px screen height.
	# The font is 16px at base, so scale = ui_scale * (7/16) ≈ ui_scale * 0.44
	var text_scale := ui_scale * 0.72
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.scale = Vector2(text_scale, text_scale)
	# Wrap in a container with proper minimum size so layout works
	var wrapper = Control.new()
	var text_size = Vector2(text.length() * 10, 16)
	if _doom_font != null:
		text_size = _doom_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	wrapper.custom_minimum_size = text_size * text_scale
	wrapper.add_child(label)
	return wrapper

func _formatTime(secs: float) -> String:
	var minutes = int(secs) / 60
	var seconds = int(secs) % 60
	return "%d:%02d" % [minutes, seconds]

func _process(delta: float) -> void:
	if not visible:
		return

	if _phase == Phase.STATS and not _tally_done:
		_tally_timer += delta
		_tally_sound_timer += delta
		var tick_interval = 1.0 / 15.0  # Slower than DOOM tics for visible counting
		if _tally_timer >= tick_interval:
			_tally_timer = 0.0
			var all_done = true

			if _current_kills < _target_kills:
				_current_kills = minf(_current_kills + _tally_speed, _target_kills)
				all_done = false
			if _current_items < _target_items:
				_current_items = minf(_current_items + _tally_speed, _target_items)
				all_done = false
			if _current_secrets < _target_secrets:
				_current_secrets = minf(_current_secrets + _tally_speed, _target_secrets)
				all_done = false

			_updateStatValues()

			# Play counting sound periodically
			if not all_done and _tally_sound_timer >= 0.12:
				_tally_sound_timer = 0.0
				Game.playSound("DSPISTOL")

			if all_done:
				_tally_done = true
				Game.playSound("DSBAREXP")

func _getInnerLabel(wrapper: Control) -> Label:
	if wrapper is Label:
		return wrapper
	for child in wrapper.get_children():
		if child is Label:
			return child
	return null

func _updateStatValues() -> void:
	var lbl : Label
	lbl = _getInnerLabel(_kills_value)
	if lbl != null:
		lbl.text = "%d%%" % int(_current_kills)
	lbl = _getInnerLabel(_items_value)
	if lbl != null:
		lbl.text = "%d%%" % int(_current_items)
	lbl = _getInnerLabel(_secrets_value)
	if lbl != null:
		lbl.text = "%d%%" % int(_current_secrets)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		if _phase == Phase.STATS:
			if not _tally_done:
				# Skip tally animation
				_current_kills = _target_kills
				_current_items = _target_items
				_current_secrets = _target_secrets
				_updateStatValues()
				_tally_done = true
				Game.playSound("DSPISTOL")
			else:
				# Move to next level phase
				Game.playSound("DSPISTOL")
				_phase = Phase.NEXT_LEVEL
				_buildUI()
		elif _phase == Phase.NEXT_LEVEL:
			Game.playSound("DSPISTOL")
			visible = false
			continue_pressed.emit()
