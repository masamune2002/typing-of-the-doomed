extends Weapon
class_name TypingGun

var idleSprites : Array[String] = ["PISGA0", "PISGB0"]
var fireSprites : Array[String] = ["PISFA0"]
var recoilSpriteIndex : int = 1
var firePhase1Time : float = 0.115  # flash + recoil duration
var firePhase2Time : float = 0.17   # recovery duration
var muzzleFlashOffsetX : float = 0.2 # horizontal offset as fraction of sprite width (0.0 = centered)
var difficultyReduction : int = 0    # reduces word difficulty for enemies
var burstCount : int = 1             # shots per keypress (visual + projectile)
var projectileScene : PackedScene = null
var projectileFlyingSprites : Array[String] = []
var projectileExplosionSprites : Array[String] = []
var projectileSpeed : float = 20.0
var projectileSplashRadius : float = 0.0
var projectileKillsAll : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	fireType = Enums.WEAPON_FIRE_TYPE.TYPING
	showReticle = false
	fireSound = "DSPISTOL"

func canFire(inputEvent : InputEvent):
	if inputEvent is InputEventKey and inputEvent.pressed == true:
		return true
	return false

func fire(event : InputEvent) -> Variant:
	if canFire(event):
		# as_text_key_label() renders the spacebar as "Space", which can
		# never match the ' ' hit points of multi-word phrases
		if event.keycode == KEY_SPACE or event.key_label == KEY_SPACE:
			return " "
		return(event.as_text_key_label())
	return null

