extends TypingGun
class_name DoomPistol

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSPISTOL"
	idleSprites = ["PISGA0", "PISGB0"]
	fireSprites = ["PISFA0"]
	recoilSpriteIndex = 1
