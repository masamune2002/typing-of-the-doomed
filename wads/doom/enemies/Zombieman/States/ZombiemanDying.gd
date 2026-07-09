extends EnemyState
class_name ZombiemanDying

func _ready() -> void:
	key = Enums.ENEMY_STATE.DYING
	displayName = 'Dying'

func enter(_previousState: Enums.ENEMY_STATE) -> void:
	# Zombieman handles its own death animation via _startSpriteDeath()
	# Just set state flags here
	parent.dying = true
	parent.alive = false

func exit(_newState: Enums.ENEMY_STATE) -> void:
	parent.dying = false
	parent.alive = false
