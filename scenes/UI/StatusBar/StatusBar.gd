extends Control
class_name StatusBar

@onready var background : TextureRect = $Background
@onready var healthDigits : Array[TextureRect] = [$HealthDigits/Digit0, $HealthDigits/Digit1, $HealthDigits/Digit2]
@onready var healthPercent : TextureRect = $HealthDigits/Percent
@onready var armorDigits : Array[TextureRect] = [$ArmorDigits/Digit0, $ArmorDigits/Digit1, $ArmorDigits/Digit2]
@onready var armorPercent : TextureRect = $ArmorDigits/Percent
@onready var faceSprite : TextureRect = $FaceSprite
@onready var healthContainer : HBoxContainer = $HealthDigits
@onready var armorContainer : HBoxContainer = $ArmorDigits
@onready var killDigitsContainer : HBoxContainer = $KillDigits
@onready var _killDigits : Array[TextureRect] = [$KillDigits/Digit0, $KillDigits/Digit1, $KillDigits/Digit2]
@onready var ammoDigitsContainer : HBoxContainer = $AmmoDigits
@onready var _ammoDigits : Array[TextureRect] = [$AmmoDigits/Digit0, $AmmoDigits/Digit1, $AmmoDigits/Digit2]
@onready var _keySprites : Array[TextureRect] = [$KeySlot0, $KeySlot1, $KeySlot2]

# DOOM STBAR is 320x32 pixels
const STBAR_WIDTH : float = 320.0
const STBAR_HEIGHT : float = 32.0

# Original DOOM positions (in 320x32 coordinate space)
# Health digits: roughly x=48, centered vertically
# Face: centered around x=143
# Armor digits: roughly x=220
const HEALTH_X : float = 48.0
const HEALTH_Y : float = 3.0
const FACE_X : float = 143.0
const FACE_Y : float = 1.0
const FACE_W : float = 33.0
const FACE_H : float = 30.0
const ARMOR_X : float = 179.0
const ARMOR_Y : float = 3.0
const DIGIT_W : float = 14.0
const DIGIT_H : float = 16.0
const PERCENT_W : float = 14.0

var _digitTextures : Array[Texture2D] = []
var _infinityTexture : Texture2D

# Bar-local Y (in 320x32 STBAR space) where the big value digits sit.
# Vanilla puts them at 3 with the small panel labels along the bottom, but
# official STBARs vary between releases — _probeBarLayout reads the actual
# graphic and moves the digits out of the label band if it's on top.
var _value_y : float = 3.0
var _percentTexture : Texture2D = null

# DOOM face sprites
var _normalFaces : Array[Texture2D] = []
var _ouchFaces : Array[Texture2D] = []
var _deadFace : Texture2D = null

var _showingOuch : bool = false
var _ouchTimer : float = 0.0
const OUCH_DURATION : float = 0.5

var _currentHealth : int = 100
var _killCount : int = 0

# Kill counter position (in the FRAGS area, x=100-138 in DOOM coords)
const KILLS_X : float = 100.0
const KILLS_Y : float = 3.0

# Ammo readout — DOOM's big red digits, right edge at x=44 like the original
# STBAR. -1 means infinite and renders a sideways 8 as the infinity symbol.
const AMMO_X : float = 2.0
const AMMO_Y : float = 3.0
var _currentAmmo : int = -1

# Key display - DOOM STBAR key positions (in 320x32 space)
# Keys appear in a column on the right side of the status bar
const KEY_X : float = 239.0
const KEY_Y_BLUE : float = 5.0
const KEY_Y_YELLOW : float = 15.0
const KEY_Y_RED : float = 25.0
const KEY_W : float = 6.0
const KEY_H : float = 4.0

# STKEYS0=blue card, 1=yellow card, 2=red card, 3=blue skull, 4=yellow skull, 5=red skull
var _keyTextures : Array[Texture2D] = []

func setup() -> void:
	_loadBarGraphics()
	_loadFaceSprites()
	_setupKeySprites()
	updateStatus(100, 0, false)
	_updateBarHeight()
	resetKills()
	if not EventBus.enemyKilled.is_connected(_onEnemyKilled):
		EventBus.enemyKilled.connect(_onEnemyKilled)

func _onEnemyKilled(_enemy: Enemy) -> void:
	addKill()

func _loadBarGraphics() -> void:
	background.texture = Game.fetchSprite(DoomGame.STATUS_BAR)
	_probeBarLayout()
	_digitTextures.resize(10)
	for i in range(10):
		_digitTextures[i] = Game.fetchSprite("STTNUM%d" % i)

	# Bake the infinity symbol as a genuinely sideways 8. Rotating the
	# TextureRect at runtime was unreliable: the digits sit in an
	# HBoxContainer, and every deferred container sort runs
	# fit_child_in_rect, which resets child rotation — any sort landing
	# after the rotation write left a plain upright 8.
	_infinityTexture = null
	if _digitTextures[8] != null:
		var img := _digitTextures[8].get_image()
		if img != null:
			img = img.duplicate()
			if img.is_compressed():
				img.decompress()
			img.rotate_90(CLOCKWISE)
			_infinityTexture = ImageTexture.create_from_image(img)

	_percentTexture = Game.fetchSprite("STTPRCNT")
	healthPercent.texture = _percentTexture
	armorPercent.texture = _percentTexture

## Find the small panel-label band ("AMMO", "HEALTH", ...) in the loaded
## WAD's own STBAR pixels and keep the value digits out of it. Scans the
## AMMO panel (x 4..40 in 320x32 space) for rows dominated by bright label
## pixels; wall-texture noise stays well under the threshold.
func _probeBarLayout() -> void:
	_value_y = 3.0
	if background.texture == null:
		return
	var img : Image = background.texture.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	# Widescreen STBARs (e.g. the Unity re-release assets) are wider than
	# 320 with the classic art centered and filler on the sides — the same
	# center-crop KEEP_ASPECT_COVERED renders. Sample in art space: the
	# height sets the pixel-per-unit scale, the art is centered.
	var unit := img.get_height() / STBAR_HEIGHT
	var art_x0 := maxf((img.get_width() - STBAR_WIDTH * unit) / 2.0, 0.0)
	var band_start := -1
	var band_end := -1
	for row in range(2, 30):
		var bright := 0
		for col in range(4, 41):
			if img.get_pixel(int(art_x0 + col * unit), int(row * unit)).get_luminance() > 0.45:
				bright += 1
		if bright >= 12:
			if band_start < 0:
				band_start = row
			band_end = row
	if band_start < 0:
		return
	if (band_start + band_end) / 2.0 <= 16.0:
		# Labels along the top: drop the digits below the band
		_value_y = clampf(band_end + 2.0, 3.0, STBAR_HEIGHT - DIGIT_H - 2.0)

func _loadFaceSprites() -> void:
	_normalFaces.resize(5)
	_ouchFaces.resize(5)
	for level in range(5):
		_normalFaces[level] = Game.fetchSprite("STFST%d0" % level)
		_ouchFaces[level] = Game.fetchSprite("STFOUCH%d" % level)
	_deadFace = Game.fetchSprite("STFDEAD0")

func _setupKeySprites() -> void:
	_keyTextures.resize(6)
	for i in range(6):
		_keyTextures[i] = Game.fetchSprite("STKEYS%d" % i)

func _getKeyMap() -> Dictionary:
	var wad_game = Game.getWadGame()
	if wad_game != null:
		return wad_game.key_map
	return {}

func updateKeys(keys: Array[String]) -> void:
	for sprite in _keySprites:
		sprite.visible = false
		sprite.texture = null
	var km = _getKeyMap()
	for key_name in keys:
		if km.has(key_name):
			var info = km[key_name]
			var slot : int = info[0]
			var card_idx : int = info[1]
			var skull_idx : int = info[2]
			var tex_idx = card_idx if card_idx >= 0 else skull_idx
			if tex_idx >= 0 and tex_idx < _keyTextures.size() and _keyTextures[tex_idx] != null:
				_keySprites[slot].texture = _keyTextures[tex_idx]
				_keySprites[slot].visible = true
	_layoutKeys()

func _layoutKeys() -> void:
	var barSize := size
	var scaleX := barSize.x / STBAR_WIDTH
	var scaleY := barSize.y / STBAR_HEIGHT
	var keyW := KEY_W * scaleX
	var keyH := KEY_H * scaleY
	var keyX := KEY_X * scaleX
	if _keySprites.size() >= 3:
		_keySprites[0].position = Vector2(keyX, KEY_Y_BLUE * scaleY)
		_keySprites[0].size = Vector2(keyW, keyH)
		_keySprites[1].position = Vector2(keyX, KEY_Y_YELLOW * scaleY)
		_keySprites[1].size = Vector2(keyW, keyH)
		_keySprites[2].position = Vector2(keyX, KEY_Y_RED * scaleY)
		_keySprites[2].size = Vector2(keyW, keyH)

func _ready() -> void:
	resized.connect(_layoutElements)
	get_viewport().size_changed.connect(_updateBarHeight)
	_updateBarHeight()

func _updateBarHeight() -> void:
	var screenWidth := get_viewport().get_visible_rect().size.x
	var barHeight := screenWidth / (STBAR_WIDTH / STBAR_HEIGHT)
	custom_minimum_size.y = barHeight
	# Update the parent MarginContainer offset so it sizes to fit
	var parent := get_parent()
	if parent is MarginContainer:
		parent.offset_top = -barHeight
	_layoutElements()

func _layoutElements() -> void:
	var barSize := size
	var scaleX := barSize.x / STBAR_WIDTH
	var scaleY := barSize.y / STBAR_HEIGHT

	# Size and position digit containers
	var digitW := DIGIT_W * scaleX
	var digitH := DIGIT_H * scaleY
	var percentW := PERCENT_W * scaleX

	# Health digits position
	healthContainer.position = Vector2(HEALTH_X * scaleX, _value_y * scaleY)
	for d in healthDigits:
		d.custom_minimum_size = Vector2(digitW, digitH)
	healthPercent.custom_minimum_size = Vector2(percentW, digitH)

	# Armor digits position
	armorContainer.position = Vector2(ARMOR_X * scaleX, _value_y * scaleY)
	for d in armorDigits:
		d.custom_minimum_size = Vector2(digitW, digitH)
	armorPercent.custom_minimum_size = Vector2(percentW, digitH)

	# Face position
	faceSprite.position = Vector2(FACE_X * scaleX, FACE_Y * scaleY)
	faceSprite.size = Vector2(FACE_W * scaleX, FACE_H * scaleY)

	# Kill counter digits
	killDigitsContainer.position = Vector2(KILLS_X * scaleX, _value_y * scaleY)
	for d in _killDigits:
		d.custom_minimum_size = Vector2(digitW, digitH)
	_updateKillDigits()

	# Ammo digits
	ammoDigitsContainer.position = Vector2(AMMO_X * scaleX, _value_y * scaleY)
	for d in _ammoDigits:
		d.custom_minimum_size = Vector2(digitW, digitH)
	_updateAmmoDigits()

	_layoutKeys()

func _updateKillDigits() -> void:
	if _killDigits.size() < 3:
		return
	_setDigits(_killDigits, _killCount)

func updateAmmo(ammo : int) -> void:
	_currentAmmo = ammo
	_updateAmmoDigits()

func _updateAmmoDigits() -> void:
	if _ammoDigits.size() < 3 or _digitTextures.size() < 10:
		return
	if _currentAmmo < 0:
		# Infinite ammo: a sideways 8 reads as the infinity symbol, baked
		# from the same STTNUM digit sprites as the rest of the bar.
		_ammoDigits[0].texture = null
		_ammoDigits[2].texture = null
		_ammoDigits[1].texture = _infinityTexture if _infinityTexture != null else _digitTextures[8]
	else:
		_setDigits(_ammoDigits, _currentAmmo)

func addKill() -> void:
	_killCount += 1
	_updateKillDigits()

func resetKills() -> void:
	_killCount = 0
	_updateKillDigits()

func updateStatus(health : int, armor : int, wasHit : bool) -> void:
	_currentHealth = health
	_setDigits(healthDigits, health)
	_setDigits(armorDigits, armor)

	if wasHit:
		_showingOuch = true
		_ouchTimer = OUCH_DURATION

	_updateFace()

func _setDigits(digits : Array[TextureRect], value : int) -> void:
	if _digitTextures.size() < 10:
		return
	value = clampi(value, 0, 999)
	@warning_ignore("integer_division")
	var hundreds := value / 100
	@warning_ignore("integer_division")
	var tens := (value % 100) / 10
	var ones := value % 10

	# Hide leading zeros
	if value >= 100:
		digits[0].texture = _digitTextures[hundreds]
	else:
		digits[0].texture = null

	if value >= 10:
		digits[1].texture = _digitTextures[tens]
	else:
		digits[1].texture = null

	digits[2].texture = _digitTextures[ones]

func _process(delta : float) -> void:
	if _showingOuch:
		_ouchTimer -= delta
		if _ouchTimer <= 0.0:
			_showingOuch = false
			_updateFace()

func _updateFace() -> void:
	if _currentHealth <= 0:
		if _deadFace != null:
			faceSprite.texture = _deadFace
		return

	@warning_ignore("integer_division")
	var level : int = 4 - clampi(_currentHealth / 20, 0, 4)
	var faces : Array[Texture2D] = _ouchFaces if _showingOuch else _normalFaces
	if level < faces.size() and faces[level] != null:
		faceSprite.texture = faces[level]
