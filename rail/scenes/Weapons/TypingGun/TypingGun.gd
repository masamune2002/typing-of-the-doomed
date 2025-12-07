extends Weapon
class_name TypingGun


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fireType = Enums.WEAPON_FIRE_TYPE.TYPING
	showReticle = false

func canFire(inputEvent : InputEvent):
	if inputEvent is InputEventKey and inputEvent.pressed == true:
		return true
	return false

func fire(event : InputEvent) -> Variant:
	if canFire(event):
		return(event.as_text_key_label())
	return null

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
