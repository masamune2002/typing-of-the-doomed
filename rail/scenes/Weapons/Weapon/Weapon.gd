extends Node3D
class_name Weapon

var fireType : Enums.WEAPON_FIRE_TYPE
var showReticle : bool
var fireSound : String = "DSPISTOL"

@export var bobAmountX : float = 0.002
@export var bobAmountY : float = 0.004
@export var bobSpeed : float = 10.0
var _bobTime : float = 0.0
var _originPosition : Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_originPosition = position

func canFire(event : InputEvent) -> bool:
	return false

func fire(inputEvent : InputEvent) -> Variant:
	push_warning('Weapon.fire() not implemented')
	return null

func _isPlayerMoving() -> bool:
	return Input.is_action_pressed("forward") or Input.is_action_pressed("backward") \
		or Input.is_action_pressed("strafeLeft") or Input.is_action_pressed("strafeRight")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _isPlayerMoving():
		_bobTime += delta * bobSpeed
		var bob_offset := Vector3(
			sin(_bobTime) * bobAmountX,
			sin(_bobTime * 2.0) * bobAmountY,
			0.0
		)
		position = _originPosition + bob_offset
	else:
		_bobTime = 0.0
		position = position.lerp(_originPosition, delta * 10.0)
