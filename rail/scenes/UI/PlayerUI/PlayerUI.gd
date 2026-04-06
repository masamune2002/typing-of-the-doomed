extends Control
class_name PlayerUI

@onready var dialogBox : DialogBox = $DialogBoxMarginContainer/DialogBox
@onready var youWinPanel : MarginContainer = $YouWinMarginContainer
@onready var gameOverPanel : MarginContainer = $GameOverMarginContainer
@onready var loadingContainer : MarginContainer = $LoadingMarginContainer
@onready var statusBar : StatusBar = $StatusBarMarginContainer/StatusBar
@onready var weaponSprite : TextureRect = $WeaponSprite

var _winning : bool = false
var _playerCharacter : PlayerCharacter
var _performedSetup : bool = false
var _pickupFlash : ColorRect
var _weaponIdleFrames : Array[Texture2D] = []
var _weaponFireFrames : Array[Texture2D] = []
var _weaponAnimTimer : float = 0.0
var _weaponFrame : int = 0
var _weaponFiring : bool = false
var _weaponFirePhase : int = 0  # 0=not firing, 1=flash+recoil, 2=recovering
var _weaponSpriteW : float = 0.0
var _weaponSpriteH : float = 0.0
var _weaponBaseY : float = 0.0
var _weaponBaseX : float = 0.0
var _weaponScale : float = 1.0
var _weaponBottomY : float = 0.0
var _bobTime : float = 0.0
var _muzzleFlash : TextureRect
# DOOM pistol timing: 4 tics flash+recoil, 6 tics recovery (1 tic ≈ 28.6ms)
const FIRE_PHASE1_TIME : float = 0.115  # flash + recoil
const FIRE_PHASE2_TIME : float = 0.17   # recovery (gun slides back up)
const RECOIL_AMOUNT : float = 0.08      # fraction of sprite height to shift down

func _ready() -> void:
	youWinPanel.hide()
	gameOverPanel.hide()
	loadingContainer.hide()
	dialogBox.hide()
	# Force weapon sprite to manual positioning
	weaponSprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
	weaponSprite.anchor_left = 0.0
	weaponSprite.anchor_top = 0.0
	weaponSprite.anchor_right = 0.0
	weaponSprite.anchor_bottom = 0.0
	# Muzzle flash overlay
	_muzzleFlash = TextureRect.new()
	_muzzleFlash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_muzzleFlash.stretch_mode = TextureRect.STRETCH_SCALE
	_muzzleFlash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_muzzleFlash.visible = false
	_muzzleFlash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_muzzleFlash)
	_pickupFlash = ColorRect.new()
	_pickupFlash.color = Color(1.0, 1.0, 0.0, 0.3)
	_pickupFlash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pickupFlash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pickupFlash.visible = false
	add_child(_pickupFlash)
	move_child(_pickupFlash, get_child_count() - 1)

func setup(playerCharacter : PlayerCharacter) -> void:
	_playerCharacter = playerCharacter
	_performedSetup = true
	statusBar.setup()
	_loadWeaponSprites()

func _loadWeaponSprites() -> void:
	_tryLoadWeaponSprites()

func _tryLoadWeaponSprites() -> void:
	if Game.wadLoader == null or Game.wadLoader._loader == null:
		get_tree().process_frame.connect(_tryLoadWeaponSprites, CONNECT_ONE_SHOT)
		return
	for spriteName in ["PISGA0", "PISGB0"]:
		var tex = Game.fetchSprite(spriteName)
		if tex != null:
			_weaponIdleFrames.append(tex)
	for spriteName in ["PISFA0"]:
		var tex = Game.fetchSprite(spriteName)
		if tex != null:
			_weaponFireFrames.append(tex)
	if _weaponIdleFrames.size() > 0:
		weaponSprite.texture = _weaponIdleFrames[0]
	_layoutWeaponSprite()
	get_viewport().size_changed.connect(_layoutWeaponSprite)

func _layoutWeaponSprite() -> void:
	if _weaponIdleFrames.size() == 0:
		return
	var screenWidth := get_viewport().get_visible_rect().size.x
	var screenHeight := get_viewport().get_visible_rect().size.y
	var barHeight := statusBar.size.y
	var targetWidth := screenWidth * 0.15
	var texSize := _weaponIdleFrames[0].get_size()
	_weaponScale = targetWidth / texSize.x
	_weaponBottomY = screenHeight - barHeight
	_layoutIdleSprite()

func _layoutIdleSprite() -> void:
	var screenWidth := get_viewport().get_visible_rect().size.x
	var texSize := _weaponIdleFrames[0].get_size()
	_weaponSpriteW = texSize.x * _weaponScale
	_weaponSpriteH = texSize.y * _weaponScale
	_weaponBaseY = _weaponBottomY - _weaponSpriteH
	_weaponBaseX = (screenWidth - _weaponSpriteW) / 2.0
	weaponSprite.size = Vector2(_weaponSpriteW, _weaponSpriteH)
	weaponSprite.position = Vector2(_weaponBaseX, _weaponBaseY)

func _showMuzzleFlash() -> void:
	_muzzleFlash.texture = _weaponFireFrames[0]
	var flashW := _weaponSpriteW * 0.4
	var flashH := flashW * (_weaponFireFrames[0].get_size().y / _weaponFireFrames[0].get_size().x)
	_muzzleFlash.size = Vector2(flashW, flashH)
	_muzzleFlash.position = Vector2(
		weaponSprite.position.x + (_weaponSpriteW - flashW) / 2.0 + _weaponSpriteW * 0.2,
		weaponSprite.position.y - flashH * 0.5
	)
	_muzzleFlash.visible = true

func showWeaponFire() -> void:
	if _weaponFireFrames.size() == 0 or _weaponIdleFrames.size() < 2:
		return
	# Phase 1: recoil frame + muzzle flash
	weaponSprite.texture = _weaponIdleFrames[1]  # PISGB0 recoil frame
	weaponSprite.position.y = _weaponBaseY + _weaponSpriteH * RECOIL_AMOUNT
	_showMuzzleFlash()
	_weaponFiring = true
	_weaponFirePhase = 1
	_weaponAnimTimer = FIRE_PHASE1_TIME

func _process(delta : float) -> void:
	if _weaponFiring:
		_weaponAnimTimer -= delta
		if _weaponAnimTimer <= 0.0:
			if _weaponFirePhase == 1:
				# Phase 2: flash gone, gun recovering back to idle position
				_muzzleFlash.visible = false
				weaponSprite.texture = _weaponIdleFrames[0]  # PISGA0
				_weaponFirePhase = 2
				_weaponAnimTimer = FIRE_PHASE2_TIME
			else:
				# Done firing
				_weaponFiring = false
				_weaponFirePhase = 0
				weaponSprite.position.y = _weaponBaseY
		elif _weaponFirePhase == 2:
			# Smoothly slide gun back up during recovery
			var t := _weaponAnimTimer / FIRE_PHASE2_TIME
			weaponSprite.position.y = _weaponBaseY + _weaponSpriteH * RECOIL_AMOUNT * t
	# Weapon bob
	if _weaponIdleFrames.size() > 0:
		_bobTime += delta * 2.5
		var bobOffset = sin(_bobTime) * 4.0
		weaponSprite.position.y = _weaponBaseY + bobOffset

func _showLoading():
	loadingContainer.show()

func win() -> void:
	_winning = true
	youWinPanel.show()

func closeWin() -> void:
	youWinPanel.hide()
	_winning = false

func closeGameOver() -> void:
	gameOverPanel.hide()

func showDialog(dialog : Dialog) -> void:
	if !_performedSetup:
		return
	dialogBox.show()
	dialogBox.showDialog(dialog)
	if dialogBox.showingDialog:
		EventBus.wait.emit()

func updateStatus(health : int, armor : int, wasHit : bool) -> void:
	statusBar.updateStatus(health, armor, wasHit)

func updateKeys(keys: Array[String]) -> void:
	statusBar.updateKeys(keys)

func closeDialogBox() -> void:
	dialogBox.hide()
	EventBus.stopWait.emit()

func flashPickup() -> void:
	_pickupFlash.visible = true
	_pickupFlash.color = Color(1.0, 1.0, 0.0, 0.3)
	var tween = create_tween()
	tween.tween_property(_pickupFlash, "color:a", 0.0, 0.12)
	tween.tween_callback(func(): _pickupFlash.visible = false)

func showGameOver() -> void:
	gameOverPanel.show()
