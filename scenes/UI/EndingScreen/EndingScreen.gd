extends CanvasLayer
class_name EndingScreen

## DOOM-style episode end text wall: the FLOOR4_8 flat tiled behind red
## STCFN bitmap text, typed out at DOOM's cadence (one char per 3 tics).
## First key press reveals everything, second dismisses.

signal dismissed

var text : String = ""
var episode : int = 1

## Vanilla's post-text finale patch per episode (F_Finale stage 1):
## E1 the id credits, E2 the victory art, E3 the bunny ending (we show the
## final PFUB1 scene instead of animating the scroll), E4 the ENDPIC.
const FINALE_PICS := {1: "CREDIT", 2: "VICTORY2", 3: "PFUB1", 4: "ENDPIC"}

const BG_FLAT := "FLOOR4_8"
const CHARS_PER_SEC := 35.0 / 3.0  # DOOM types one char every 3 tics
# Logical canvas: 2x DOOM's 320x200 so the size-16 bitmap font (the same
# scale the menus use) renders at DOOM's 8px-per-line proportions.
const CANVAS_H := 400.0
const TEXT_COLUMN_W := 640.0
const TEXT_MARGIN := 20.0

var _label : Label
var _shown := 0.0
var _revealed := false
var _showing_finale_pic := false

func _ready() -> void:
	# DEHACKED replacements arrive mixed-case; the STCFN font is caps-only
	text = text.to_upper()
	layer = 20
	# Vanilla scores the episode end text with D_VICTOR (looping)
	Game.playMidiMusic("D_VICTOR")
	var vp := get_viewport().get_visible_rect().size
	var s := vp.y / CANVAS_H
	var canvas_w := vp.x / s

	var root := Control.new()
	root.scale = Vector2(s, s)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var flat := Game.fetchFlat(BG_FLAT)
	if flat != null:
		# Tile at DOOM density: 64px flat cells over a 320x200 screen
		var bg := TextureRect.new()
		bg.texture = flat
		bg.stretch_mode = TextureRect.STRETCH_TILE
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.size = Vector2(ceilf(canvas_w / 2.0), CANVAS_H / 2.0)
		bg.scale = Vector2(2, 2)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
	else:
		var solid := ColorRect.new()
		solid.color = Color(0.11, 0.0, 0.0)
		solid.size = Vector2(canvas_w, CANVAS_H)
		solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(solid)

	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# DOOM's text column: 320 wide starting at (10,10), centered on wide
	# viewports; doubled for this canvas
	_label.position = Vector2(maxf((canvas_w - TEXT_COLUMN_W) / 2.0, 0.0) + TEXT_MARGIN, TEXT_MARGIN)
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var doom_font = Game.getDoomFont()
	if doom_font != null:
		_label.add_theme_font_override("font", doom_font)
		# DOOM packs its text screen at 8px rows (16 on this 2x canvas).
		# Compute the spacing from the font's actual metrics — a hardcoded
		# value overflows the canvas when the engine version or the loaded
		# WAD's font reports a different line height.
		_label.add_theme_constant_override("line_spacing", int(16.0 - doom_font.get_height(16)))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", DoomGame.COLOR_RED)
	_label.visible_characters = 0
	root.add_child(_label)

func _process(delta: float) -> void:
	if _revealed:
		return
	_shown += delta * CHARS_PER_SEC
	_label.visible_characters = int(_shown)
	if _label.visible_characters >= text.length():
		_label.visible_characters = -1
		_revealed = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Mark handled BEFORE emitting: the dismissed handler reloads the
		# scene, removing this node from the tree mid-call — after which
		# get_viewport() is null.
		get_viewport().set_input_as_handled()
		# Only Enter/Space advance — players are usually still typing at
		# the monsters when this screen appears
		if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER \
				and event.keycode != KEY_SPACE:
			return
		if _showing_finale_pic:
			Game.stopMidiMusic()
			dismissed.emit()
			queue_free()
		elif !_revealed:
			_revealed = true
			_label.visible_characters = -1
		else:
			_showFinalePic()

## Vanilla follows the text with a full-screen episode patch — the credits
## after E1 — dismissed by one more key press.
func _showFinalePic() -> void:
	var tex = Game.fetchSprite(FINALE_PICS.get(episode, "CREDIT"))
	if tex == null:
		# WAD without the patch: end straight from the text
		Game.stopMidiMusic()
		dismissed.emit()
		queue_free()
		return
	_showing_finale_pic = true
	if episode == 3:
		Game.playMidiMusic("D_BUNNY")  # the bunny ending has its own score
	var cover := Control.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(black)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(pic)
