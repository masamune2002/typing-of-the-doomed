extends Node
class_name StateMachine

var parent : Enemy

var stateDict : Dictionary
var currentStateKey : Enums.ENEMY_STATE
var previousStateKey : Enums.ENEMY_STATE
var currentState : EnemyState = null

func _ready() -> void:
	var currentParent = get_parent()
	if currentParent is Enemy:
		parent = currentParent
	else:
		print('Error in State Machine. Parent must be of the correct type.')
	_buildStateDict()
	if stateDict != null && stateDict.size() > 0:
		if stateDict[Enums.ENEMY_STATE.INACTIVE] != null:
			currentState = stateDict[currentStateKey]

func _buildStateDict() -> void:
	var children = get_children()
	for child in children:
		if child is EnemyState:
			var childState : EnemyState = child
			childState.setup(parent)
			stateDict[childState.key] = childState

func setState(newState : Enums.ENEMY_STATE) -> void:
	if currentState:
		currentState.exit(newState)
		previousStateKey = currentState.key

	if stateDict.has(newState) && stateDict[newState] != null:
		currentState = stateDict[newState]
		currentStateKey = currentState.key
		currentState.enter(previousStateKey)
	parent.updateStateLabel()
