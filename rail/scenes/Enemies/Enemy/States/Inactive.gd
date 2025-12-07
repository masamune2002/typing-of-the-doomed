extends EnemyState
class_name Inactive

var _pausedAnimation : String
var _pausedAnimationSeekTime : float

func _ready() -> void:
	key = Enums.ENEMY_STATE.INACTIVE
	displayName = 'Inactive'

func enter(previousState : Enums.ENEMY_STATE) -> void:
	parent.active = false
	if parent.animationPlayer.is_playing():
		_pausedAnimation = parent.animationPlayer.current_animation
		_pausedAnimationSeekTime = parent.animationPlayer.current_animation_position
		parent.animationPlayer.pause()
	parent.enemyTargetLabel.hide()

func exit(newState : Enums.ENEMY_STATE) -> void:
	parent.setWeakness(Game.getWeaponFireType())
	parent.active = true
	parent.enemyTargetLabel.show()
	if _pausedAnimation != null && _pausedAnimation != "":
		parent.animationPlayer.seek(_pausedAnimationSeekTime, true)
		parent.animationPlayer.play(_pausedAnimation)
