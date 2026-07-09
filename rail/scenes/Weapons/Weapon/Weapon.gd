extends Node3D
class_name Weapon

var fireType : Enums.WEAPON_FIRE_TYPE
var showReticle : bool
var fireSound : String = "DSPISTOL"

@export var bobAmountY : float = 0.006
@export var bobSpeed : float = 8.0
@export var swayAmount : float = 0.003
var _bobTime : float = 0.0
# Amplitude envelope (0..1): see DoomPlayer head bob — fades the sway out on
# a stop and back in on resume with continuous phase, instead of snapping the
# weapon to its origin the first stopped frame.
var _bobAmp : float = 0.0
const BOB_FADE := 0.15
var _originPosition : Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_originPosition = position

func canFire(_event : InputEvent) -> bool:
	return false

func fire(_inputEvent : InputEvent) -> Variant:
	push_warning('Weapon.fire() not implemented')
	return null

func _isPlayerMoving() -> bool:
	var player = Game.getPlayer()
	if player != null and player._moving:
		return true
	return Input.is_action_pressed("forward") or Input.is_action_pressed("backward") \
		or Input.is_action_pressed("strafeLeft") or Input.is_action_pressed("strafeRight")

func _getSwayDirection() -> float:
	var sway := 0.0
	if Input.is_action_pressed("strafeLeft"):
		sway += 1.0
	if Input.is_action_pressed("strafeRight"):
		sway -= 1.0
	return sway

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _isPlayerMoving():
		var player = Game.getPlayer()
		var speed_ratio = player.getMovementSpeedRatio() if player else 1.0
		_bobTime += delta * bobSpeed * speed_ratio
		_bobAmp = move_toward(_bobAmp, 1.0, delta / BOB_FADE)
	else:
		_bobAmp = move_toward(_bobAmp, 0.0, delta / BOB_FADE)
	var sway_dir = _getSwayDirection()
	var bob_offset := Vector3(
		sin(_bobTime) * swayAmount + sway_dir * swayAmount * 2.0,
		abs(sin(_bobTime)) * bobAmountY,
		0.0
	) * _bobAmp
	position = _originPosition + bob_offset
