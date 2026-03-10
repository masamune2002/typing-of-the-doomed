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
var _spriteFlip: Dictionary = {}  # {"POSSA6": true, ...} angles that need horizontal flip
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
	
	# DOOM sprite naming: angles 2&8, 3&7, 4&6 share sprites (e.g. POSSA2A8)
	var anglePatterns = [
		{"name": "1", "angles": [1]},
		{"name": "2A8", "angles": [2, 8]},
		{"name": "3A7", "angles": [3, 7]},
		{"name": "4A6", "angles": [4, 6]},
		{"name": "5", "angles": [5]},
	]
	
	for frame in allFrames:
		if frame == "M":
			# Death frame only has angle 0
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
					# Map this texture to all angles it covers
					for angle in pattern["angles"]:
						_sprites[SPRITE_PREFIX + frame + str(angle)] = texture
						# Mark which angles need flipping (6, 7, 8)
						if angle >= 6:
							_spriteFlip[SPRITE_PREFIX + frame + str(angle)] = true
	
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
	var spriteName = SPRITE_PREFIX + frame + str(angleIndex)
	
	if _sprites.has(spriteName):
		sprite.texture = _sprites[spriteName]
		sprite.flip_h = _spriteFlip.has(spriteName)
	else:
		print("Zombieman: sprite '", spriteName, "' not found. Available: ", _sprites.keys())

func _calculateAngleIndex() -> int:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return 1
	
	var toCamera = (camera.global_position - global_position).normalized()
	var forward = global_transform.basis.z.normalized()
	
	# Calculate angle between camera direction and enemy forward
	var angle = atan2(
		toCamera.x * forward.z - toCamera.z * forward.x,
		toCamera.x * forward.x + toCamera.z * forward.z
	)
	
	# Convert to DOOM's 8-angle system (1-8)
	# 1=front (enemy facing camera), 5=back (enemy facing away)
	var index = int(round(angle / (PI / 4.0))) + 1
	if index <= 0:
		index += 8
	while index > 8:
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
