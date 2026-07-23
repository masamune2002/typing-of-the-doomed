class_name TeleportFog
extends Node3D

## DOOM's teleport fog: the TFOG sprite burst spawned at both ends of a
## teleport (vanilla's S_TFOG sequence - A B A B C..J at 6 tics, fullbright),
## then gone.

const FRAMES : Array[String] = [
	"TFOGA0", "TFOGB0", "TFOGA0", "TFOGB0", "TFOGC0", "TFOGD0",
	"TFOGE0", "TFOGF0", "TFOGG0", "TFOGH0", "TFOGI0", "TFOGJ0",
]
const FRAME_SECS := 6.0 / 35.0
const PIXEL_SIZE := 0.04

var _textures : Array[Texture2D] = []
var _sprite : Sprite3D
var _frame_index : int = 0
var _timer : float = 0.0


## pos is the floor point; the fog rises from it like the WAD sprites do.
static func spawnAt(tree : SceneTree, pos : Vector3) -> void:
	if tree == null or tree.current_scene == null:
		return
	var fog := TeleportFog.new()
	for name in FRAMES:
		var tex = Game.fetchSprite(name)
		if tex:
			fog._textures.append(tex)
	if fog._textures.is_empty():
		return
	tree.current_scene.add_child(fog)
	fog.global_position = pos


func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = PIXEL_SIZE
	add_child(_sprite)
	_setFrame(0)


func _process(delta : float) -> void:
	_timer += delta
	if _timer < FRAME_SECS:
		return
	_timer = 0.0
	_frame_index += 1
	if _frame_index >= _textures.size():
		queue_free()
		return
	_setFrame(_frame_index)


func _setFrame(i : int) -> void:
	_sprite.texture = _textures[i]
	_sprite.position.y = (_sprite.texture.get_height() / 2.0) * PIXEL_SIZE
