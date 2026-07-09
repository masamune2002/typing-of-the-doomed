extends TypingGun
class_name DoomFist

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSPUNCH"
	idleSprites = ["PUNGA0", "PUNGB0", "PUNGC0", "PUNGD0"]
	fireSprites = []
	recoilSpriteIndex = 1
