extends EncounterAction
class_name MoveEnemyToMarkerAction

## Walks an enemy to a marker when the action runs. The marker is any Node3D
## resolved relative to the encounter point. Enemies spawned from WAD data
## don't exist in the level scene, so the enemy is looked up in the "Enemies"
## group — by WAD thing index (the `#` column in llm/<MAP>.md, stamped as
## metadata at spawn) or by runtime node name (e.g. "ShotgunGuy7").

@export var thingIndex : int = -1
@export var enemyName : String = ""
@export var markerNode : NodePath
## Movement speed in world units/sec. <= 0 teleports instantly.
@export var speed : float = 3.0
## Also wake the enemy (activate()) when the move starts.
@export var activate : bool = false

func run(encounterPoint : EncounterPoint) -> void:
	var enemy := _findEnemy(encounterPoint)
	if enemy == null:
		push_warning("MoveEnemyToMarkerAction: no living enemy matches thingIndex=%d enemyName='%s'" % [thingIndex, enemyName])
		finish()
		return

	var marker := encounterPoint.get_node_or_null(markerNode) as Node3D
	if marker == null:
		push_warning("MoveEnemyToMarkerAction: marker not found at %s" % [markerNode])
		finish()
		return

	if activate:
		enemy.activate()

	var destination := marker.global_position
	var distance := enemy.global_position.distance_to(destination)
	if speed <= 0.0 or distance < 0.01:
		enemy.global_position = destination
		finish()
		return

	var tween := enemy.create_tween()
	tween.tween_property(enemy, "global_position", destination, distance / speed)
	tween.finished.connect(_finishOnce)
	# Don't march a corpse across the map if the enemy dies mid-move.
	enemy.died.connect(func():
		if tween.is_valid():
			tween.kill()
		_finishOnce())

func _finishOnce() -> void:
	if !isFinished():
		finish()

func _findEnemy(encounterPoint : EncounterPoint) -> Enemy:
	for node in encounterPoint.get_tree().get_nodes_in_group("Enemies"):
		var enemy := node as Enemy
		if enemy == null or !enemy.alive:
			continue
		if thingIndex >= 0 and enemy.get_meta("thing_index", -1) == thingIndex:
			return enemy
		if enemyName != "" and String(enemy.name) == enemyName:
			return enemy
	return null
