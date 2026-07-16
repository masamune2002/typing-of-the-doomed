extends TypingGun
class_name DoomBFG

func _ready() -> void:
	super()
	$GunMesh.visible = false
	fireSound = "DSBFG"
	idleSprites = ["BFGGA0", "BFGGB0"]
	fireSprites = ["BFGFA0", "BFGFB0"]
	recoilSpriteIndex = 1
	muzzleFlashOffsetX = 0.0
	difficultyReduction = 4
	projectileScene = preload("res://rail/scenes/Projectiles/PlayerProjectile.tscn")
	projectileFlyingSprites = ["BFS1A0", "BFS1B0"] as Array[String]
	projectileExplosionSprites = ["BFE1A0", "BFE1B0", "BFE1C0", "BFE1D0", "BFE1E0", "BFE1F0"] as Array[String]
	projectileSpeed = 15.0
	projectileKillsAll = true
	maxAmmo = 4
