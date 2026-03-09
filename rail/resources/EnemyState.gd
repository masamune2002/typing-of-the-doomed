extends Node
class_name EnemyState

var parent : Enemy
var key : Enums.ENEMY_STATE
var displayName : String

func setup(newParent : Enemy) -> void:
	parent = newParent

func enter(previousState : Enums.ENEMY_STATE) -> void:
	pass

func exit(newState : Enums.ENEMY_STATE) -> void:
	pass
