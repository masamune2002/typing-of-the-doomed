extends TypingGun
class_name DoomPlasmaRifle

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSPLASMA"
	idleSprites = ["PLSGA0", "PLSGB0"]
	fireSprites = ["PLSFA0", "PLSFB0"]
	recoilSpriteIndex = 1
	muzzleFlashOffsetX = 0.0
	difficultyReduction = 2
	burstCount = 3
	firePhase1Time = 0.08
	firePhase2Time = 0.08
	projectileScene = preload("res://rail/scenes/Projectiles/PlayerProjectile.tscn")
	projectileFlyingSprites = ["PLSSA0", "PLSSB0"] as Array[String]
	projectileExplosionSprites = ["PLSEA0", "PLSEB0", "PLSEC0", "PLSED0", "PLSEE0"] as Array[String]
	projectileSpeed = 25.0
	maxAmmo = 40
