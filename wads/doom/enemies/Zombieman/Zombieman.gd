extends Enemy
class_name Zombieman

# DOOM sprite naming: POSSxY where x=frame letter, Y=angle (1-8, 0=no rotation)
# A-B: Idle, C-D: Walk, E-F: Attack, G: Pain, H-L: Death (L=corpse)
const SPRITE_PREFIX = "POSS"
const IDLE_FRAMES = ["A", "B"]
const ATTACK_FRAMES = ["E", "F"]
const PAIN_FRAMES = ["G"]
const DEATH_FRAMES = ["H", "I", "J", "K", "L"]
# Frames that only have angle 0 (no rotation variants)
const ANGLE_ZERO_FRAMES = ["H", "I", "J", "K", "L"]
const PAIN_DURATION = 6.0 / 35.0
# DOOM runs at 35 ticks/sec, idle frames have Dur=10, death frames Dur=5
const FRAME_DURATION = 10.0 / 35.0  # ~0.286s per frame

@onready var sprite: Sprite3D = $Sprite3D

var _sprites: Dictionary = {}  # {"POSSA1": Texture2D, ...}
var _spriteFlip: Dictionary = {}  # {"POSSA6": true, ...} angles that need horizontal flip
var _currentAnimation: String = "idle"
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
var _spritesLoaded: bool = false
var _warned_sprites: Dictionary = {}
var _deathComplete: bool = false

func _ready() -> void:
	difficulty = 2
	numHealthBars = 1
	dying = false
	alive = true
	baseDamageMin = 5
	baseDamageMax = 10
	attackSound = "DSPISTOL"
	seeSound = "DSPOSIT1"
	painSound = "DSPOPAIN"
	deathSound = "DSPODTH1"
	activeSound = "DSPOSACT"

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
	var allFrames = IDLE_FRAMES + ATTACK_FRAMES + PAIN_FRAMES + DEATH_FRAMES
	
	# DOOM sprite naming: angles 2&8, 3&7, 4&6 share sprites (e.g. POSSA2A8)
	var anglePatterns = [
		{"name": "1", "angles": [1]},
		{"name": "2A8", "angles": [2, 8]},
		{"name": "3A7", "angles": [3, 7]},
		{"name": "4A6", "angles": [4, 6]},
		{"name": "5", "angles": [5]},
	]
	
	for frame in allFrames:
		if frame in ANGLE_ZERO_FRAMES:
			# These frames only have angle 0 (no rotation variants)
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
	
	# Fill in missing angles by falling back to nearest available angle
	# Some frames only have angles 1 and 5 (front/back)
	for frame in allFrames:
		if frame in ANGLE_ZERO_FRAMES:
			continue
		for angle in range(1, 9):
			var key = SPRITE_PREFIX + frame + str(angle)
			if not _sprites.has(key):
				# Front-facing angles (8,1,2,3) fall back to 1, back-facing (4,5,6,7) to 5
				var fallback_angle = 1 if angle in [1, 2, 3, 8] else 5
				var fallback_key = SPRITE_PREFIX + frame + str(fallback_angle)
				if _sprites.has(fallback_key):
					_sprites[key] = _sprites[fallback_key]
					if angle >= 6:
						_spriteFlip[key] = true

	_spritesLoaded = _sprites.size() > 0
	if _spritesLoaded:
		_updateSprite()

func _process(delta: float) -> void:
	if !_spritesLoaded or _deathComplete:
		return
	
	# Always face the player when active
	if active and alive:
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
		# Reposition sprite so bottom sits on the floor (texture height may vary per frame)
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size
	else:
		if not _warned_sprites.has(spriteName):
			_warned_sprites[spriteName] = true
			push_warning("Zombieman: sprite '%s' not found" % spriteName)

func _calculateAngleIndex() -> int:
	# Enemy always faces the player via look_at, so always show front view
	return 1

# Override base Enemy methods for sprite-based animation

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
	# The per-enemy died signal drives EnemyManager cleanup and the WAD
	# npc triggers (E1M8 barons -> tag-666 wall)
	died.emit(self)

	# Wait for death animation to complete
	var deathDuration = DEATH_FRAMES.size() * FRAME_DURATION
	await get_tree().create_timer(deathDuration).timeout

	# Lock to corpse sprite (POSSL0 - last frame of death sequence)
	_deathComplete = true
	var corpseKey = SPRITE_PREFIX + "L0"
	if _sprites.has(corpseKey):
		sprite.texture = _sprites[corpseKey]
		sprite.flip_h = false
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size

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
