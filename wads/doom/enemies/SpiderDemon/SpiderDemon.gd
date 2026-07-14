extends Enemy
class_name SpiderDemon

const SPRITE_PREFIX = "SPID"
const IDLE_FRAMES = ["A", "B"]
const ATTACK_FRAMES = ["G", "H"]
const PAIN_FRAMES = ["I"]
const DEATH_FRAMES = ["J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"]
const ANGLE_ZERO_FRAMES = ["J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"]
const PAIN_DURATION = 6.0 / 35.0
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
	difficulty = 5
	numHealthBars = 8
	dying = false
	alive = true
	baseDamageMin = 5
	baseDamageMax = 10
	attackSound = "DSSHOTGN"
	seeSound = "DSSPISIT"
	painSound = "DSDMPAIN"
	deathSound = "DSSPIDTH"
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
	# Scan all WAD lumps matching our prefix and parse frame+angle pairs.
	# Handles multi-frame combined lumps like SPIDA1D1 (frames A and D share angle 1)
	# and same-frame multi-angle lumps like SPIDA2A8 (frame A at angles 2 and 8).
	var allWadKeys = Game.wadLoader._loader.get_node("ResourceManager").get_parent().flatTextureEntries.keys()
	for k in allWadKeys:
		var key = str(k)
		if !key.begins_with(SPRITE_PREFIX):
			continue
		var texture = Game.fetchSprite(key)
		if texture == null:
			continue
		# Parse suffix into (frame_letter, angle_digit) pairs
		var suffix = key.substr(SPRITE_PREFIX.length())
		var pairs = []
		var i = 0
		while i + 1 < suffix.length():
			pairs.append({"frame": suffix[i], "angle": int(suffix[i + 1])})
			i += 2
		# Track which angles each frame has in this lump (for flip detection)
		var frame_angles = {}
		for p in pairs:
			if not frame_angles.has(p.frame):
				frame_angles[p.frame] = []
			frame_angles[p.frame].append(p.angle)
		# Store each frame+angle entry
		for p in pairs:
			var frame = p.frame
			var angle = p.angle
			if angle == 0:
				_sprites[SPRITE_PREFIX + frame + "0"] = texture
				for a in range(1, 9):
					_sprites[SPRITE_PREFIX + frame + str(a)] = texture
			else:
				var sprKey = SPRITE_PREFIX + frame + str(angle)
				_sprites[sprKey] = texture
				# Flip only if this is a mirror angle (>=6) paired with another
				# angle of the same frame in this lump (e.g. A2A8 -> flip A8)
				if angle >= 6 and frame_angles[frame].size() > 1:
					_spriteFlip[sprKey] = true
	_spritesLoaded = _sprites.size() > 0
	if _spritesLoaded:
		_updateSprite()

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
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size
	else:
		if not _warned_sprites.has(spriteName):
			_warned_sprites[spriteName] = true
			push_warning("SpiderDemon: sprite '%s' not found" % spriteName)

func _calculateAngleIndex() -> int:
	return 1

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
	var deathDuration = DEATH_FRAMES.size() * FRAME_DURATION
	await get_tree().create_timer(deathDuration).timeout
	_deathComplete = true
	var corpseKey = SPRITE_PREFIX + "S1"
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

func _getMesh() -> MeshInstance3D:
	return null
