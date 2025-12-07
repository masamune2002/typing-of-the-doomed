extends Node3D

class_name Player

@export var moveSpeed: float = 2.0
@export var playerCharacter : PlayerCharacter
@export var startingWeapon : Weapon

@onready var _defaultWeapon : Weapon = $CameraRig/TypingGun
@onready var _playerUi : PlayerUI = $Hud

signal fireWeapon(weapon : Enums.WEAPON_FIRE_TYPE, targetEnemy : Enemy, payload : Variant)

var _alive : bool
var _hitPointsRemaining : int
var _moving : bool

var _currentWeapon : Weapon
var currentPath : Path3D
var currentPathFollow : PathFollow3D
var currentEncounter : EncounterPoint
var _currentFireTarget : Enemy
var _moveTarget : Vector3
var _moveAction : MoveCameraAction

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(false)
	_moving = false
	_alive = true
	_moveAction = null
	if startingWeapon != null:
		_currentWeapon = startingWeapon
	else:
		_currentWeapon = _defaultWeapon
	_hitPointsRemaining = playerCharacter.startingHealth
	_playerUi.setup(playerCharacter)
	Game.setPlayer(self)
	EventBus.releasePlayerTarget.connect(_clearFireTarget)

func stopCameraMove(actionToFinish : EncounterAction):
	_moving = false
	currentPathFollow = null
	print('stop')
	if actionToFinish != null:
		actionToFinish.finish()

func getCurrentFireType() -> Enums.WEAPON_FIRE_TYPE:
	if _currentWeapon == null || _currentWeapon.fireType == null:
		return Enums.WEAPON_FIRE_TYPE.NONE
	return _currentWeapon.fireType

func _physics_process(delta: float) -> void:
	if !_moving or currentPathFollow == null:
		return

	# Advance follower a small step to produce a target point ahead
	currentPathFollow.progress += moveSpeed * delta
	_moveTarget = currentPathFollow.global_position

	#var toTarget = _moveTarget - global_position
	#if toTarget.length() > 0.004:
		#velocity = toTarget.normalized() * moveSpeed
		#look_at(_moveTarget)
		#move_and_slide()
	#else:
		#velocity = Vector3.ZERO
	#	if (_moveAction != null && is_instance_valid(_moveAction)):
	#		_moveAction.finish()

func startCameraMove(pathToFollow: Path3D, newMoveAction : MoveCameraAction) -> void:
	currentPath = pathToFollow
	_moveAction = newMoveAction
	if is_instance_valid(currentPathFollow):
		currentPathFollow.queue_free()
	currentPathFollow = PathFollow3D.new()
	currentPathFollow.loop = false
	currentPathFollow.progress = 0.0
	currentPath.add_child(currentPathFollow)
	_moveTarget = currentPathFollow.global_position
	_moving = true

func _input(event):
	var eventConsumed : bool = false
	if event.is_action("ui_cancel"):
		_clearFireTarget()
		eventConsumed = true
	if event.is_action_pressed("ui_accept") || event.is_action_pressed("ui_select") || Utils.isEventMidiNoteOnEvent(event):
		if _playerUi.dialogBox.showingDialog:
			_playerUi.dialogBox.showNextPage()
			var stillShowingDialog = _playerUi.dialogBox.showingDialog
			if stillShowingDialog == false:
				_playerUi.closeDialogBox()
				eventConsumed = true
		elif _playerUi._winning:
			_playerUi.closeWin()
			_playerUi.loadingContainer.show()
			eventConsumed = true
			Game.restartLevel()
		elif !_alive:
			_playerUi.closeGameOver()
			_playerUi.loadingContainer.show()
			eventConsumed = true
			Game.restartLevel()
	if event is InputEvent && _alive && !eventConsumed:
		_fireWeapon(event)
		eventConsumed = true

func _fireWeapon(event : InputEvent):
	if _currentWeapon.canFire(event):
		var firePayload : Variant = _currentWeapon.fire(event)
		if firePayload == null:
			return
		fireWeapon.emit(_currentWeapon.fireType, _currentFireTarget, firePayload)

func setCurrentEncounter(newEncounter : EncounterPoint) -> void:
	currentEncounter = newEncounter
	currentEncounter.startEncounter()

func _clearFireTarget() -> void:
	_currentFireTarget = null
	if _currentWeapon != null:
		_currentWeapon.rotation = Vector3.ZERO

func setFireTarget(newFireTarget : Enemy) -> void:
	_currentFireTarget = newFireTarget
	var targetPosition : Vector3 = newFireTarget.global_position
	_currentWeapon.look_at(Vector3(targetPosition.x, targetPosition.y + 1, targetPosition.z), Vector3.UP, false)

func win() -> void:
	_playerUi.win()

func showDialog(dialog : Dialog) -> void:
	_playerUi.showDialog(dialog)

func receiveHit():
	_hitPointsRemaining -= 1
	_playerUi.receiveDamage(1)
	if _hitPointsRemaining <= 0:
		_die()

func _die():
	_alive = false
	EventBus.wait.emit()
	_playerUi.showGameOver()
