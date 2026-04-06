extends Node3D
class_name Item

@onready var sprite: Sprite3D = $Sprite3D
@onready var itemLabel: Label3D = $ItemLabel

var active: bool = false
var alive: bool = true
var visible_to_player: bool = false

var itemDefinition: Dictionary
var weakness: TypingWeakness

# Sprite animation
var _spriteFrames: Array[Texture2D] = []
var _currentFrameIndex: int = 0
var _frameTimer: float = 0.0
const FRAME_DURATION = 8.0 / 35.0  # DOOM tick rate


signal pickedUp(item: Item)

func _ready() -> void:
	alive = true
	active = false
	add_to_group("Items")
	EventBus.startEncounter.connect(activate)

	weakness = TypingWeakness.new()
	weakness.setup(0)
	itemLabel.text = weakness.getLabelText().to_upper()
	itemLabel.hide()

	match itemDefinition.get("effect", "health"):
		"health":
			itemLabel.modulate = Color(0.2, 1.0, 0.2)
		"armor":
			itemLabel.modulate = Color(0.2, 0.5, 1.0)

	_tryLoadSprites()

func _tryLoadSprites() -> void:
	if Game.wadLoader == null or Game.wadLoader._loader == null:
		get_tree().process_frame.connect(_onRetryLoad, CONNECT_ONE_SHOT)
		return
	_loadSprites()

func _onRetryLoad() -> void:
	_tryLoadSprites()

func _loadSprites() -> void:
	var spriteNames: Array = itemDefinition.get("sprites", [])
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
		itemLabel.font = doomFont
		itemLabel.font_size = 16
		itemLabel.pixel_size = 0.02

func activate() -> void:
	active = true
	_applyDoomFont()
	if alive and visible_to_player:
		itemLabel.show()

func deactivate() -> void:
	active = false
	itemLabel.hide()

func receiveFire(weaponFireType: Enums.WEAPON_FIRE_TYPE, payload: Variant) -> bool:
	if !alive or !active or !visible_to_player:
		return false
	if weaponFireType != Enums.WEAPON_FIRE_TYPE.TYPING:
		return false
	var hit = weakness.receiveHit(payload)
	itemLabel.text = weakness.getLabelText().to_upper()
	if hit and weakness.isHealthBarEmpty():
		_pickup()
	return hit

func _pickup() -> void:
	alive = false
	itemLabel.hide()
	var player = Game.getPlayer()
	if player != null and player._currentFireTarget == self:
		EventBus.releasePlayerTarget.emit()
	if player == null:
		queue_free()
		return
	match itemDefinition.get("effect", ""):
		"health":
			player.healHealth(itemDefinition.get("amount", 10), itemDefinition.get("overheal", false))
		"armor":
			var armorType: Enums.ARMOR_TYPE = Enums.ARMOR_TYPE.NONE
			match itemDefinition.get("armor_type", "NONE"):
				"GREEN":
					armorType = Enums.ARMOR_TYPE.GREEN
				"BLUE":
					armorType = Enums.ARMOR_TYPE.BLUE
			player.addArmor(itemDefinition.get("amount", 1), armorType)
		"key":
			player.addKey(itemDefinition.get("key", ""))
	player.flashPickup()
	_playPickupSound()
	pickedUp.emit(self)
	queue_free()

func _playPickupSound() -> void:
	Game.playSound(itemDefinition.get("sound", "DSITEMUP"))

func _process(delta: float) -> void:
	if !alive:
		return

	# Animate sprite frames
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
		itemLabel.show()
	else:
		itemLabel.hide()

const MAX_PICKUP_DISTANCE: float = 15.0

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
	if distance > MAX_PICKUP_DISTANCE:
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
