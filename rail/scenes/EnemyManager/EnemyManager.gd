extends Node
class_name EnemyManager

@export var attackSecs : int = 30

var playerRef : Player
var enemies : Array[Enemy] = []
var waitingEnemies : Array[Enemy] = []
var _attackTimer : Timer
var _currentFireType : Enums.WEAPON_FIRE_TYPE

func _ready():
	EventBus.wait.connect(_handleWait)
	EventBus.stopWait.connect(_handleStopWait)
	EventBus.changeFireType.connect(_handleChangeFireType)
	EventBus.startEncounter.connect(_onEncounterStart)
	EventBus.enemySpawned.connect(_handleEnemySpawned)
	EventBus.playerChanged.connect(_handlePlayerChanged)
	_attackTimer = Timer.new()
	_attackTimer.timeout.connect(_attackTimerTimeout)
	add_child(_attackTimer)

func _onEncounterStart() -> void:
	_attackTimer.start(attackSecs)

func _handlePlayerChanged(newPlayer : Player) -> void:
	playerRef = newPlayer
	if !playerRef || playerRef == null:
		print('Enemy Manager needs player ref')
		return
	playerRef.fireWeapon.connect(_handlePlayerFired)
	_currentFireType = playerRef._currentWeapon.fireType


func _handleChangeFireType(newFireType : Enums.WEAPON_FIRE_TYPE) -> void:
	_currentFireType = newFireType
	var enemiesGroup = get_tree().get_nodes_in_group("Enemies")
	for potentialEnemy in enemiesGroup:
		if potentialEnemy is Enemy:
			var enemy : Enemy = potentialEnemy
			enemy.setWeakness(_currentFireType)


func _handleEnemySpawned(enemy : Enemy) -> void:
	enemy.setWeakness(_currentFireType)
	enemy.died.connect(_handleEnemyDied)
	enemies.append(enemy)

func _handleEnemyDied(enemy : Enemy) -> void:
	enemies.erase(enemy)
	waitingEnemies.erase(enemy)
	enemy.queue_free()

func _handleWait() -> void:
	_attackTimer.paused = true
	var enemiesGroup = get_tree().get_nodes_in_group("Enemies")
	for potentialEnemy in enemiesGroup:
		if potentialEnemy is Enemy:
			var enemy : Enemy = potentialEnemy
			if enemy.active:
				waitingEnemies.append(enemy)
			enemy.deactivate()

func _handleStopWait() -> void:
	for enemy : Enemy in waitingEnemies:
		if enemy.alive:
			enemy.activate()
	_attackTimer.paused = false
	waitingEnemies.clear()

func _attackTimerTimeout() -> void:
	var enemiesGroup : Array[Node]= get_tree().get_nodes_in_group("Enemies")
	var candidateEnemies : Array[Enemy]= []
	for potentialEnemy : Node in enemiesGroup:
			if potentialEnemy is Enemy:
				var enemy : Enemy = potentialEnemy
				if enemy.active && enemy.alive && !enemy.dying:
					candidateEnemies.append(enemy)
	if candidateEnemies.size() == 0:
		return
	var attackingEnemy : Enemy = candidateEnemies.pick_random()
	if attackingEnemy.alive && !attackingEnemy.dying && attackingEnemy.active:
		attackingEnemy.startAttack(playerRef)
		_attackTimer.start(attackSecs)


func _handlePlayerFired(weaponFireType : Enums.WEAPON_FIRE_TYPE, enemyTarget : Enemy, payload : Variant) -> void:
	if enemyTarget == null || !is_instance_valid(enemyTarget):
		var enemiesGroup = get_tree().get_nodes_in_group("Enemies")
		for enemy : Enemy in enemiesGroup:
			if enemy.receiveFire(weaponFireType, payload):
				# If the target is still alive, set it as the active fire target
				if enemy.active && enemy.alive:
					var newEnemyTarget : Enemy = enemy
					playerRef.setFireTarget(newEnemyTarget)
					break

	elif is_instance_valid(enemyTarget):
		enemyTarget.receiveFire(weaponFireType, payload)
