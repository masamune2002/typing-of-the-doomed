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

func process_input(event: InputEvent) -> State:
	return null

func process_frame(delta: float) -> State:
	return null

func process_physics(delta: float) -> State:
	return null

func is_alive() -> bool:
	assert(false, "Unimplemented enemy state function" +  get_stack()[0]["function"])
	return false

func can_attack() -> bool:
	assert(false, "Unimplemented enemy state function" +  get_stack()[0]["function"])
	return false
