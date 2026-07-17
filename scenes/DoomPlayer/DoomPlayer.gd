extends Player
class_name DoomPlayer

const PISTOL_SCENE = preload("res://wads/doom/weapons/Pistol/Pistol.tscn")

var _weaponCycleIndex : int = 2  # start on pistol
var _isChangingWeapon : bool = false

var _headBobTime : float = 0.0
var _headBobBaseY : float = 0.0
var _headBobInitialized : bool = false
# Amplitude envelope (0..1): fades the bob in/out over a short window so a
# stop settles the camera smoothly and a resume continues the same phase,
# instead of hard-resetting the sine and snapping to base height.
var _headBobAmp : float = 0.0
const HEAD_BOB_FADE := 0.15

func _ready() -> void:
	if startingWeaponScene == null:
		startingWeaponScene = PISTOL_SCENE
	if weaponScenes.is_empty():
		weaponScenes = [PISTOL_SCENE]
	super()

func _physics_process(delta: float) -> void:
	super(delta)
	if !_alive:
		return
	if not _headBobInitialized:
		_headBobBaseY = _cameraRig.position.y
		_headBobInitialized = true
	var headBobScale = SettingsManager.head_bob if SettingsManager else 1.0
	var horizSpeed = Vector2(velocity.x, velocity.z).length()
	if horizSpeed > 0.01 and headBobScale > 0.0:
		_headBobTime += delta * 10.0 * getMovementSpeedRatio()
		_headBobAmp = move_toward(_headBobAmp, 1.0, delta / HEAD_BOB_FADE)
	else:
		_headBobAmp = move_toward(_headBobAmp, 0.0, delta / HEAD_BOB_FADE)
	_cameraRig.position.y = _headBobBaseY + sin(_headBobTime) * 0.3 * headBobScale * _headBobAmp

func _onAmmoDepleted() -> void:
	if _isChangingWeapon:
		return
	# Deferred so the swap doesn't start inside the firing call stack
	_fallBackToPistol.call_deferred()

func _fallBackToPistol() -> void:
	if _isChangingWeapon or _currentWeaponScene == PISTOL_SCENE:
		return
	# A spent weapon is lost, not holstered: dropping it from the inventory
	# lets the player pick the same weapon type up again later.
	weaponScenes.erase(_currentWeaponScene)
	_isChangingWeapon = true
	await changeWeapon(PISTOL_SCENE)
	_isChangingWeapon = false

func _cycleWeapon() -> void:
	if weaponScenes.size() <= 1:
		return
	_weaponCycleIndex = (_weaponCycleIndex + 1) % weaponScenes.size()
	var nextScene = weaponScenes[_weaponCycleIndex]
	if nextScene == _currentWeaponScene:
		return
	_isChangingWeapon = true
	await changeWeapon(nextScene)
	_isChangingWeapon = false

func changeWeapon(weaponScene : PackedScene, action : EncounterAction = null) -> void:
	# Lower current weapon
	_playerUi.lowerWeapon()
	await _playerUi.weaponLowered

	# Swap weapon node
	var newWeapon = weaponScene.instantiate()
	var oldWeapon = _currentWeapon
	_cameraRig.add_child(newWeapon)
	newWeapon.transform = oldWeapon.transform
	_currentWeapon = newWeapon
	_currentWeaponScene = weaponScene
	oldWeapon.queue_free()

	# Keep cycle index in sync
	var idx = weaponScenes.find(weaponScene)
	if idx >= 0:
		_weaponCycleIndex = idx

	# Notify enemies of new weapon difficulty
	EventBus.weaponChanged.emit()

	# Load new weapon's HUD sprites and raise
	updateAmmoUi()
	_playerUi.loadWeaponSprites(newWeapon)
	_playerUi.raiseWeapon()
	await _playerUi.weaponRaised

	if action != null:
		action.finish()
