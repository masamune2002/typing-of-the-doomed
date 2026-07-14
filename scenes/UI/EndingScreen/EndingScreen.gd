extends CanvasLayer
class_name EndingScreen

## DOOM-style episode end text wall: dark screen, typewriter reveal in the
## DOOM font. First key press reveals everything, second dismisses.

signal dismissed

var text : String = ""

const CHARS_PER_SEC := 40.0

var _label : Label
var _shown := 0.0
var _revealed := false

func _ready() -> void:
	layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label = Label.new()
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	var doom_font = Game.getDoomFont()
	if doom_font != null:
		_label.add_theme_font_override("font", doom_font)
	var vp := get_viewport().get_visible_rect().size
	_label.add_theme_font_size_override("font_size", maxi(16, int(vp.y / 26.0)))
	_label.add_theme_color_override("font_color", DoomGame.COLOR_RED)
	_label.visible_characters = 0
	add_child(_label)

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
		if !_revealed:
			_revealed = true
			_label.visible_characters = -1
		else:
			dismissed.emit()
			queue_free()
		get_viewport().set_input_as_handled()
