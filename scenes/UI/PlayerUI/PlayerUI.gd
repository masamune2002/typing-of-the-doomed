extends Control
class_name PlayerUI

@onready var dialogBox : DialogBox = $DialogBoxMarginContainer/DialogBox
@onready var youWinPanel : MarginContainer = $YouWinMarginContainer
@onready var gameOverPanel : MarginContainer = $GameOverMarginContainer
@onready var loadingContainer : MarginContainer = $LoadingMarginContainer
@onready var statusBar : StatusBar = $StatusBarMarginContainer/StatusBar
@onready var weaponSprite : TextureRect = $WeaponSprite
@onready var painFlash : ColorRect = %PainFlash

var _winning : bool = false
var _painTween : Tween
var _playerCharacter : PlayerCharacter
var _performedSetup : bool = false
@onready var _muzzleFlash : TextureRect = %MuzzleFlash
@onready var _pickupFlash : ColorRect = %PickupFlash
@onready var _deathTint : ColorRect = %DeathTint
var _weaponIdleFrames : Array[Texture2D] = []
var _weaponFireFrames : Array[Texture2D] = []
var _weaponAnimTimer : float = 0.0
var _weaponFiring : bool = false
var _weaponFirePhase : int = 0  # 0=not firing, 1=flash+recoil, 2=recovering
var _weaponFireQueued : bool = false
var _weaponSpriteW : float = 0.0
var _weaponSpriteH : float = 0.0
var _weaponBaseY : float = 0.0
var _weaponBaseX : float = 0.0
var _weaponScale : float = 1.0
var _weaponBottomY : float = 0.0
var _bobTime : float = 0.0
var _swapTween : Tween
var _bobDebugRect : ColorRect
var _bobDebugTrail : Control
var _bobTrailPoints : PackedVector2Array = PackedVector2Array()
var BOB_DEBUG : bool:
	get: return SettingsManager.debug_reticle
const BOB_DEBUG_TRAIL_MAX := 300
signal weaponLowered
signal weaponRaised
const DEFAULT_FIRE_PHASE1_TIME : float = 0.115
const DEFAULT_FIRE_PHASE2_TIME : float = 0.17
var _firePhase1Time : float = DEFAULT_FIRE_PHASE1_TIME
var _firePhase2Time : float = DEFAULT_FIRE_PHASE2_TIME
var _burstRemaining : int = 0
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
	# Reticle / bob debug visualization
	_bobDebugTrail = Control.new()
	_bobDebugTrail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bobDebugTrail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bobDebugTrail.z_index = 100
	_bobDebugTrail.draw.connect(_drawBobTrail.bind(_bobDebugTrail))
	add_child(_bobDebugTrail)
	_bobDebugRect = ColorRect.new()
	_bobDebugRect.color = Color(1, 0, 0, 1)
	_bobDebugRect.size = Vector2(16, 16)
	_bobDebugRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bobDebugRect.z_index = 101
	add_child(_bobDebugRect)

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
	# Load from current weapon's sprite arrays if available
	var player = Game.getPlayer()
	var idleSpriteNames := ["PISGA0", "PISGB0"]
	var fireSpriteNames := ["PISFA0"]
	if player != null and player._currentWeapon != null and "idleSprites" in player._currentWeapon:
		idleSpriteNames = player._currentWeapon.idleSprites
		fireSpriteNames = player._currentWeapon.fireSprites
	_loadSpritesFromNames(idleSpriteNames, fireSpriteNames)

func loadWeaponSprites(weapon : Weapon) -> void:
	if weapon == null or not "idleSprites" in weapon:
		return
	_loadSpritesFromNames(weapon.idleSprites, weapon.fireSprites)

func _loadSpritesFromNames(idleNames : Array, fireNames : Array) -> void:
	_weaponIdleFrames.clear()
	_weaponFireFrames.clear()
	for spriteName in idleNames:
		var tex = Game.fetchSprite(spriteName)
		if tex != null:
			_weaponIdleFrames.append(tex)
	for spriteName in fireNames:
		var tex = Game.fetchSprite(spriteName)
		if tex != null:
			_weaponFireFrames.append(tex)
	if _weaponIdleFrames.size() > 0:
		weaponSprite.texture = _weaponIdleFrames[0]
		weaponSprite.visible = true
	_layoutWeaponSprite()
	if not get_viewport().size_changed.is_connected(_layoutWeaponSprite):
		get_viewport().size_changed.connect(_layoutWeaponSprite)

func _layoutWeaponSprite() -> void:
	if _weaponIdleFrames.size() == 0:
		return
	var screenWidth := get_viewport().get_visible_rect().size.x
	var screenHeight := get_viewport().get_visible_rect().size.y
	var barHeight := statusBar.size.y
	# Scale all weapon sprites uniformly based on DOOM's 320px reference width
	_weaponScale = screenWidth / 320.0 * 0.65
	_weaponBottomY = screenHeight - barHeight
	_layoutIdleSprite()

func _layoutIdleSprite() -> void:
	var screenWidth := get_viewport().get_visible_rect().size.x
	var texSize := _weaponIdleFrames[0].get_size()
	_weaponSpriteW = texSize.x * _weaponScale
	_weaponSpriteH = texSize.y * _weaponScale
	_weaponBaseY = _weaponBottomY - _weaponSpriteH + _weaponSpriteH * 0.15
	_weaponBaseX = (screenWidth - _weaponSpriteW) / 2.0
	weaponSprite.size = Vector2(_weaponSpriteW, _weaponSpriteH)
	weaponSprite.position = Vector2(_weaponBaseX, _weaponBaseY)

func _showMuzzleFlash() -> void:
	_muzzleFlash.texture = _weaponFireFrames[0]
	var flashW := _weaponSpriteW * 0.4
	var flashH := flashW * (_weaponFireFrames[0].get_size().y / _weaponFireFrames[0].get_size().x)
	_muzzleFlash.size = Vector2(flashW, flashH)
	var flashOffsetX := 0.0
	var player = Game.getPlayer()
	if player != null and player._currentWeapon != null and "muzzleFlashOffsetX" in player._currentWeapon:
		flashOffsetX = player._currentWeapon.muzzleFlashOffsetX
	_muzzleFlash.position = Vector2(
		weaponSprite.position.x + (_weaponSpriteW - flashW) / 2.0 + _weaponSpriteW * flashOffsetX,
		weaponSprite.position.y - flashH * 0.5
	)
	_muzzleFlash.visible = true

func showWeaponFire() -> void:
	if _weaponIdleFrames.size() < 2:
		return
	if _weaponFiring:
		_weaponFireQueued = true
		return
	var player = Game.getPlayer()
	if player != null and player._currentWeapon != null and "burstCount" in player._currentWeapon:
		_burstRemaining = player._currentWeapon.burstCount - 1
	else:
		_burstRemaining = 0
	_startFireAnimation()

func _startFireAnimation() -> void:
	var recoilIdx := 1
	var player = Game.getPlayer()
	if player != null and player._currentWeapon != null:
		if "recoilSpriteIndex" in player._currentWeapon:
			recoilIdx = player._currentWeapon.recoilSpriteIndex
		if "firePhase1Time" in player._currentWeapon:
			_firePhase1Time = player._currentWeapon.firePhase1Time
			_firePhase2Time = player._currentWeapon.firePhase2Time
		else:
			_firePhase1Time = DEFAULT_FIRE_PHASE1_TIME
			_firePhase2Time = DEFAULT_FIRE_PHASE2_TIME
	recoilIdx = mini(recoilIdx, _weaponIdleFrames.size() - 1)
	weaponSprite.texture = _weaponIdleFrames[recoilIdx]
	weaponSprite.position.x = _weaponBaseX
	weaponSprite.position.y = _weaponBaseY + _weaponSpriteH * RECOIL_AMOUNT
	if _weaponFireFrames.size() > 0:
		_showMuzzleFlash()
	_weaponFiring = true
	_weaponFirePhase = 1
	_weaponAnimTimer = _firePhase1Time

func _process(delta : float) -> void:
	if _weaponFiring:
		_weaponAnimTimer -= delta
		if _weaponAnimTimer <= 0.0:
			if _weaponFirePhase == 1:
				# Phase 2: flash gone, gun recovering back to idle position
				_muzzleFlash.visible = false
				weaponSprite.texture = _weaponIdleFrames[0]
				_weaponFirePhase = 2
				_weaponAnimTimer = _firePhase2Time
			else:
				# Done firing — check for burst or queued shot
				if _burstRemaining > 0:
					_burstRemaining -= 1
					var player = Game.getPlayer()
					if player != null and player._currentWeapon != null:
						Game.playSound(player._currentWeapon.fireSound)
					_startFireAnimation()
				elif _weaponFireQueued:
					_weaponFireQueued = false
					_weaponFiring = false
					_weaponFirePhase = 0
					weaponSprite.position.y = _weaponBaseY
					showWeaponFire()
				else:
					_weaponFiring = false
					_weaponFirePhase = 0
					weaponSprite.position.y = _weaponBaseY
		elif _weaponFirePhase == 2:
			# Smoothly slide gun back up during recovery
			var t := _weaponAnimTimer / _firePhase2Time
			weaponSprite.position.y = _weaponBaseY + _weaponSpriteH * RECOIL_AMOUNT * t
	# Weapon bob and sway (only when moving, skip when dead)
	if _weaponIdleFrames.size() > 0 and not _gameOver:
		var swayScale = SettingsManager.weapon_sway if SettingsManager else 1.0
		var player = Game.getPlayer()
		var moving = player != null and player.isMoving()
		var bobOffset := 0.0
		var swayOffset := 0.0
		if _weaponFiring:
			_bobTime = 0.0
			weaponSprite.position.x = _weaponBaseX
		elif moving and swayScale > 0.0:
			_bobTime += delta * 8.0 * player.getMovementSpeedRatio()
			# DOOM-style figure-8: X is cos(angle), Y is sin(angle*2) at half amplitude
			swayOffset = cos(_bobTime) * _weaponSpriteW * 0.1 * swayScale
			bobOffset = sin(_bobTime * 2.0) * _weaponSpriteH * 0.05 * swayScale
			# Extra sway when strafing (only when the keys actually steer)
			if player.isWasdActive():
				if Input.is_action_pressed("strafeLeft"):
					swayOffset += _weaponSpriteW * 0.1 * swayScale
				if Input.is_action_pressed("strafeRight"):
					swayOffset -= _weaponSpriteW * 0.1 * swayScale
			weaponSprite.position.y = _weaponBaseY + bobOffset
			weaponSprite.position.x = _weaponBaseX + swayOffset
		else:
			_bobTime = 0.0
			weaponSprite.position.y = _weaponBaseY
			weaponSprite.position.x = _weaponBaseX
		# Update reticle visualization
		if _bobDebugRect != null:
			if BOB_DEBUG:
				var screenCenter = get_viewport().get_visible_rect().size / 2.0
				var debugPos = screenCenter + Vector2(swayOffset, bobOffset)
				_bobDebugRect.position = debugPos - _bobDebugRect.size / 2.0
				if moving and not _weaponFiring and swayScale > 0.0:
					_bobTrailPoints.append(debugPos)
					if _bobTrailPoints.size() > BOB_DEBUG_TRAIL_MAX:
						_bobTrailPoints = _bobTrailPoints.slice(_bobTrailPoints.size() - BOB_DEBUG_TRAIL_MAX)
					_bobDebugTrail.queue_redraw()
				_bobDebugRect.visible = true
				_bobDebugTrail.visible = true
			else:
				_bobDebugRect.visible = false
				_bobDebugTrail.visible = false

func _drawBobTrail(canvas: Control) -> void:
	if _bobTrailPoints.size() < 2:
		return
	for i in range(_bobTrailPoints.size() - 1):
		var alpha = float(i) / float(_bobTrailPoints.size())
		canvas.draw_line(_bobTrailPoints[i], _bobTrailPoints[i + 1], Color(1, 1, 0, alpha * 0.8), 2.0)
	# Draw a crosshair at center for reference
	var center = get_viewport().get_visible_rect().size / 2.0
	canvas.draw_line(center - Vector2(20, 0), center + Vector2(20, 0), Color(1, 1, 1, 0.5), 1.0)
	canvas.draw_line(center - Vector2(0, 20), center + Vector2(0, 20), Color(1, 1, 1, 0.5), 1.0)

func _showLoading():
	loadingContainer.show()

func win() -> void:
	_winning = true
	youWinPanel.show()

func closeWin() -> void:
	youWinPanel.hide()
	_winning = false

func closeGameOver() -> void:
	_gameOver = false
	_deathTint.visible = false

func showDialog(dialog : Dialog) -> void:
	if !_performedSetup:
		return
	dialogBox.show()
	dialogBox.showDialog(dialog)
	if dialogBox.showingDialog:
		EventBus.wait.emit()

func updateStatus(health : int, armor : int, wasHit : bool) -> void:
	statusBar.updateStatus(health, armor, wasHit)
	if wasHit:
		showPainFlash()

func showPainFlash() -> void:
	if _painTween != null and _painTween.is_running():
		_painTween.kill()
	painFlash.visible = true
	painFlash.modulate = Color(1, 1, 1, 1)
	_painTween = create_tween()
	_painTween.tween_property(painFlash, "modulate:a", 0.0, 0.15)
	_painTween.tween_callback(func(): painFlash.visible = false)

func updateKeys(keys: Array[String]) -> void:
	statusBar.updateKeys(keys)

func updateAmmo(ammo : int) -> void:
	statusBar.updateAmmo(ammo)

func closeDialogBox() -> void:
	dialogBox.hide()
	EventBus.stopWait.emit()

func flashPickup() -> void:
	_pickupFlash.visible = true
	_pickupFlash.color = Color(1.0, 1.0, 0.0, 0.3)
	var tween = create_tween()
	tween.tween_property(_pickupFlash, "color:a", 0.0, 0.12)
	tween.tween_callback(func(): _pickupFlash.visible = false)

var _gameOver : bool = false

func showGameOver() -> void:
	_gameOver = true
	weaponSprite.visible = false
	_muzzleFlash.visible = false
	# Fade in red tint over the death animation
	_deathTint.color = Color(1.0, 0.0, 0.0, 0.0)
	_deathTint.visible = true
	var tintTween = create_tween()
	tintTween.tween_property(_deathTint, "color:a", 0.35, 1.0)

func lowerWeapon(duration : float = 0.3) -> void:
	if _swapTween != null and _swapTween.is_running():
		_swapTween.kill()
	_weaponFiring = false
	_muzzleFlash.visible = false
	var offScreenY = _weaponBottomY + 20.0
	_swapTween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_swapTween.tween_property(weaponSprite, "position:y", offScreenY, duration)
	_swapTween.tween_callback(func(): weaponLowered.emit())

func raiseWeapon(duration : float = 0.3) -> void:
	if _swapTween != null and _swapTween.is_running():
		_swapTween.kill()
	var offScreenY = _weaponBottomY + 20.0
	weaponSprite.position.y = offScreenY
	_swapTween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_swapTween.tween_property(weaponSprite, "position:y", _weaponBaseY, duration)
	_swapTween.tween_callback(func(): weaponRaised.emit())
