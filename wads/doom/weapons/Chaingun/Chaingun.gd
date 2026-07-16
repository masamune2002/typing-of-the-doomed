extends TypingGun
class_name DoomChaingun

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSPISTOL"
	idleSprites = ["CHGGA0", "CHGGB0"]
	fireSprites = ["CHGFA0", "CHGFB0"]
	recoilSpriteIndex = 1
	muzzleFlashOffsetX = 0.0
	difficultyReduction = 2
	burstCount = 3
	firePhase1Time = 0.07
	firePhase2Time = 0.07
	maxAmmo = 40
