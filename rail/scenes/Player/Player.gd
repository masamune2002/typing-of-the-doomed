extends CharacterBody3D

class_name Player

@export var moveSpeed: float = 12.0
@export var mouseSensitivity: float = 0.25
const GRAVITY : float = 20.0
const STEP_HEIGHT : float = 0.9
@export var playerCharacter : PlayerCharacter
@export var startingWeapon : Weapon

@onready var _defaultWeapon : Weapon = $CameraRig/TypingGun
@onready var _playerUi : PlayerUI = $Hud
@onready var _cameraRig : Node3D = $CameraRig

signal fireWeapon(weapon : Enums.WEAPON_FIRE_TYPE, target : Node3D, payload : Variant)

var _alive : bool
var _health : int
var _armor : int
var _armorType : Enums.ARMOR_TYPE
var _moving : bool
var _keys : Array[String] = []

var interactPressed : bool = false  # Required by WAD interactables (lifts, doors, etc.)
var _currentWeapon : Weapon
var currentPath : Path3D
var currentPathFollow : PathFollow3D
var currentEncounter : EncounterPoint
var _currentFireTarget : Node3D
var _moveTarget : Vector3
var _moveAction : MoveCameraAction
var _lookTween : Tween
var _rotH : float = 0.0
var _rotV : float = 0.0
const PITCH_LIMIT : float = 85.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_moving = false
	_alive = true
	_moveAction = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if startingWeapon != null:
		_currentWeapon = startingWeapon
	else:
		_currentWeapon = _defaultWeapon
	_health = playerCharacter.startingHealth
	_armor = playerCharacter.startingArmor
	_armorType = playerCharacter.startingArmorType
	_playerUi.setup(playerCharacter)
	_defaultWeapon.visible = false
	Game.setPlayer(self)
	add_to_group("player")
	EventBus.releasePlayerTarget.connect(_clearFireTarget)

func stopCameraMove(actionToFinish : EncounterAction):
	_moving = false
	currentPathFollow = null
	if actionToFinish != null:
		actionToFinish.finish()

func getCurrentFireType() -> Enums.WEAPON_FIRE_TYPE:
	if _currentWeapon == null || _currentWeapon.fireType == null:
		return Enums.WEAPON_FIRE_TYPE.NONE
	return _currentWeapon.fireType

func _physics_process(delta: float) -> void:
	if !_alive:
		return

	# Continuously track the current fire target
	if _currentFireTarget != null and is_instance_valid(_currentFireTarget):
		_trackTarget(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	# WASD movement relative to camera yaw
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("backward"):
		input_dir.y += 1
	if Input.is_action_pressed("strafeLeft"):
		input_dir.x -= 1
	if Input.is_action_pressed("strafeRight"):
		input_dir.x += 1
	input_dir = input_dir.normalized()

	var forward := -_cameraRig.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := _cameraRig.global_transform.basis.x
	right.y = 0
	right = right.normalized()

	var move_dir := (forward * -input_dir.y + right * input_dir.x) * moveSpeed
	velocity.x = move_dir.x
	velocity.z = move_dir.z

	var pos_before := global_position
	move_and_slide()

	# Step-up: if we barely moved in the intended direction, try stepping up
	if is_on_wall() and input_dir != Vector2.ZERO:
		var intended_dir := Vector2(move_dir.x, move_dir.z).normalized()
		var actual_move := Vector2(global_position.x - pos_before.x, global_position.z - pos_before.z)
		var moved_along_intended := actual_move.dot(intended_dir)
		var expected_xz := Vector2(move_dir.x, move_dir.z).length() * get_physics_process_delta_time() * 0.5
		if moved_along_intended < expected_xz:
			# Reset to before the failed move
			global_position = pos_before
			# Try: move up, move forward, move down
			var y_before := global_position.y
			move_and_collide(Vector3(0, STEP_HEIGHT, 0))
			velocity.x = move_dir.x
			velocity.z = move_dir.z
			velocity.y = 0
			move_and_slide()
			# Snap back down to floor
			move_and_collide(Vector3(0, -STEP_HEIGHT, 0))
			# If we ended up lower than where we started, we vaulted over
			# a wall instead of stepping onto a higher floor — revert
			if global_position.y < y_before - 0.01:
				global_position = pos_before

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
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotH -= event.relative.x * mouseSensitivity
		_rotV -= event.relative.y * mouseSensitivity
		_rotV = clamp(_rotV, -PITCH_LIMIT, PITCH_LIMIT)
		_cameraRig.rotation_degrees = Vector3(_rotV, _rotH, 0)

	var eventConsumed : bool = false

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_clearFireTarget()
		eventConsumed = true

	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		cycleTarget()
		eventConsumed = true

	# Re-capture mouse on click
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	if _currentFireTarget != null and is_instance_valid(_currentFireTarget):
		_setTargetHighlight(_currentFireTarget, false)
	_currentFireTarget = null
	if _currentWeapon != null:
		_currentWeapon.rotation = Vector3.ZERO

func setFireTarget(newTarget : Node3D) -> void:
	if _currentFireTarget != newTarget and _currentFireTarget != null and is_instance_valid(_currentFireTarget):
		_setTargetHighlight(_currentFireTarget, false)
	_currentFireTarget = newTarget
	_setTargetHighlight(newTarget, true)

func _trackTarget(_delta: float) -> void:
	var targetPosition : Vector3 = _currentFireTarget.global_position
	_currentWeapon.look_at(Vector3(targetPosition.x, targetPosition.y + 1, targetPosition.z), Vector3.UP, false)
	# Smoothly rotate camera toward target
	var cam_pos = _cameraRig.global_position
	var dir = Vector3(targetPosition.x - cam_pos.x, 0, targetPosition.z - cam_pos.z).normalized()
	var target_yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	var current_yaw = _cameraRig.rotation_degrees.y
	var diff = fmod(target_yaw - current_yaw + 180.0, 360.0) - 180.0
	_cameraRig.rotation_degrees.y = current_yaw + diff * clampf(15.0 * _delta, 0.0, 1.0)
	_rotH = _cameraRig.rotation_degrees.y

func _getTargetLabel(node : Node3D) -> Label3D:
	if node == null or !is_instance_valid(node):
		return null
	if node is Enemy:
		return node.enemyTargetLabel
	if node is Item:
		return node.itemLabel
	if node is Interactable:
		return node.interactableLabel
	if node is ExplodingBarrel:
		return node.barrelLabel
	return null

func _setTargetHighlight(node : Node3D, highlighted : bool) -> void:
	var label = _getTargetLabel(node)
	if label == null:
		return
	if highlighted:
		label.modulate = Color.RED
		label.render_priority = 100
		label.no_depth_test = true
	else:
		label.render_priority = 0
		label.no_depth_test = false
		# Restore original color
		if node is Enemy:
			label.modulate = Color.WHITE
		elif node is Item:
			match node.itemDefinition.get("effect", "health"):
				"health": label.modulate = Color(0.2, 1.0, 0.2)
				"armor": label.modulate = Color(0.2, 0.5, 1.0)
		elif node is Interactable:
			label.modulate = Color(1.0, 0.8, 0.2)
		elif node is ExplodingBarrel:
			label.modulate = Color(1.0, 0.4, 0.1)

func _getVisibleTargets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return targets

	for node in get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy:
			var enemy: Enemy = node
			if enemy.alive and enemy.active and !enemy.dying and enemy.visible_to_player:
				if _isOnScreen(camera, enemy.global_position + Vector3(0, 1.0, 0)):
					targets.append(enemy)

	for node in get_tree().get_nodes_in_group("Items"):
		if node is Item:
			if node.alive and node.active and node.visible_to_player:
				if _isOnScreen(camera, node.global_position + Vector3(0, 0.5, 0)):
					targets.append(node)

	for node in get_tree().get_nodes_in_group("Interactables"):
		if node is Interactable:
			if node.alive and node.active and node.visible_to_player:
				if _isOnScreen(camera, node.global_position + Vector3(0, 1.0, 0)):
					targets.append(node)

	for node in get_tree().get_nodes_in_group("Barrels"):
		if node is ExplodingBarrel:
			if node.alive and node.active and node.visible_to_player:
				if _isOnScreen(camera, node.global_position + Vector3(0, 0.5, 0)):
					targets.append(node)

	# Sort by distance (closest first)
	targets.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return targets

func _isOnScreen(camera : Camera3D, world_pos : Vector3) -> bool:
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos := camera.unproject_position(world_pos)
	var viewport_size := get_viewport().get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y

func cycleTarget() -> void:
	var targets := _getVisibleTargets()
	if targets.is_empty():
		return
	var current_idx = targets.find(_currentFireTarget)
	var next_idx = (current_idx + 1) % targets.size()
	setFireTarget(targets[next_idx])

func lookAtPosition(targetPosition : Vector3) -> void:
	_lookAtTarget(targetPosition)

func _lookAtTarget(targetPosition : Vector3) -> void:
	var cam_pos = _cameraRig.global_position
	var dir = Vector3(targetPosition.x - cam_pos.x, 0, targetPosition.z - cam_pos.z).normalized()
	var target_yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	# Ensure we rotate the short way around by adjusting target relative to current yaw
	var current_yaw = _cameraRig.rotation_degrees.y
	var diff = fmod(target_yaw - current_yaw + 180.0, 360.0) - 180.0
	target_yaw = current_yaw + diff
	if _lookTween != null and _lookTween.is_running():
		_lookTween.kill()
	_lookTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lookTween.tween_property(_cameraRig, "rotation_degrees:y", target_yaw, 0.15)
	_lookTween.tween_callback(func(): _rotH = _cameraRig.rotation_degrees.y)

func win() -> void:
	_playerUi.win()

func showDialog(dialog : Dialog) -> void:
	_playerUi.showDialog(dialog)

var godMode : bool = true

func receiveHit(damage : int = 10) -> void:
	if godMode:
		return
	var armorAbsorption : float = _getArmorAbsorption()
	var armorDamage : int = 0
	if _armor > 0 and armorAbsorption > 0.0:
		armorDamage = mini(ceili(damage * armorAbsorption), _armor)
	var healthDamage : int = damage - armorDamage
	_armor = maxi(0, _armor - armorDamage)
	_health = maxi(0, _health - healthDamage)
	if _armor <= 0:
		_armorType = Enums.ARMOR_TYPE.NONE
	_playerUi.updateStatus(_health, _armor, true)
	if _health <= 0:
		_die()

func _getArmorAbsorption() -> float:
	match _armorType:
		Enums.ARMOR_TYPE.GREEN: return 1.0 / 3.0
		Enums.ARMOR_TYPE.BLUE: return 1.0 / 2.0
		_: return 0.0

func healHealth(amount : int, canOverheal : bool = false) -> void:
	var cap : int = playerCharacter.maxHealth if canOverheal else 100
	_health = mini(_health + amount, cap)
	_playerUi.updateStatus(_health, _armor, false)

func addArmor(amount : int, type : Enums.ARMOR_TYPE = Enums.ARMOR_TYPE.NONE) -> void:
	if type != Enums.ARMOR_TYPE.NONE:
		_armorType = type
	_armor = mini(_armor + amount, playerCharacter.maxArmor)
	_playerUi.updateStatus(_health, _armor, false)

func addKey(key_name: String) -> void:
	if key_name not in _keys:
		_keys.append(key_name)
		_playerUi.updateKeys(_keys)

func flashPickup() -> void:
	_playerUi.flashPickup()

func _die():
	_alive = false
	EventBus.wait.emit()
	_playerUi.showGameOver()
