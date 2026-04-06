extends Node3D
class_name EnemyProjectile

@export var speed: float = 10.0
@export var hit_distance: float = 0.5
@export var sprite_prefix: String = "BAL1"
@export var explosion_prefix: String = ""  # If empty, uses sprite_prefix
@export var damage: int = 10

var target: Player

@onready var _sprite: Sprite3D = $Sprite3D

var _flying_textures: Array[Texture2D] = []
var _explosion_textures: Array[Texture2D] = []
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _exploding: bool = false
const FRAME_DURATION = 4.0 / 35.0  # ~0.114s per frame

func _ready() -> void:
	# Load flying sprites (e.g. BAL1A0, BAL1B0)
	for suffix in ["A0", "B0"]:
		var tex = Game.fetchSprite(sprite_prefix + suffix)
		if tex:
			_flying_textures.append(tex)

	# Load explosion sprites (e.g. BAL1C0, BAL1D0, BAL1E0)
	var exp_prefix = explosion_prefix if explosion_prefix != "" else sprite_prefix
	for suffix in ["C0", "D0", "E0"]:
		var tex = Game.fetchSprite(exp_prefix + suffix)
		if tex:
			_explosion_textures.append(tex)

	if _flying_textures.size() > 0:
		_sprite.texture = _flying_textures[0]
		_sprite.position.y = (_sprite.texture.get_height() / 2.0) * _sprite.pixel_size

func _process(delta: float) -> void:
	if _exploding:
		_frame_timer += delta
		if _frame_timer >= FRAME_DURATION:
			_frame_timer = 0.0
			_frame_index += 1
			if _frame_index >= _explosion_textures.size():
				queue_free()
				return
			_sprite.texture = _explosion_textures[_frame_index]
		return

	if target == null or !is_instance_valid(target):
		queue_free()
		return

	# Move toward target
	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta

	# Animate flying frames
	_frame_timer += delta
	if _frame_timer >= FRAME_DURATION and _flying_textures.size() > 0:
		_frame_timer = 0.0
		_frame_index = (_frame_index + 1) % _flying_textures.size()
		_sprite.texture = _flying_textures[_frame_index]

	# Check if we hit the player
	if global_position.distance_to(target.global_position) < hit_distance:
		target.receiveHit(damage)
		_explode()

func _explode() -> void:
	_exploding = true
	_frame_index = 0
	_frame_timer = 0.0
	if _explosion_textures.size() > 0:
		_sprite.texture = _explosion_textures[0]
	else:
		queue_free()
