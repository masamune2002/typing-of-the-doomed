extends Enemy
class_name Pinky

# DOOM sprite naming: SARGxY where x=frame letter, Y=angle (1-8, 0=no rotation)
# A-B: Idle, C-D: Walk, E-F-G: Attack (melee), H: Pain, I-N: Death (N=corpse)
const SPRITE_PREFIX = "SARG"
const IDLE_FRAMES = ["A", "B"]
const WALK_FRAMES = ["A", "B", "C", "D"]
const ATTACK_FRAMES = ["E", "F", "G"]
const PAIN_FRAMES = ["H"]
const DEATH_FRAMES = ["I", "J", "K", "L", "M", "N"]
# Engagement distance: pinkies stop and bite from here rather than walking
# into the player's face — up close the weakness label gets pulled around
# by the view clamping and is hard to read. Keep in sync with
# PinkyMoving.MELEE_RANGE.
const MELEE_RANGE := 4.5
const ANGLE_ZERO_FRAMES = ["I", "J", "K", "L", "M", "N"]
const PAIN_DURATION := 6.0 / 35.0
const FRAME_DURATION = 10.0 / 35.0

@onready var sprite: Sprite3D = $Sprite3D

var _sprites: Dictionary = {}
var _spriteFlip: Dictionary = {}
var _currentAnimation: String = "idle"
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
var _spritesLoaded: bool = false
var _warned_sprites: Dictionary = {}
var _deathComplete: bool = false

func _ready() -> void:
	difficulty = 3
	numHealthBars = 2
	dying = false
	alive = true
	baseDamageMin = 10
	baseDamageMax = 20
	attackSound = "DSSGTATK"
	seeSound = "DSSGTSIT"
	painSound = "DSDMPAIN"
	deathSound = "DSSGTDTH"
	activeSound = "DSDMACT"

	var midiScaleWeakness = MidiScaleWeakness.new()
	var typingWeakness = TypingWeakness.new()
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.MIDI, midiScaleWeakness)
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.TYPING, typingWeakness)
	for weakness: Weakness in weaknesses.values():
		weakness.setup(difficulty)

	add_to_group('Enemies')
	EventBus.enemySpawned.emit(self)

	enemyTargetLabel.hide()
	stateMachine.setState(Enums.ENEMY_STATE.INACTIVE)

	_tryLoadSprites()

func _tryLoadSprites() -> void:
	if Game.wadLoader == null or Game.wadLoader._loader == null:
		get_tree().process_frame.connect(_onProcessFrameRetryLoad, CONNECT_ONE_SHOT)
		return
	_loadSprites()

func _onProcessFrameRetryLoad() -> void:
	_tryLoadSprites()

func _loadSprites() -> void:
	var allFrames = IDLE_FRAMES + WALK_FRAMES + ATTACK_FRAMES + PAIN_FRAMES + DEATH_FRAMES

	var anglePatterns = [
		{"name": "1", "angles": [1]},
		{"name": "2A8", "angles": [2, 8]},
		{"name": "3A7", "angles": [3, 7]},
		{"name": "4A6", "angles": [4, 6]},
		{"name": "5", "angles": [5]},
	]

	for frame in allFrames:
		if frame in ANGLE_ZERO_FRAMES:
			var spriteName = SPRITE_PREFIX + frame + "0"
			var texture = Game.fetchSprite(spriteName)
			if texture != null:
				_sprites[spriteName] = texture
				for i in range(1, 9):
					_sprites[SPRITE_PREFIX + frame + str(i)] = texture
		else:
			for pattern in anglePatterns:
				var spriteName = SPRITE_PREFIX + frame + pattern["name"]
				var texture = Game.fetchSprite(spriteName)
				if texture != null:
					for angle in pattern["angles"]:
						_sprites[SPRITE_PREFIX + frame + str(angle)] = texture
						if angle >= 6:
							_spriteFlip[SPRITE_PREFIX + frame + str(angle)] = true

	for frame in allFrames:
		if frame in ANGLE_ZERO_FRAMES:
			continue
		for angle in range(1, 9):
			var key = SPRITE_PREFIX + frame + str(angle)
			if not _sprites.has(key):
				var fallback_angle = 1 if angle in [1, 2, 3, 8] else 5
				var fallback_key = SPRITE_PREFIX + frame + str(fallback_angle)
				if _sprites.has(fallback_key):
					_sprites[key] = _sprites[fallback_key]
					if angle >= 6:
						_spriteFlip[key] = true

	_spritesLoaded = _sprites.size() > 0
	if _spritesLoaded:
		_updateSprite()
	if _startDead:
		_showCorpse()

func _showCorpse() -> void:
	_deathComplete = true
	var corpseKey = SPRITE_PREFIX + "N0"
	if _sprites.has(corpseKey):
		sprite.texture = _sprites[corpseKey]
		sprite.flip_h = false
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.08

func _process(delta: float) -> void:
	if !_spritesLoaded or _deathComplete:
		return

	if active and alive:
		# Only face the player when idle or attacking, not when moving
		# (Moving state handles its own facing direction)
		if stateMachine.currentStateKey != Enums.ENEMY_STATE.MOVING:
			var player = Game.getPlayer()
			if player and is_instance_valid(player):
				look_at(player.global_position, Vector3.UP, true)

	_frameTimer += delta
	if _frameTimer >= FRAME_DURATION:
		_frameTimer = 0.0
		_advanceFrame()

	_updateSprite()

func _advanceFrame() -> void:
	var frames = _getFramesForAnimation()
	if frames.size() == 0:
		return
	_currentFrameIndex += 1
	if _currentFrameIndex >= frames.size():
		if _currentAnimation == "death":
			_currentFrameIndex = frames.size() - 1
		else:
			_currentFrameIndex = 0

func _getFramesForAnimation() -> Array:
	match _currentAnimation:
		"idle":
			return IDLE_FRAMES
		"walk":
			return WALK_FRAMES
		"attack":
			return ATTACK_FRAMES
		"pain":
			return PAIN_FRAMES
		"death":
			return DEATH_FRAMES
		_:
			return IDLE_FRAMES

func _updateSprite() -> void:
	var frames = _getFramesForAnimation()
	if frames.size() == 0 or _currentFrameIndex >= frames.size():
		return
	var frame = frames[_currentFrameIndex]
	var angleIndex = _calculateAngleIndex()
	var spriteName = SPRITE_PREFIX + frame + str(angleIndex)
	if _sprites.has(spriteName):
		sprite.texture = _sprites[spriteName]
		sprite.flip_h = _spriteFlip.has(spriteName)
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.08
	else:
		if not _warned_sprites.has(spriteName):
			_warned_sprites[spriteName] = true
			push_warning("Pinky: sprite '%s' not found" % spriteName)

func _calculateAngleIndex() -> int:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return 1
	# DOOM sprite angles: 1=front, 5=back, 3=right, 7=left
	# "Front" = camera sees the enemy's face
	# We need: from the camera's perspective, which side of the enemy are we seeing?
	# That's the angle between the enemy's forward and the camera-to-enemy direction.
	var enemy_forward = -global_transform.basis.z
	enemy_forward.y = 0
	if enemy_forward.length_squared() < 0.001:
		return 1
	enemy_forward = enemy_forward.normalized()
	var cam_to_enemy = (global_position - camera.global_position)
	cam_to_enemy.y = 0
	if cam_to_enemy.length_squared() < 0.001:
		return 1
	cam_to_enemy = cam_to_enemy.normalized()
	# Angle: 0 = camera looking at enemy's front, PI = looking at back
	var dot = enemy_forward.dot(cam_to_enemy)
	var cross_y = enemy_forward.cross(cam_to_enemy).y
	var angle = atan2(cross_y, dot)
	# Quantize to 8 directions (each 45 degrees)
	var sector = roundi(angle / (PI / 4.0)) % 8
	if sector < 0:
		sector += 8
	# sector 0=front, 1=front-right, 2=right, 3=back-right, 4=back, etc.
	return sector + 1  # DOOM uses 1-8

func playPain() -> void:
	if !alive or dying:
		return
	var prev_anim = _currentAnimation
	_currentAnimation = "pain"
	_currentFrameIndex = 0
	_updateSprite()
	await get_tree().create_timer(PAIN_DURATION).timeout
	if alive and !dying and _currentAnimation == "pain":
		_currentAnimation = prev_anim
		_currentFrameIndex = 0

func activate() -> void:
	_currentAnimation = "idle"
	_currentFrameIndex = 0
	stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func die() -> void:
	if deathSound != "":
		Game.playSoundAt(deathSound, self)
	_currentAnimation = "death"
	_currentFrameIndex = 0
	_startSpriteDeath()

func _startSpriteDeath() -> void:
	cancelTelegraph()
	dying = true
	alive = false
	startedDying.emit(self)
	enemyTargetLabel.hide()
	EventBus.releasePlayerTarget.emit()
	EventBus.enemyKilled.emit(self)

	var deathDuration = DEATH_FRAMES.size() * FRAME_DURATION
	await get_tree().create_timer(deathDuration).timeout

	_deathComplete = true
	var corpseKey = SPRITE_PREFIX + "N0"
	if _sprites.has(corpseKey):
		sprite.texture = _sprites[corpseKey]
		sprite.flip_h = false
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.08

	stateMachine.setState(Enums.ENEMY_STATE.DEAD)

func startAttack(target: Player) -> void:
	_currentAnimation = "attack"
	_currentFrameIndex = 0
	currentTarget = target
	stateMachine.setState(Enums.ENEMY_STATE.ATTACKING)

func telegraphAndAttackCurrentTarget() -> void:
	if !_canAttack():
		return
	cancelTelegraph()
	var token: int = _newAttackToken()
	_telegraphTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).bind_node(self)
	_telegraphTween.tween_property(sprite, "modulate", Color(2, 0.5, 0.5, 1), 1.0)
	_telegraphTween.tween_callback(func():
		_attackIfValid(token)
	)
	_telegraphTween.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	_telegraphTween.finished.connect(func():
		_telegraphTween = null
	)

func cancelTelegraph() -> void:
	_attackToken += 1
	if _telegraphTween != null && _telegraphTween.is_running():
		_telegraphTween.kill()
	_telegraphTween = null
	sprite.modulate = Color.WHITE

func _attack(target : Player) -> void:
	# The telegraph started while visible, but the player may have looked
	# away since — an off-screen pinky must not land hits the player never
	# saw coming. Reset to IDLE so the state machine doesn't stall.
	if !visible_to_player:
		if stateMachine.currentStateKey == Enums.ENEMY_STATE.ATTACKING:
			stateMachine.setState(Enums.ENEMY_STATE.IDLE)
		return
	super._attack(target)

func isMeleeOnly() -> bool:
	return true

func _getMesh() -> MeshInstance3D:
	return null
