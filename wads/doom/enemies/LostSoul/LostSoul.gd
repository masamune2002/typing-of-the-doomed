extends Enemy
class_name LostSoul

const SPRITE_PREFIX = "SKUL"
const IDLE_FRAMES = ["A", "B"]
const ATTACK_FRAMES = ["C", "D"]
const DEATH_FRAMES = ["E", "F", "G", "H", "I", "J"]
const ANGLE_ZERO_FRAMES = ["F", "G", "H", "I", "J"]
const FRAME_DURATION = 10.0 / 35.0

@onready var sprite: Sprite3D = $Sprite3D

var _sprites: Dictionary = {}
var _spriteFlip: Dictionary = {}
var _currentAnimation: String = "idle"
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
var _spritesLoaded: bool = false
var _deathComplete: bool = false

func _ready() -> void:
	difficulty = 2
	numHealthBars = 2
	dying = false
	alive = true
	baseDamageMin = 5
	baseDamageMax = 12
	attackSound = "DSSKLATK"
	seeSound = "DSSKLATK"
	painSound = "DSDMPAIN"
	deathSound = "DSFIRXDT"
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
	var allFrames = IDLE_FRAMES + ATTACK_FRAMES + DEATH_FRAMES
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
	var corpseKey = SPRITE_PREFIX + "J0"
	if _sprites.has(corpseKey):
		sprite.texture = _sprites[corpseKey]
		sprite.flip_h = false
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.01

func _process(delta: float) -> void:
	if !_spritesLoaded or _deathComplete:
		return
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
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.01

func _calculateAngleIndex() -> int:
	return 1

func activate() -> void:
	_currentAnimation = "idle"
	_currentFrameIndex = 0
	stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func die() -> void:
	_currentAnimation = "death"
	_currentFrameIndex = 0
	if deathSound != "":
		Game.playSoundAt(deathSound, self)
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
	var corpseKey = SPRITE_PREFIX + "J0"
	if _sprites.has(corpseKey):
		sprite.texture = _sprites[corpseKey]
		sprite.flip_h = false
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size - 0.01
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

func _attack(target: Player) -> void:
	if dying || !alive || !is_inside_tree():
		return
	if stateMachine.currentStateKey == Enums.ENEMY_STATE.ATTACKING:
		target.receiveHit(getDamage())
		stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func _getMesh() -> MeshInstance3D:
	return null
