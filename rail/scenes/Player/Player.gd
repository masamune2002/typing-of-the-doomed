extends CharacterBody3D

class_name Player

@export var moveSpeed: float = 8.0
@export var mouseSensitivity: float = 0.25
const GRAVITY : float = 20.0
const STEP_HEIGHT : float = 0.9
@export var playerCharacter : PlayerCharacter
@export var startingWeaponScene : PackedScene
@export var weaponScenes : Array[PackedScene] = []

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
var _currentWeaponScene : PackedScene
var currentPath : Path3D
var currentPathFollow : PathFollow3D
var currentEncounter : EncounterPoint
var _currentFireTarget : Node3D
var _moveTarget : Vector3
var _moveAction : EncounterAction
var _lookTween : Tween
var _rotH : float = 0.0
var _rotV : float = 0.0
const PITCH_LIMIT : float = 85.0
const DEFAULT_TRACKING_SPEED : float = 15.0
const RAIL_MAX_LEAD : float = 1.5  # Max XZ distance the rail cursor can lead the player
var trackingSpeed : float = DEFAULT_TRACKING_SPEED
var _railSpeed : float = 0.0
var _deathReady : bool = false  # True once death animation finishes and any key can restart
var _stuck_frames : int = 0  # Counts frames where rail cursor is blocked by walls
var _air_time : float = 0.0  # Seconds since the player last touched the floor
const AIR_CARRY_GRACE : float = 0.15   # Full rail speed for brief step-offs
const AIR_CARRY_FACTOR : float = 0.15  # Then straighten the fall

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_moving = false
	_alive = true
	_moveAction = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if startingWeaponScene != null:
		var weapon = startingWeaponScene.instantiate()
		weapon.transform = _defaultWeapon.transform
		_cameraRig.add_child(weapon)
		_currentWeapon = weapon
		_currentWeaponScene = startingWeaponScene
	else:
		_currentWeapon = _defaultWeapon
		_currentWeaponScene = null
	_health = playerCharacter.startingHealth
	_armor = playerCharacter.startingArmor
	_armorType = playerCharacter.startingArmorType
	_playerUi.setup(playerCharacter)
	_defaultWeapon.visible = false
	Game.setPlayer(self)
	add_to_group("player")
	EventBus.releasePlayerTarget.connect(_clearFireTarget)
	if SettingsManager.autoplay:
		interactPressed = true
		godMode = true

func reset() -> void:
	_moving = false
	_alive = true
	_moveAction = null
	_deathReady = false
	# The player body free-falls while idle behind the title screen or during
	# level transitions; carrying that velocity into a fresh spawn shoots the
	# body through the floor before the new map's colliders can catch it.
	velocity = Vector3.ZERO
	_air_time = 0.0
	_keys.clear()
	_clearFireTarget()
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Reset weapon to starting weapon
	if _currentWeapon != null and _currentWeapon != _defaultWeapon:
		_currentWeapon.queue_free()
	if startingWeaponScene != null:
		var weapon = startingWeaponScene.instantiate()
		weapon.transform = _defaultWeapon.transform
		_cameraRig.add_child(weapon)
		_currentWeapon = weapon
		_currentWeaponScene = startingWeaponScene
	else:
		_currentWeapon = _defaultWeapon
		_currentWeaponScene = null
	_health = playerCharacter.startingHealth
	_armor = playerCharacter.startingArmor
	_armorType = playerCharacter.startingArmorType
	_rotH = 0.0
	_rotV = 0.0
	_cameraRig.rotation_degrees = Vector3.ZERO
	_playerUi.setup(playerCharacter)
	_defaultWeapon.visible = false
	Game.setPlayer(self)

func hasWeapon(weaponScene : PackedScene) -> bool:
	return weaponScene in weaponScenes

func addWeapon(weaponScene : PackedScene) -> void:
	if not hasWeapon(weaponScene):
		weaponScenes.append(weaponScene)

func removeWeapon(weaponScene : PackedScene) -> void:
	weaponScenes.erase(weaponScene)

func stopCameraMove(actionToFinish : EncounterAction):
	_moving = false
	currentPathFollow = null
	if actionToFinish != null:
		actionToFinish.finish()

func getCurrentFireType() -> Enums.WEAPON_FIRE_TYPE:
	if _currentWeapon == null || _currentWeapon.fireType == null:
		return Enums.WEAPON_FIRE_TYPE.NONE
	return _currentWeapon.fireType

func isWasdActive() -> bool:
	# Movement keys only steer the player in debug free-move mode; walk
	# animations must not treat key presses as movement outside it.
	return SettingsManager.debug_wasd and not SettingsManager.debug_wasd_paused \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func isMoving() -> bool:
	# Actual motion — rail drive or real horizontal velocity — not key state.
	return _moving or Vector2(velocity.x, velocity.z).length() > 0.01

func _physics_process(delta: float) -> void:
	if !_alive:
		return

	# Continuously track the current fire target
	if _currentFireTarget != null and is_instance_valid(_currentFireTarget):
		_trackTarget(delta)

	# Rail path progress tracking
	var speed_mult := _speedMultiplier()
	if _moving and is_instance_valid(currentPathFollow):
		# Only advance the rail cursor if the player is close enough.
		# This prevents the rail from running ahead when the player is
		# blocked by a wall, which would trigger stations prematurely.
		var lead_dist := Vector2(
			global_position.x - currentPathFollow.global_position.x,
			global_position.z - currentPathFollow.global_position.z
		).length()
		if lead_dist < RAIL_MAX_LEAD:
			currentPathFollow.progress += _railSpeed * speed_mult * delta
			_stuck_frames = 0
		else:
			_stuck_frames += 1
		if currentPathFollow.progress_ratio >= 1.0:
			_moving = false
			if _moveAction != null:
				_moveAction.finish()
				_moveAction = null
			if currentPath is RailPath:
				var rail: RailPath = currentPath as RailPath
				var to_node = rail.get_node_or_null(rail.to_station)
				if to_node is RailStation:
					setCurrentEncounter(to_node)

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_air_time += delta
	else:
		velocity.y = 0
		_air_time = 0.0

	# Movement input: rail supplies direction when active, otherwise WASD
	var input_dir := Vector2.ZERO
	var move_dir := Vector3.ZERO
	if _moving and is_instance_valid(currentPathFollow):
		# Rail steers the player toward the path follow point
		var target_pos = currentPathFollow.global_position
		var dir = target_pos - global_position
		dir.y = 0
		var dist_to_follow := dir.length()
		if dist_to_follow > 0.01:
			dir = dir.normalized()
		# Never step past the follow point in a single tick: overshooting
		# flips the steering direction next frame, and the player visibly
		# jerks backward at path handoffs and on stair risers.
		var step_speed : float = minf(_railSpeed * speed_mult, dist_to_follow / delta)
		move_dir = dir * step_speed
		# On longer falls, drop nearly straight instead of arcing forward at
		# full rail speed: the horizontal carry otherwise lands the player on
		# ledge lips (e.g. a lift shaft's protruding ceiling-slab collider)
		# instead of the floor below. Brief airtime (stair edges, small
		# step-offs) keeps full momentum so ledge walk-offs still look natural.
		if not is_on_floor() and _air_time > AIR_CARRY_GRACE:
			move_dir *= AIR_CARRY_FACTOR
		# Fake input_dir so head bob and step-up work
		input_dir = Vector2(dir.x, dir.z).normalized()
	elif isWasdActive():
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

		move_dir = (forward * -input_dir.y + right * input_dir.x) * moveSpeed * speed_mult

	velocity.x = move_dir.x
	velocity.z = move_dir.z

	var pos_before := global_position
	move_and_slide()

	# Step-up: if a wall is blocking the intended direction, try stepping up.
	# The trigger must read the wall normal, not lost movement: a glancing
	# hit slides along the ledge and keeps most of its speed (cos^2 of the
	# approach angle), so a "barely moved" test only fires once the approach
	# is nearly head-on — until then the ledge feels like a wall.
	if is_on_wall() and input_dir != Vector2.ZERO:
		var wall_normal := get_wall_normal()
		var intended_dir := Vector3(move_dir.x, 0, move_dir.z).normalized()
		if wall_normal.dot(intended_dir) < -0.05 and _isClimbableStep(wall_normal):
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

	# Check for sector damage (nukage, lava, etc.)
	_checkFloorDamage()

func _isClimbableStep(wall_normal : Vector3) -> bool:
	# A step-up candidate is blocked at ankle height but clear at
	# STEP_HEIGHT, probed straight into the wall we are touching (so
	# glancing approaches test the riser too). This rules out tall walls
	# and, critically, deck edges: walking off a ledge grinds the capsule
	# against the slab side BELOW the lip, and a probe firing there resets
	# the walk-off every frame and wedges the player on the lip (E1M7
	# sector 35 deck drop). At a lip the ankle ray sees open air.
	var flat := Vector3(wall_normal.x, 0, wall_normal.z)
	if flat.length() < 0.3:
		return false
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var into := -flat.normalized() * 0.6  # capsule radius 0.3 + margin
	var low_from := global_position + Vector3(0, 0.15, 0)
	var low := PhysicsRayQueryParameters3D.create(low_from, low_from + into)
	low.collision_mask = 2
	low.exclude = [get_rid()]
	if space.intersect_ray(low).is_empty():
		return false
	var high_from := global_position + Vector3(0, STEP_HEIGHT + 0.05, 0)
	var high := PhysicsRayQueryParameters3D.create(high_from, high_from + into)
	high.collision_mask = 2
	high.exclude = [get_rid()]
	return space.intersect_ray(high).is_empty()

func _checkFloorDamage() -> void:
	if !is_on_floor():
		return
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return
	var from = global_position + Vector3(0, 0.1, 0)
	var to = global_position + Vector3(0, -1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # environment
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result["collider"]
	# The floor mesh's parent (MeshInstance3D) has the damage metadata
	var node = collider
	if node == null:
		return
	# Check the collider and its parent for damage metadata
	var damage_info: Dictionary = {}
	if node.has_meta("damage"):
		damage_info = node.get_meta("damage")
	elif node.get_parent() != null and node.get_parent().has_meta("damage"):
		damage_info = node.get_parent().get_meta("damage")
	if damage_info.is_empty() or not damage_info.has("amt"):
		return
	if damage_info["amt"] <= 0:
		return
	# Tick-based damage: only apply every N physics frames
	if damage_info.has("everyNframe") and damage_info["everyNframe"] > 0:
		if Engine.get_physics_frames() % damage_info["everyNframe"] != 0:
			return
	# Addon values are roughly half of DOOM's actual sector damage — scale up to match
	var doom_damage := int(damage_info["amt"]) * 2
	receiveHit(doom_damage)

func getMovementSpeedRatio() -> float:
	if _moving:
		return _railSpeed / moveSpeed
	return 1.0

func _speedMultiplier() -> float:
	if SettingsManager != null and SettingsManager.debug_superspeed:
		return 2.0
	return 1.0

func startCameraMove(pathToFollow: Path3D, newMoveAction : EncounterAction, railSpeed : float = -1.0) -> void:
	currentPath = pathToFollow
	_moveAction = newMoveAction
	_railSpeed = railSpeed if railSpeed > 0.0 else moveSpeed
	if is_instance_valid(currentPathFollow):
		currentPathFollow.queue_free()
	currentPathFollow = PathFollow3D.new()
	currentPathFollow.loop = false
	currentPathFollow.progress = 0.0
	currentPath.add_child(currentPathFollow)
	# At a turnaround station the player can stop slightly PAST the path
	# start (they trail the follow along the arrival direction). Start the
	# follow at the nearest curve point so the player is never dragged
	# backward to the station center; capped so a curve that loops back
	# near the player can't skip ahead.
	if currentPath.curve != null and currentPath.curve.get_baked_length() > 0.0:
		var closest := currentPath.curve.get_closest_offset(currentPath.to_local(global_position))
		currentPathFollow.progress = clampf(closest, 0.0, 2.0)
	_moveTarget = currentPathFollow.global_position
	_moving = true

func _input(event):
	# Mouse look (disabled when dead — camera is animating down)
	if _alive and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotH -= event.relative.x * mouseSensitivity
		_rotV -= event.relative.y * mouseSensitivity
		_rotV = clamp(_rotV, -PITCH_LIMIT, PITCH_LIMIT)
		_cameraRig.rotation_degrees = Vector3(_rotV, _rotH, 0)

	var eventConsumed : bool = false

	if event.is_action_pressed("cycle_target"):
		cycleTarget()
		eventConsumed = true
	elif event.is_action_pressed("clear_target"):
		_clearFireTarget()
		eventConsumed = true

	# Re-capture mouse on click
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		eventConsumed = true

	# Any key restarts when dead (after death animation completes)
	if !_alive and _deathReady and event is InputEventKey and event.pressed:
		_deathReady = false  # Prevent multiple restarts
		_playerUi.closeGameOver()
		eventConsumed = true
		set_process_input(false)
		Game.restartLevel()

	if event.is_action_pressed("ui_accept") || event.is_action_pressed("ui_select") || Utils.isEventMidiNoteOnEvent(event):
		if _playerUi.dialogBox.showingDialog:
			_playerUi.dialogBox.showNextPage()
			var stillShowingDialog = _playerUi.dialogBox.showingDialog
			if stillShowingDialog == false:
				_playerUi.closeDialogBox()
				eventConsumed = true
		elif _playerUi._winning:
			_playerUi.closeWin()
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
	if SettingsManager.autoplay and newEncounter is RailStation:
		var map_name = SettingsManager.autoplay_map
		print("[AUTOPLAY] Visited station: %s on %s" % [newEncounter.name, map_name])
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
	# Kill any active look tween so it doesn't fight with _trackTarget
	if _lookTween != null and _lookTween.is_running():
		_lookTween.kill()
		_rotH = _cameraRig.rotation_degrees.y

func _trackTarget(_delta: float) -> void:
	var targetPosition : Vector3 = _currentFireTarget.global_position
	_currentWeapon.look_at(Vector3(targetPosition.x, targetPosition.y + 1, targetPosition.z), Vector3.UP, false)
	# Smoothly rotate camera toward target
	var cam_pos = _cameraRig.global_position
	var dir = Vector3(targetPosition.x - cam_pos.x, 0, targetPosition.z - cam_pos.z).normalized()
	var target_yaw = rad_to_deg(atan2(-dir.x, -dir.z))
	# Normalize current yaw to [-180, 180) to prevent float drift
	var current_yaw = fmod(_cameraRig.rotation_degrees.y + 180.0, 360.0) - 180.0
	_cameraRig.rotation_degrees.y = current_yaw
	var diff = fmod(target_yaw - current_yaw + 180.0, 360.0) - 180.0
	_cameraRig.rotation_degrees.y = current_yaw + diff * clampf(trackingSpeed * _delta, 0.0, 1.0)
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
	# Get overlay labels
	var pips_label: Label3D = null
	var pips_defeated_label: Label3D = null
	var _typed_label: Label3D = null
	if node is Enemy:
		pips_label = node.pipsLabel
		pips_defeated_label = node.pipsDefeatedLabel
		_typed_label = node.typedLabel
	elif node is ExplodingBarrel:
		_typed_label = node.typedLabel
	elif node is Item:
		_typed_label = node.typedLabel
	elif node is Interactable:
		_typed_label = node.typedLabel
	if highlighted:
		# Targeted: turn label red, show full word
		label.modulate = Color.RED
		if node.has_method("showFullLabel"):
			node.showFullLabel()
		label.render_priority = 100
		label.no_depth_test = true
		if pips_label != null:
			pips_label.render_priority = 100
			pips_label.no_depth_test = true
		if pips_defeated_label != null:
			pips_defeated_label.render_priority = 101
			pips_defeated_label.no_depth_test = true
	else:
		# Not targeted: restore original color, show remaining chars
		label.render_priority = 10
		label.no_depth_test = true
		if pips_label != null:
			pips_label.render_priority = 10
			pips_label.no_depth_test = true
		if pips_defeated_label != null:
			pips_defeated_label.render_priority = 11
			pips_defeated_label.no_depth_test = true
		if node is Enemy:
			label.modulate = DoomGame.COLOR_WHITE
		elif node is ExplodingBarrel:
			label.modulate = DoomGame.COLOR_BARREL
		elif node is Item:
			match node.itemDefinition.get("effect", "health"):
				"health": label.modulate = DoomGame.COLOR_HEALTH
				"armor": label.modulate = DoomGame.COLOR_ARMOR
				"weapon": label.modulate = DoomGame.COLOR_WEAPON
		elif node is Interactable:
			label.modulate = DoomGame.COLOR_GOLD
		if node.has_method("showRemainingLabel"):
			node.showRemainingLabel()

func _getVisibleTargets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return targets

	# Close-in-front targets pass even when their anchor point has left the
	# frustum (door slab in your face, enemy at melee range): their entity
	# already reads visible via the same bypass and its label is pulled into
	# view, so the typing system must offer them too.
	for node in get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy:
			var enemy: Enemy = node
			if enemy.alive and enemy.active and !enemy.dying and enemy.visible_to_player:
				if _isOnScreen(camera, enemy.global_position + Vector3(0, 1.0, 0)) or Utils.labelCloseBypass(enemy):
					targets.append(enemy)

	for node in get_tree().get_nodes_in_group("Items"):
		if node is Item:
			if node.alive and node.active and node.visible_to_player:
				if _isOnScreen(camera, node.global_position + Vector3(0, 0.5, 0)) or Utils.labelCloseBypass(node):
					targets.append(node)

	for node in get_tree().get_nodes_in_group("Interactables"):
		if node is Interactable:
			if node.alive and node.active and node.visible_to_player:
				# Eye-level switches anchor their label (and visibility) at
				# camera height on the switch column — screen the candidate
				# at the same point, or a switch whose node sits on a ledge
				# floor (E1M2 S124) is never offered to the typing system.
				var anchor : Vector3 = node.global_position + Vector3(0, 1.0, 0)
				if node.eye_level_label:
					anchor.y = camera.global_position.y
				if _isOnScreen(camera, anchor) or Utils.labelCloseBypass(node):
					targets.append(node)

	for node in get_tree().get_nodes_in_group("Barrels"):
		if node is ExplodingBarrel:
			if node.alive and node.active and node.visible_to_player:
				if _isOnScreen(camera, node.global_position + Vector3(0, 0.5, 0)) or Utils.labelCloseBypass(node):
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

func lookAtPosition(targetPosition : Vector3, duration : float = 0.15) -> Tween:
	return _lookAtTarget(targetPosition, duration)

func _lookAtTarget(targetPosition : Vector3, duration : float = 0.15) -> Tween:
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
	_lookTween.tween_property(_cameraRig, "rotation_degrees:y", target_yaw, duration)
	_lookTween.tween_callback(func(): _rotH = _cameraRig.rotation_degrees.y)
	return _lookTween

func resetCamera(duration : float = 0.15) -> void:
	var target_yaw = _cameraRig.rotation_degrees.y
	if _moving and is_instance_valid(currentPathFollow):
		var forward = -currentPathFollow.global_transform.basis.z
		target_yaw = rad_to_deg(atan2(-forward.x, -forward.z))
		var current_yaw = _cameraRig.rotation_degrees.y
		var diff = fmod(target_yaw - current_yaw + 180.0, 360.0) - 180.0
		target_yaw = current_yaw + diff
	if _lookTween != null and _lookTween.is_running():
		_lookTween.kill()
	_lookTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lookTween.set_parallel(true)
	_lookTween.tween_property(_cameraRig, "rotation_degrees:y", target_yaw, duration)
	_lookTween.tween_property(_cameraRig, "rotation_degrees:x", 0.0, duration)
	_lookTween.set_parallel(false)
	_lookTween.tween_callback(func():
		_rotH = _cameraRig.rotation_degrees.y
		_rotV = _cameraRig.rotation_degrees.x
	)

func rotateByDegrees(yaw_delta: float, pitch_delta: float, duration : float = 0.15) -> void:
	var target_yaw = _cameraRig.rotation_degrees.y + yaw_delta
	var target_pitch = clamp(_cameraRig.rotation_degrees.x + pitch_delta, -PITCH_LIMIT, PITCH_LIMIT)
	if _lookTween != null and _lookTween.is_running():
		_lookTween.kill()
	_lookTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_lookTween.set_parallel(true)
	_lookTween.tween_property(_cameraRig, "rotation_degrees:y", target_yaw, duration)
	_lookTween.tween_property(_cameraRig, "rotation_degrees:x", target_pitch, duration)
	_lookTween.set_parallel(false)
	_lookTween.tween_callback(func():
		_rotH = _cameraRig.rotation_degrees.y
		_rotV = _cameraRig.rotation_degrees.x
	)

func win() -> void:
	_playerUi.win()

func showDialog(dialog : Dialog) -> void:
	_playerUi.showDialog(dialog)

var godMode : bool = false

func receiveHit(damage : int = 10) -> void:
	if !_alive or godMode or (SettingsManager != null and SettingsManager.debug_god_mode):
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
		Game.playSound(DoomGame.PLAYER_DEATH)
		_die()
	else:
		Game.playSound(DoomGame.PLAYER_PAIN)

func _getArmorAbsorption() -> float:
	match _armorType:
		Enums.ARMOR_TYPE.GREEN: return 1.0 / 3.0
		Enums.ARMOR_TYPE.BLUE: return 1.0 / 2.0
		_: return 0.0

func healHealth(amount : int, canOverheal : bool = false) -> void:
	var cap : int = playerCharacter.maxHealth if canOverheal else 100
	_health = mini(_health + amount, cap)
	_playerUi.updateStatus(_health, _armor, false)

func canPickUpItem(itemDef : Dictionary) -> bool:
	var effect = itemDef.get("effect", "")
	match effect:
		"health":
			var cap : int = playerCharacter.maxHealth if itemDef.get("overheal", false) else 100
			return _health < cap
		"armor":
			return _armor < playerCharacter.maxArmor
		"weapon":
			var weapon_scene = itemDef.get("weapon_scene")
			if weapon_scene != null:
				return not hasWeapon(weapon_scene)
			return true
		_:
			return true

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

func getState() -> Dictionary:
	var weapon_paths : Array[String] = []
	for ws in weaponScenes:
		if ws != null:
			weapon_paths.append(ws.resource_path)
	var current_weapon_path := ""
	if _currentWeaponScene != null:
		current_weapon_path = _currentWeaponScene.resource_path
	return {
		"health": _health,
		"armor": _armor,
		"armor_type": _armorType as int,
		"keys": _keys.duplicate(),
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"camera_rot_h": _rotH,
		"camera_rot_v": _rotV,
		"weapon_scenes": weapon_paths,
		"current_weapon": current_weapon_path,
	}

func restoreState(data: Dictionary) -> void:
	_health = data.get("health", 100)
	_armor = data.get("armor", 0)
	_armorType = int(data.get("armor_type", 0)) as Enums.ARMOR_TYPE
	_keys = []
	for k in data.get("keys", []):
		_keys.append(k)
		Game.setVar("key_" + k, true)
	_rotH = data.get("camera_rot_h", 0.0)
	_rotV = data.get("camera_rot_v", 0.0)
	_cameraRig.rotation_degrees = Vector3(_rotV, _rotH, 0)
	_playerUi.updateStatus(_health, _armor, false)
	_playerUi.updateKeys(_keys)
	# Restore weapon inventory
	var weapon_paths = data.get("weapon_scenes", [])
	if weapon_paths.size() > 0:
		weaponScenes.clear()
		for path in weapon_paths:
			if ResourceLoader.exists(path):
				weaponScenes.append(load(path))
	# Restore current weapon
	var current_wp = data.get("current_weapon", "")
	if current_wp != "" and ResourceLoader.exists(current_wp):
		var scene = load(current_wp)
		var weapon = scene.instantiate()
		weapon.transform = _defaultWeapon.transform
		if _currentWeapon != null and _currentWeapon != _defaultWeapon:
			_currentWeapon.queue_free()
		_cameraRig.add_child(weapon)
		_currentWeapon = weapon
		_currentWeaponScene = scene
		_playerUi.loadWeaponSprites(weapon)

func _die():
	_alive = false
	_deathReady = false
	EventBus.wait.emit()
	_clearFireTarget()
	# DOOM death animation: camera drops toward the floor
	var deathTween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	deathTween.tween_property(_cameraRig, "position:y", 0.2, 1.0)
	deathTween.tween_callback(func():
		_deathReady = true
	)
	_playerUi.showGameOver()
