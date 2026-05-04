extends Player
class_name DoomPlayer

const FIST_SCENE = preload("res://weapons/Fist/Fist.tscn")
const CHAINSAW_SCENE = preload("res://weapons/Chainsaw/Chainsaw.tscn")
const PISTOL_SCENE = preload("res://weapons/Pistol/Pistol.tscn")
const SHOTGUN_SCENE = preload("res://weapons/Shotgun/Shotgun.tscn")
const CHAINGUN_SCENE = preload("res://weapons/Chaingun/Chaingun.tscn")
const ROCKET_SCENE = preload("res://weapons/RocketLauncher/RocketLauncher.tscn")
const PLASMA_SCENE = preload("res://weapons/PlasmaRifle/PlasmaRifle.tscn")
const BFG_SCENE = preload("res://weapons/BFG/BFG.tscn")

var _weaponCycleIndex : int = 2  # start on pistol
var _isChangingWeapon : bool = false

var _headBobTime : float = 0.0
var _headBobBaseY : float = 0.0
var _headBobInitialized : bool = false

func _ready() -> void:
	if startingWeaponScene == null:
		startingWeaponScene = PISTOL_SCENE
	if weaponScenes.is_empty():
		weaponScenes = [FIST_SCENE, CHAINSAW_SCENE, PISTOL_SCENE, SHOTGUN_SCENE,
			CHAINGUN_SCENE, ROCKET_SCENE, PLASMA_SCENE, BFG_SCENE]
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
		_cameraRig.position.y = _headBobBaseY + sin(_headBobTime) * 0.3 * headBobScale
	else:
		_headBobTime = 0.0
		_cameraRig.position.y = _headBobBaseY

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and !event.echo:
		if event.keycode == KEY_CTRL:
			if _alive and !_isChangingWeapon:
				_cycleWeapon()
			get_viewport().set_input_as_handled()
			return
	super(event)

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
	_playerUi.loadWeaponSprites(newWeapon)
	_playerUi.raiseWeapon()
	await _playerUi.weaponRaised

	if action != null:
		action.finish()
