extends EnemyState
class_name PinkyMoving

# DOOM Pinky speed: 10 map units per tic, 35 tics/sec = 350 units/sec
# Our scale: DOOM map units * scaleFactor. Adjust to feel right in-game.
const MOVE_SPEED := 5.0
const MELEE_RANGE := 4.5  # keep in sync with Pinky.MELEE_RANGE
const GRAVITY := 20.0
const CHASE_SOUND_CHANCE := 0.03  # 3% per tic, checked each physics frame
# DOOM monsters never walk off drops taller than 24 map units (~0.91 world
# units at the WAD y-scale) — without this, chasing pinkies walk straight
# into nukage pits and are stuck there for the rest of the level.
const MAX_DROP := 1.0

# 8 cardinal+diagonal directions (matching DOOM's DI_ enum)
const DIRECTIONS = [
	Vector3(1, 0, 0),    # 0: East
	Vector3(1, 0, -1),   # 1: NE
	Vector3(0, 0, -1),   # 2: North
	Vector3(-1, 0, -1),  # 3: NW
	Vector3(-1, 0, 0),   # 4: West
	Vector3(-1, 0, 1),   # 5: SW
	Vector3(0, 0, 1),    # 6: South
	Vector3(1, 0, 1),    # 7: SE
]

var _target : Player
var _move_dir : int = -1  # Current direction index (0-7), -1 = no direction
var _move_count : int = 0  # Tics remaining in current direction
var _just_attacked : bool = false

func _ready() -> void:
	key = Enums.ENEMY_STATE.MOVING
	displayName = 'Moving'

func enter(previousState: Enums.ENEMY_STATE) -> void:
	_target = Game.getPlayer()
	if parent is Pinky:
		parent._currentAnimation = "walk"
		parent._currentFrameIndex = 0
	_just_attacked = (previousState == Enums.ENEMY_STATE.ATTACKING)
	if _just_attacked:
		# Post-attack: face the player for a beat before resuming chase
		_move_count = 8
		_move_dir = -1

func exit(_newState: Enums.ENEMY_STATE) -> void:
	parent.velocity = Vector3.ZERO
	_target = null

func _physics_process(delta: float) -> void:
	if parent.stateMachine.currentState != self:
		return
	if _target == null or !is_instance_valid(_target) or !parent.alive or parent.dying:
		return

	# Freeze while off-screen: an unseen pinky can't be typed at, so it
	# must not close in or attack from behind. It resumes the moment the
	# player can see it again. Same freeze while pain-stunned.
	if !parent.visible_to_player or parent.stunned:
		parent.velocity.x = 0
		parent.velocity.z = 0
		if not parent.is_on_floor():
			parent.velocity.y -= GRAVITY * delta
		else:
			parent.velocity.y = 0
		parent.move_and_slide()
		return

	# Check melee range. Inside MIN_RANGE the player is too close for the
	# weakness label to be readable (the rail can carry them right into a
	# pinky's face), so back away first and only bite from the band between
	# MIN_RANGE and MELEE_RANGE.
	var distance = parent.global_position.distance_to(_target.global_position)
	var too_close = distance < Pinky.MIN_RANGE
	if !too_close and distance <= MELEE_RANGE and _hasLineOfSight():
		parent.velocity = Vector3.ZERO
		parent.startAttack(_target)
		return

	if too_close:
		_just_attacked = false  # never stand still in the player's face
		if !_ensureRetreatDir():
			# Cornered — nowhere to back away to, so bite from here.
			if distance <= MELEE_RANGE and _hasLineOfSight():
				parent.velocity = Vector3.ZERO
				parent.startAttack(_target)
				return

	# Post-attack pause: face player, don't move
	if _just_attacked:
		parent.look_at(_target.global_position, Vector3.UP, true)
		_move_count -= 1
		if _move_count <= 0:
			_just_attacked = false
		# Apply gravity even when paused
		if not parent.is_on_floor():
			parent.velocity.y -= GRAVITY * delta
		else:
			parent.velocity.y = 0
		parent.velocity.x = 0
		parent.velocity.z = 0
		parent.move_and_slide()
		return

	# Decrement move count; pick new direction when it expires or blocked
	_move_count -= 1
	if _move_count < 0:
		_pickNewChaseDir(too_close)

	# Try to move in current direction
	if _move_dir >= 0 and _move_dir < DIRECTIONS.size():
		var dir = DIRECTIONS[_move_dir].normalized()
		# Stop at ledges mid-run: the pick-time probe looks one step ahead,
		# but a long straight run can still reach an edge between picks.
		if parent.is_on_floor() and _isLedgeAhead(dir, 0.4):
			parent.velocity.x = 0
			parent.velocity.z = 0
			_move_dir = -1
			_move_count = 0
		else:
			parent.velocity.x = dir.x * MOVE_SPEED
			parent.velocity.z = dir.z * MOVE_SPEED

			if too_close:
				# Backing off: keep facing the player, don't turn tail
				parent.look_at(_target.global_position, Vector3.UP, true)
			else:
				# Face movement direction
				var look_target = parent.global_position + dir
				parent.look_at(look_target, Vector3.UP, true)
	else:
		parent.velocity.x = 0
		parent.velocity.z = 0

	# Apply gravity
	if not parent.is_on_floor():
		parent.velocity.y -= GRAVITY * delta
	else:
		parent.velocity.y = 0

	var pos_before = parent.global_position
	parent.move_and_slide()

	# If barely moved (blocked by wall), pick a new direction immediately
	var moved = parent.global_position.distance_to(pos_before)
	if moved < MOVE_SPEED * delta * 0.3 and _move_dir >= 0:
		_pickNewChaseDir(too_close)

	# Random chase sound
	if randf() < CHASE_SOUND_CHANCE * delta * 35.0:
		Game.playSoundAt(DoomGame.DEMON_ACTIVE, parent)

# Keeps the current direction while it still leads away from the player,
# otherwise picks a fresh retreat direction. Returns false when every
# escape route is blocked (walls/ledges) — the caller may bite instead.
func _ensureRetreatDir() -> bool:
	var away = parent.global_position - _target.global_position
	away.y = 0
	if _move_dir >= 0 and away.length() > 0.001 \
			and DIRECTIONS[_move_dir].normalized().dot(away.normalized()) > 0.0:
		return true
	_pickNewChaseDir(true)
	return _move_dir >= 0

func _pickNewChaseDir(away : bool = false) -> void:
	if _target == null:
		return
	var delta_pos = _target.global_position - parent.global_position
	if away:
		delta_pos = -delta_pos
	# From here on delta_pos points where the pinky wants to go: toward the
	# player when chasing, directly away when retreating.
	var dx = delta_pos.x
	var dz = delta_pos.z

	# Determine ideal horizontal and vertical directions
	var dir_h := -1  # Horizontal direction toward player
	var dir_v := -1  # Vertical direction toward player

	if dx > 0.5:
		dir_h = 0  # East
	elif dx < -0.5:
		dir_h = 4  # West

	if dz > 0.5:
		dir_v = 6  # South (+Z)
	elif dz < -0.5:
		dir_v = 2  # North (-Z)

	# Determine diagonal
	var dir_diag := -1
	if dir_h >= 0 and dir_v >= 0:
		# Diagonal is between the two cardinal directions
		if dir_h == 0 and dir_v == 2: dir_diag = 1    # NE
		elif dir_h == 4 and dir_v == 2: dir_diag = 3   # NW
		elif dir_h == 4 and dir_v == 6: dir_diag = 5   # SW
		elif dir_h == 0 and dir_v == 6: dir_diag = 7   # SE

	# Randomly try horizontal or vertical first (creates zigzag)
	var try_dirs : Array[int] = []
	if randf() < 0.5:
		if dir_h >= 0: try_dirs.append(dir_h)
		if dir_v >= 0: try_dirs.append(dir_v)
	else:
		if dir_v >= 0: try_dirs.append(dir_v)
		if dir_h >= 0: try_dirs.append(dir_h)

	# Add diagonal
	if dir_diag >= 0:
		try_dirs.append(dir_diag)

	# Add random sweep directions for when ideal ones are blocked
	var sweep_start = randi_range(0, 7)
	for i in 8:
		var d = (sweep_start + i) % 8
		if d not in try_dirs:
			try_dirs.append(d)

	# Pick first valid direction (check for walls)
	var desired = Vector3(dx, 0, dz)
	for d in try_dirs:
		# When retreating, the sweep fallback must not send the pinky back
		# toward the player — sideways is fine, closing in is not.
		if away and desired.length() > 0.001 \
				and DIRECTIONS[d].normalized().dot(desired.normalized()) < 0.0:
			continue
		if _isDirectionClear(d):
			_move_dir = d
			_move_count = randi_range(0, 15)
			return

	_move_dir = -1
	_move_count = 0

func _isDirectionClear(dir_index: int) -> bool:
	var dir = DIRECTIONS[dir_index].normalized()
	var space_state = parent.get_world_3d().direct_space_state
	if space_state == null:
		return true
	var from = parent.global_position + Vector3(0, 0.5, 0)
	var to = from + dir * 1.0
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2 | 16  # walls + blocking-line bars
	query.exclude = [parent.get_rid()]
	var result = space_state.intersect_ray(query)
	if !result.is_empty():
		return false
	# No wall — but don't pick a direction that walks off a ledge
	return !_isLedgeAhead(dir, 1.0)

func _isLedgeAhead(dir: Vector3, ahead: float) -> bool:
	var space_state = parent.get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = parent.global_position + dir * ahead + Vector3(0, 0.3, 0)
	var to = from + Vector3(0, -(0.3 + MAX_DROP), 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [parent.get_rid()]
	return space_state.intersect_ray(query).is_empty()

func _hasLineOfSight() -> bool:
	var space_state = parent.get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = parent.global_position + Vector3(0, 0.5, 0)
	var to = _target.global_position + Vector3(0, 0.85, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [parent.get_rid(), _target.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()
