extends TypingGun
class_name DoomChainsaw

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSSAWIDL"
	idleSprites = ["SAWGA0", "SAWGB0", "SAWGC0", "SAWGD0"]
	fireSprites = []
	recoilSpriteIndex = 1
