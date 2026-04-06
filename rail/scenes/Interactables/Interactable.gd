extends Node3D
class_name Interactable

@onready var interactableLabel: Label3D = $InteractableLabel

var active: bool = false
var alive: bool = true
var visible_to_player: bool = false

var wadNode: Node3D
var weakness: TypingWeakness
var requiredKey: String = ""  # empty = no key needed

func _ready() -> void:
	alive = true
	active = false
	add_to_group("Interactables")
	EventBus.startEncounter.connect(activate)

	weakness = TypingWeakness.new()
	weakness.setup(0)
	interactableLabel.text = weakness.getLabelText().to_upper()
	interactableLabel.hide()

	# Yellow/orange color to distinguish from enemies (white) and items (green/blue)
	interactableLabel.modulate = Color(1.0, 0.8, 0.2)




func _applyDoomFont() -> void:
	var doomFont = Game.getDoomFont()
	if doomFont != null:
		interactableLabel.font = doomFont
		interactableLabel.font_size = 16
		interactableLabel.pixel_size = 0.02

func activate() -> void:
	active = true
	_applyDoomFont()
	if alive and visible_to_player:
		interactableLabel.show()

func deactivate() -> void:
	active = false
	interactableLabel.hide()

func receiveFire(weaponFireType: Enums.WEAPON_FIRE_TYPE, payload: Variant) -> bool:
	if !alive or !active or !visible_to_player:
		return false
	if weaponFireType != Enums.WEAPON_FIRE_TYPE.TYPING:
		return false
	var hit = weakness.receiveHit(payload)
	interactableLabel.text = weakness.getLabelText().to_upper()
	if hit and weakness.isHealthBarEmpty():
		_activate_wad_node()
	return hit

func _activate_wad_node() -> void:
	alive = false
	interactableLabel.hide()
	var player = Game.getPlayer()
	if player != null and player._currentFireTarget == self:
		EventBus.releasePlayerTarget.emit()
	if wadNode != null and is_instance_valid(wadNode):
		if wadNode.has_method("activate"):
			wadNode.activate()
		elif wadNode.has_method("bodyIn") and player != null:
			# Lifts check interactPressed on the body for switch-type triggers
			player.interactPressed = true
			wadNode.bodyIn(player)
			player.interactPressed = false
	Game.playSound("DSDOROPN")

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	# If door has closed again, re-enable the interactable with the same word
	if !alive and active:
		if _isDoorClosed():
			_resetWeakness()

	if !active or !alive:
		visible_to_player = false
		return
	if not _hasRequiredKey():
		visible_to_player = false
		interactableLabel.hide()
		return
	visible_to_player = _check_line_of_sight()
	if visible_to_player:
		interactableLabel.show()
	else:
		interactableLabel.hide()

func _isDoorClosed() -> bool:
	if wadNode == null or !is_instance_valid(wadNode):
		return false
	var state = wadNode.get("state")
	if state == null:
		return false
	# STATE.CLOSED = 2 in door.gd, STATE.TOP = 0 in lift.gd
	# Door is closed when state matches CLOSED enum
	return state == 2

func _resetWeakness() -> void:
	alive = true
	weakness._currentHitPointIndex = 0
	for hitPoint in weakness.hitPoints:
		hitPoint.full = true
	weakness.updateLabel()
	interactableLabel.text = weakness.getLabelText().to_upper()

# Keys that satisfy each color requirement (card and skull are interchangeable)
const KEY_EQUIVALENTS = {
	"blue_keycard": ["blue_keycard", "blue_skull"],
	"yellow_keycard": ["yellow_keycard", "yellow_skull"],
	"red_keycard": ["red_keycard", "red_skull"],
}

func _hasRequiredKey() -> bool:
	if requiredKey == "":
		return true
	var player = Game.getPlayer()
	if player == null:
		return false
	var valid_keys = KEY_EQUIVALENTS.get(requiredKey, [requiredKey])
	for key in valid_keys:
		if key in player._keys:
			return true
	return false

const MAX_INTERACT_DISTANCE: float = 20.0

func _check_line_of_sight() -> bool:
	var player = Game.getPlayer()
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	if distance > MAX_INTERACT_DISTANCE:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var world_pos := global_position + Vector3(0, 1.0, 0)
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos := camera.unproject_position(world_pos)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return false
	# Raycast to check for walls between player and door
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = player.global_position + Vector3(0, 0.85, 0)
	var to = global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2  # environment only
	query.exclude = [player.get_rid()]
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	# Cast a reverse ray from the label toward the player to check if we're inside
	# a thin sector (door) vs behind a real wall
	var reverse_query = PhysicsRayQueryParameters3D.create(to, from)
	reverse_query.collision_mask = 2
	var reverse_result = space_state.intersect_ray(reverse_query)
	if reverse_result.is_empty():
		return true
	# Both rays hit something — if both hits are close to each other, it's a thin
	# door sector and the label is between the walls. If they're far apart, there's
	# a real wall between the player and the label.
	var fwd_hit: Vector3 = result["position"]
	var rev_hit: Vector3 = reverse_result["position"]
	return fwd_hit.distance_to(rev_hit) < 2.0
