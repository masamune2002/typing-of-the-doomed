extends Enemy
class_name Skeleton

func _ready() -> void:
	animationLibraryName = 'SkeletonAnimationLibrary'
	difficulty = 0
	$EnemyTargetLabel.position.y += 0.05
	super._ready()
