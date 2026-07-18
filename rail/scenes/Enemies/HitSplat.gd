class_name HitSplat
extends Node3D

## DOOM hit feedback: each landed hit sprays a blood splat on the enemy
## (sprite BLUD, frames C-B-A at 8 tics like vanilla's S_BLOOD1-3). Enemies
## that don't bleed (MF_NOBLOOD - the Lost Soul) get the bullet puff
## (PUFF A-D at 4 tics) instead, exactly as DOOM's P_SpawnBlood/P_SpawnPuff
## split does. Vanilla randomizes the spawn height along the target body;
## we also spread across the visible sprite width.

const BLOOD_FRAMES : Array[String] = ["BLUDC0", "BLUDB0", "BLUDA0"]
const PUFF_FRAMES : Array[String] = ["PUFFA0", "PUFFB0", "PUFFC0", "PUFFD0"]
const BLOOD_FRAME_SECS := 8.0 / 35.0
const PUFF_FRAME_SECS := 4.0 / 35.0
const PIXEL_SIZE := 0.04
# Pushed toward the camera so the splat draws in front of the enemy billboard
const FRONT_OFFSET := 0.3
# Fractions of the sprite's height/width the splat may land on. Sprite
# textures carry transparent padding, so keep well inside the edges or the
# splat floats off the body.
const HEIGHT_MIN := 0.25
const HEIGHT_MAX := 0.75
const LATERAL_MAX := 0.18

var _textures : Array[Texture2D] = []
var _frame_secs : float
var _frame_index : int = 0
var _timer : float = 0.0
var _sprite : Sprite3D
var _enemy : Node3D
var _height : float
var _lateral : float


static func spawnOn(enemy : Enemy) -> void:
	var player = Game.getPlayer()
	if player == null or !enemy.is_inside_tree():
		return
	var splat := HitSplat.new()
	var frames := BLOOD_FRAMES if enemy.bleeds else PUFF_FRAMES
	splat._frame_secs = BLOOD_FRAME_SECS if enemy.bleeds else PUFF_FRAME_SECS
	for name in frames:
		var tex = Game.fetchSprite(name)
		if tex:
			splat._textures.append(tex)
	if splat._textures.is_empty():
		return

	# Body extents from the enemy's own sprite when it has one; the origin
	# sits at the feet, so the splat lands somewhere on the visible body.
	var width := 0.8
	var height := 1.6
	var spr = enemy.get("sprite")
	if spr is Sprite3D and spr.texture != null:
		width = spr.texture.get_width() * spr.pixel_size
		height = spr.texture.get_height() * spr.pixel_size

	splat._enemy = enemy
	splat._height = randf_range(HEIGHT_MIN, HEIGHT_MAX) * height
	splat._lateral = randf_range(-LATERAL_MAX, LATERAL_MAX) * width
	enemy.add_child(splat)
	# The enemy re-aims at the player every frame; a plain child would swing
	# with that rotation and end up behind the billboard. Ignore the parent
	# transform and re-anchor camera-side ourselves each frame instead.
	splat.top_level = true
	splat._reposition()


func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = PIXEL_SIZE
	_sprite.texture = _textures[0]
	add_child(_sprite)


func _process(delta : float) -> void:
	_reposition()
	_timer += delta
	if _timer < _frame_secs:
		return
	_timer = 0.0
	_frame_index += 1
	if _frame_index >= _textures.size():
		queue_free()
		return
	_sprite.texture = _textures[_frame_index]


func _reposition() -> void:
	if _enemy == null or !is_instance_valid(_enemy):
		return
	var player = Game.getPlayer()
	if player == null:
		return
	var toward : Vector3 = player.global_position - _enemy.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.0001 else Vector3.FORWARD
	var right : Vector3 = toward.cross(Vector3.UP).normalized()
	global_position = _enemy.global_position \
		+ Vector3(0, _height, 0) + right * _lateral + toward * FRONT_OFFSET
