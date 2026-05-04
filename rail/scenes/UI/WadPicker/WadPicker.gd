extends Control
class_name WadPicker

signal wad_selected(wad_path: String)

var _vbox : VBoxContainer
var _wad_list : VBoxContainer
var _browse_container : VBoxContainer
var _file_dialog : FileDialog

func _ready() -> void:
	# Make this control fill the viewport
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Full-screen dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Centered container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 600)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 1.0)
	style.border_color = Color(0.3, 0.3, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(64)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 24)
	panel.add_child(_vbox)

	var title = Label.new()
	title.text = "Select a WAD File"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_vbox.add_child(title)

	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 8)
	_vbox.add_child(separator)

	# WAD buttons go here
	_wad_list = VBoxContainer.new()
	_wad_list.add_theme_constant_override("separation", 16)
	_vbox.add_child(_wad_list)

	# Expanding spacer pushes browse to bottom
	var expand_spacer = Control.new()
	expand_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(expand_spacer)

	# Browse container at bottom
	_browse_container = VBoxContainer.new()
	_vbox.add_child(_browse_container)

	# File dialog (hidden until browse is clicked)
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.wad ; WAD Files", "*.WAD ; WAD Files"])
	_file_dialog.title = "Select WAD File"
	_file_dialog.min_size = Vector2i(1200, 800)
	_file_dialog.file_selected.connect(_onFileSelected)
	# Set initial directory to last used WAD path
	if SettingsManager.last_wad_path != "":
		_file_dialog.current_dir = SettingsManager.last_wad_path.get_base_dir()
	add_child(_file_dialog)

func addWadOption(wad_path: String, display_name: String) -> void:
	var button = _createButton(display_name, _wad_list)
	button.pressed.connect(func(): wad_selected.emit(wad_path))

func showNoWadsMessage() -> void:
	var label = Label.new()
	label.text = "No WAD files were found automatically."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_wad_list.add_child(label)

func addBrowseButton() -> void:
	var button = _createButton("Browse...", _browse_container)
	button.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	button.pressed.connect(func(): _file_dialog.popup_centered())

func _createButton(text: String, parent: Control = _vbox) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 80)
	button.add_theme_font_size_override("font_size", 52)
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.18, 0.18, 0.25, 1.0)
	style_normal.set_corner_radius_all(6)
	style_normal.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", style_normal)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.35, 1.0)
	style_hover.set_corner_radius_all(6)
	style_hover.set_content_margin_all(12)
	button.add_theme_stylebox_override("hover", style_hover)
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	style_pressed.set_corner_radius_all(6)
	style_pressed.set_content_margin_all(12)
	button.add_theme_stylebox_override("pressed", style_pressed)
	parent.add_child(button)
	return button

func _onFileSelected(path: String) -> void:
	wad_selected.emit(path)
