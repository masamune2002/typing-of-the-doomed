extends Node3D
class_name PlayerProjectile

@export var speed: float = 20.0
@export var hit_distance: float = 1.0
@export var fireSound: String = ""

var target: Node3D
var flyingSpriteNames: Array[String] = []
var explosionSpriteNames: Array[String] = []
var splashRadius: float = 0.0       # 0 = no splash damage
var splashKillsAll: bool = false     # true = BFG-style kill everything on screen

@onready var _sprite: Sprite3D = $Sprite3D

var _flying_textures: Array[Texture2D] = []
var _explosion_textures: Array[Texture2D] = []
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _exploding: bool = false
var _target_pos: Vector3
const FRAME_DURATION = 4.0 / 35.0

func _ready() -> void:
	for spriteName in flyingSpriteNames:
		var tex = Game.fetchSprite(spriteName)
		if tex:
			_flying_textures.append(tex)

	for spriteName in explosionSpriteNames:
		var tex = Game.fetchSprite(spriteName)
		if tex:
			_explosion_textures.append(tex)

	if _flying_textures.size() > 0:
		_sprite.texture = _flying_textures[0]
		_sprite.position.y = (_sprite.texture.get_height() / 2.0) * _sprite.pixel_size

	if fireSound != "":
		Game.playSound(fireSound)

	# Snapshot target position in case target dies mid-flight
	if target != null and is_instance_valid(target):
		_target_pos = target.global_position + Vector3(0, 1.0, 0)
	else:
		queue_free()

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

	# Update target position if still valid
	if target != null and is_instance_valid(target):
		_target_pos = target.global_position + Vector3(0, 1.0, 0)

	# Move toward target
	var direction = (_target_pos - global_position).normalized()
	global_position += direction * speed * delta

	# Animate flying frames
	_frame_timer += delta
	if _frame_timer >= FRAME_DURATION and _flying_textures.size() > 0:
		_frame_timer = 0.0
		_frame_index = (_frame_index + 1) % _flying_textures.size()
		_sprite.texture = _flying_textures[_frame_index]

	# Check if we reached the target
	if global_position.distance_to(_target_pos) < hit_distance:
		_explode()

func _explode() -> void:
	_exploding = true
	_frame_index = 0
	_frame_timer = 0.0

	# Apply deferred damage to the primary target
	if target != null and is_instance_valid(target) and target.has_method("applyDeferredDamage"):
		target.applyDeferredDamage()

	if splashKillsAll:
		_bfgKillAll()
	elif splashRadius > 0.0:
		_splashDamage()

	Game.playSound("DSBAREXP")

	if _explosion_textures.size() > 0:
		_sprite.texture = _explosion_textures[0]
	else:
		queue_free()

func _splashDamage() -> void:
	# Barrel-style splash: kill nearby enemies and chain-explode barrels
	for node in get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy and node.alive and !node.dying:
			var dist = global_position.distance_to(node.global_position)
			if dist <= splashRadius and node != target:
				node.die()
	for node in get_tree().get_nodes_in_group("Barrels"):
		if node is ExplodingBarrel and node.alive:
			var dist = global_position.distance_to(node.global_position)
			if dist <= splashRadius:
				node._explode()
	# Damage player if nearby
	var player = Game.getPlayer()
	if player != null:
		var dist = global_position.distance_to(player.global_position)
		if dist <= splashRadius:
			player.receiveHit(20)

func _bfgKillAll() -> void:
	# Kill every visible enemy on screen
	var player = Game.getPlayer()
	if player == null:
		return
	var camera = player.get_viewport().get_camera_3d()
	if camera == null:
		return
	for node in get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy and node.alive and !node.dying and node.visible_to_player:
			node.die()
	for node in get_tree().get_nodes_in_group("Barrels"):
		if node is ExplodingBarrel and node.alive and node.visible_to_player:
			node._explode()
