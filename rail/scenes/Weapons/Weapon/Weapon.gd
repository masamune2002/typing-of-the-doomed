extends Node3D
class_name Weapon

var fireType : Enums.WEAPON_FIRE_TYPE
var showReticle : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func canFire(event : InputEvent) -> bool:
	return false

func fire(inputEvent : InputEvent) -> Variant:
	print('Fire not implemented')
	return null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
