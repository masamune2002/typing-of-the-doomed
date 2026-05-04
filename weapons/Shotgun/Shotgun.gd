extends TypingGun
class_name DoomShotgun

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSSHOTGN"
	idleSprites = ["SHTGA0", "SHTGB0"]
	fireSprites = ["SHTFA0"]
	recoilSpriteIndex = 1
	firePhase1Time = 0.23
	firePhase2Time = 0.35
	muzzleFlashOffsetX = 0.0
	difficultyReduction = 1
