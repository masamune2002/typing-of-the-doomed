extends TypingGun
class_name DoomRocketLauncher

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSRLAUNC"
	idleSprites = ["MISGA0", "MISGB0"]
	fireSprites = ["MISFA0", "MISFB0", "MISFC0"]
	recoilSpriteIndex = 1
	muzzleFlashOffsetX = 0.0
	difficultyReduction = 3
	projectileScene = preload("res://rail/scenes/Projectiles/PlayerProjectile.tscn")
	projectileFlyingSprites = ["MISLA1"] as Array[String]
	projectileExplosionSprites = ["MISLB0", "MISLC0", "MISLD0"] as Array[String]
	projectileSpeed = 18.0
	projectileSplashRadius = 5.0
	maxAmmo = 8
