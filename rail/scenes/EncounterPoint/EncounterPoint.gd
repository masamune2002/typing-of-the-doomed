@tool
extends Node3D
class_name EncounterPoint

@export var startActions : Array[EncounterAction] = []
@export var endActions : Array[EncounterAction] = []
@export var conditions : Array[EncounterCondition]= []
var conditionsMet : bool
var enemies : Array[Enemy]
var active : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#if !Engine.is_editor_hint():
	#	_hideMeshes()
	var children = get_children()
	for child in children:
		if child is Enemy:
			var enemy : Enemy = child
			enemy.died.connect(_onEnemyDied)
			enemies.append(enemy)

func _hideMeshes():
	$EncounterMesh.hide()
	$CollisionArea/CenterMesh.hide()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !active:
		return
	_checkConditions()
	if conditionsMet:
		endEncounter()

func _checkConditions() -> void:
	if conditions == null || conditions.size() == 0:
		return
	for condition in conditions:
		if !condition.check(self):
			conditionsMet = false
			return
	conditionsMet = true

func _onCollisionAreaBodyEntered(body: Node3D) -> void:
	if body is Player:
		var player : Player = body
		player.setCurrentEncounter(self)

func _onEnemyDied(enemy : Enemy) -> void:
	enemies.erase(enemy)
	enemy.queue_free()

func _runActions(actions : Array[EncounterAction]):
	for action in actions:
		if action == null:
			continue
		action.run(self)
		if action.blocking && !action.isFinished():
			await action.finished

func startEncounter() -> void:
	EventBus.startEncounter.emit()
	active = true
	_runActions(startActions)

func endEncounter() -> void:
	_runActions(endActions)
	active = false
