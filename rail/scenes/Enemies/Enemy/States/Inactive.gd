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
	var reduction := 0
	var player = Game.getPlayer()
	if player != null and player._currentWeapon != null and "difficultyReduction" in player._currentWeapon:
		reduction = player._currentWeapon.difficultyReduction
	parent.setWeakness(Game.getWeaponFireType(), reduction)
	parent.active = true
	if parent.visible_to_player:
		parent.enemyTargetLabel.show()
	if _pausedAnimation != null && _pausedAnimation != "":
		parent.animationPlayer.seek(_pausedAnimationSeekTime, true)
		parent.animationPlayer.play(_pausedAnimation)
