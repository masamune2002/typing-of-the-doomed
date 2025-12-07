extends Enemy
class_name Zombie

func _ready() -> void:
	animationLibraryName = 'ZombieAnimationLibrary'
	difficulty = 1
	$EnemyTargetLabel.position.y += 0.1
	super._ready()
