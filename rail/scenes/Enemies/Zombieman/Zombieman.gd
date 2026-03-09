extends Enemy
class_name Zombieman

# DOOM sprite naming: POSSxY where x=frame (A-M), Y=angle (1-8, 0=no rotation)
# A-B: Idle, C-D: Walk, E-G: Attack, H: Pain, I-L: Death, M: Dead on ground
const SPRITE_PREFIX = "POSS"
const IDLE_FRAMES = ["A", "B"]
const ATTACK_FRAMES = ["E", "F", "G"]
const DEATH_FRAMES = ["I", "J", "K", "L", "M"]
const FRAME_DURATION = 0.15

@onready var sprite: Sprite3D = $Sprite3D

var _sprites: Dictionary = {}  # {"POSSA1": Texture2D, ...}
var _currentAnimation: String = "idle"
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
var _spritesLoaded: bool = false

func _ready() -> void:
	difficulty = 1
	dying = false
	alive = true
	
	# Setup weaknesses (from base Enemy)
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
	
	# Defer sprite loading until WAD is ready
	_tryLoadSprites()

func _tryLoadSprites() -> void:
	# Wait for WAD loader to be ready
	if Game.wadLoader == null or Game.wadLoader._loader == null:
		# Retry next frame
		get_tree().process_frame.connect(_onProcessFrameRetryLoad, CONNECT_ONE_SHOT)
		return
	_loadSprites()

func _onProcessFrameRetryLoad() -> void:
	_tryLoadSprites()

func _loadSprites() -> void:
	var allFrames = IDLE_FRAMES + ATTACK_FRAMES + DEATH_FRAMES
	
	for frame in allFrames:
		# Angles 1-5 for most frames (6-8 are mirrored), M only has angle 0
		var angles = ["1", "2", "3", "4", "5"]
		if frame == "M":
			angles = ["0"]
		
		for angle in angles:
			var spriteName = SPRITE_PREFIX + frame + angle
			var texture = Game.fetchSprite(spriteName)
			if texture != null:
				_sprites[spriteName] = texture
	
	_spritesLoaded = _sprites.size() > 0
	if _spritesLoaded:
		_updateSprite()

func _process(delta: float) -> void:
	if !_spritesLoaded:
		return
	
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
			# Stay on last frame
			_currentFrameIndex = frames.size() - 1
		else:
			_currentFrameIndex = 0

func _getFramesForAnimation() -> Array:
	match _currentAnimation:
		"idle":
			return IDLE_FRAMES
		"attack":
			return ATTACK_FRAMES
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
	
	# Handle final death frame (M) which only has angle 0
	var angleStr = str(angleIndex)
	if frame == "M":
		angleStr = "0"
	
	var spriteName = SPRITE_PREFIX + frame + angleStr
	
	# Handle mirrored sprites (angles 6-8 mirror 2-4)
	var shouldFlip = false
	if angleIndex >= 6 and frame != "M":
		# Mirror: 6->4, 7->3, 8->2
		var mirroredAngle = 10 - angleIndex
		var mirroredName = SPRITE_PREFIX + frame + str(mirroredAngle)
		if _sprites.has(mirroredName):
			spriteName = mirroredName
			shouldFlip = true
	
	if _sprites.has(spriteName):
		sprite.texture = _sprites[spriteName]
		sprite.flip_h = shouldFlip

func _calculateAngleIndex() -> int:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return 1
	
	var toCamera = (camera.global_position - global_position).normalized()
	var forward = -global_transform.basis.z.normalized()
	
	# Calculate angle between camera direction and enemy forward
	var angle = atan2(
		toCamera.x * forward.z - toCamera.z * forward.x,
		toCamera.x * forward.x + toCamera.z * forward.z
	)
	
	# Convert to DOOM's 8-angle system (1-8)
	# 1=front, 2=front-right, 3=right, 4=back-right, 5=back, etc.
	var index = int(round(angle / (PI / 4.0))) + 1
	if index <= 0:
		index += 8
	if index > 8:
		index -= 8
	
	return index

# Override base Enemy methods for sprite-based animation

func activate() -> void:
	_currentAnimation = "idle"
	_currentFrameIndex = 0
	stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func die() -> void:
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
	
	# Wait for death animation to complete
	var deathDuration = DEATH_FRAMES.size() * FRAME_DURATION
	await get_tree().create_timer(deathDuration).timeout
	stateMachine.setState(Enums.ENEMY_STATE.DEAD)

func startAttack(target: Player) -> void:
	_currentAnimation = "attack"
	_currentFrameIndex = 0
	currentTarget = target
	stateMachine.setState(Enums.ENEMY_STATE.ATTACKING)

# Override telegraph for sprite-based enemies (no mesh material to tint)
func telegraphAndAttackCurrentTarget() -> void:
	if !_canAttack():
		return
	
	cancelTelegraph()
	var token: int = _newAttackToken()
	
	# Simple telegraph using modulate color on sprite
	_telegraphTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).bind_node(self)
	
	# Flash red
	_telegraphTween.tween_property(sprite, "modulate", Color(2, 0.5, 0.5, 1), 1.0)
	
	# Attack at peak
	_telegraphTween.tween_callback(func():
		_attackIfValid(token)
	)
	
	# Return to normal
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

func _getMesh() -> MeshInstance3D:
	# No mesh for sprite-based enemies
	return null
