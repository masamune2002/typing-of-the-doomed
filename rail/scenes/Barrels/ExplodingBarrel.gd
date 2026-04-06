extends Node3D
class_name ExplodingBarrel

@onready var sprite: Sprite3D = $Sprite3D
@onready var barrelLabel: Label3D = $BarrelLabel

var active: bool = false
var alive: bool = true
var visible_to_player: bool = false

var weakness: TypingWeakness

# Sprite loading
var _spriteFrames: Array[Texture2D] = []
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
const FRAME_DURATION = 8.0 / 35.0

# Explosion
var _exploding: bool = false
var _explosionFrames: Array[Texture2D] = []
var _explosionFrameIndex: int = 0
var _explosionTimer: float = 0.0
const EXPLOSION_FRAME_DURATION = 4.0 / 35.0
const EXPLOSION_RADIUS: float = 5.0
const EXPLOSION_DAMAGE: int = 20
const EXPLOSION_SPRITE_NAMES: Array[String] = ["BEXPA0", "BEXPB0", "BEXPC0", "BEXPD0", "BEXPE0"]

signal exploded(barrel: ExplodingBarrel)

func _ready() -> void:
	alive = true
	active = false
	add_to_group("Barrels")
	EventBus.startEncounter.connect(activate)

	weakness = TypingWeakness.new()
	weakness.setup(2)
	barrelLabel.text = weakness.getLabelText().to_upper()
	barrelLabel.hide()

	barrelLabel.modulate = Color(1.0, 0.4, 0.1)

	_tryLoadSprites()

func _tryLoadSprites() -> void:
	if Game.wadLoader == null or Game.wadLoader._loader == null:
		get_tree().process_frame.connect(_onRetryLoad, CONNECT_ONE_SHOT)
		return
	_loadSprites()

func _onRetryLoad() -> void:
	_tryLoadSprites()

func _loadSprites() -> void:
	var spriteNames = ["BAR1A0", "BAR1B0"]
	for spriteName in spriteNames:
		var texture = Game.fetchSprite(spriteName)
		if texture != null:
			_spriteFrames.append(texture)
	if _spriteFrames.size() > 0:
		sprite.texture = _spriteFrames[0]
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size

func _applyDoomFont() -> void:
	var doomFont = Game.getDoomFont()
	if doomFont != null:
		barrelLabel.font = doomFont
		barrelLabel.font_size = 16
		barrelLabel.pixel_size = 0.02

func activate() -> void:
	active = true
	_applyDoomFont()
	if alive and visible_to_player:
		barrelLabel.show()

func deactivate() -> void:
	active = false
	barrelLabel.hide()

func receiveFire(weaponFireType: Enums.WEAPON_FIRE_TYPE, payload: Variant) -> bool:
	if !alive or !active or !visible_to_player:
		return false
	if weaponFireType != Enums.WEAPON_FIRE_TYPE.TYPING:
		return false
	var hit = weakness.receiveHit(payload)
	barrelLabel.text = weakness.getLabelText().to_upper()
	if hit and weakness.isHealthBarEmpty():
		_explode()
	return hit

func _explode() -> void:
	if !alive:
		return
	alive = false
	barrelLabel.hide()
	var player = Game.getPlayer()
	if player != null and player._currentFireTarget == self:
		EventBus.releasePlayerTarget.emit()

	Game.playSound("DSBAREXP")

	# Area damage: enemies
	for node in get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy and node.alive and !node.dying:
			var dist = global_position.distance_to(node.global_position)
			if dist <= EXPLOSION_RADIUS:
				node.receiveFire(Enums.WEAPON_FIRE_TYPE.TYPING, null)
				# Force kill by dealing massive damage through weakness
				if node.alive:
					node.die()

	# Chain-explode nearby barrels
	for node in get_tree().get_nodes_in_group("Barrels"):
		if node is ExplodingBarrel and node != self and node.alive:
			var dist = global_position.distance_to(node.global_position)
			if dist <= EXPLOSION_RADIUS:
				node._explode()

	# Damage player if nearby
	if player != null:
		var dist = global_position.distance_to(player.global_position)
		if dist <= EXPLOSION_RADIUS:
			player.receiveHit(EXPLOSION_DAMAGE)

	exploded.emit(self)

	# Start explosion animation
	_exploding = true
	_explosionFrameIndex = 0
	_explosionTimer = 0.0
	for spr_name in EXPLOSION_SPRITE_NAMES:
		var tex = Game.fetchSprite(spr_name)
		if tex != null:
			_explosionFrames.append(tex)
	if _explosionFrames.size() > 0:
		sprite.texture = _explosionFrames[0]
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size
	else:
		queue_free()

func _process(delta: float) -> void:
	if _exploding:
		_explosionTimer += delta
		if _explosionTimer >= EXPLOSION_FRAME_DURATION:
			_explosionTimer = 0.0
			_explosionFrameIndex += 1
			if _explosionFrameIndex >= _explosionFrames.size():
				queue_free()
				return
			sprite.texture = _explosionFrames[_explosionFrameIndex]
			sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size
		return

	if !alive:
		return

	# Animate idle sprite frames
	if _spriteFrames.size() > 1:
		_frameTimer += delta
		if _frameTimer >= FRAME_DURATION:
			_frameTimer = 0.0
			_currentFrameIndex = (_currentFrameIndex + 1) % _spriteFrames.size()
			sprite.texture = _spriteFrames[_currentFrameIndex]
		sprite.position.y = (sprite.texture.get_height() / 2.0) * sprite.pixel_size

func _physics_process(_delta: float) -> void:
	if !active or !alive:
		visible_to_player = false
		return
	visible_to_player = _check_line_of_sight() and _is_on_screen()
	if visible_to_player:
		barrelLabel.show()
	else:
		barrelLabel.hide()

const MAX_BARREL_DISTANCE: float = 15.0

func _is_on_screen() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var world_pos := global_position + Vector3(0, 0.5, 0)
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos := camera.unproject_position(world_pos)
	var viewport_size := get_viewport().get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y

func _check_line_of_sight() -> bool:
	var player = Game.getPlayer()
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	if distance > MAX_BARREL_DISTANCE:
		return false
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = player.global_position + Vector3(0, 0.85, 0)
	var to = global_position + Vector3(0, 0.5, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()
