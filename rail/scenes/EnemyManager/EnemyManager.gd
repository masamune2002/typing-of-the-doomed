extends Node
class_name EnemyManager

@export var attackSecs : int = 5

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
		push_warning('Enemy Manager needs player ref')
		return
	playerRef.fireWeapon.connect(_handlePlayerFired)
	_currentFireType = playerRef.getCurrentFireType()


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
				if enemy.active && enemy.alive && !enemy.dying && enemy.visible_to_player:
					candidateEnemies.append(enemy)
	if candidateEnemies.size() == 0:
		return
	var attackingEnemy : Enemy = candidateEnemies.pick_random()
	if attackingEnemy.alive && !attackingEnemy.dying && attackingEnemy.active:
		attackingEnemy.startAttack(playerRef)
		_attackTimer.start(attackSecs)


func _handlePlayerFired(weaponFireType : Enums.WEAPON_FIRE_TYPE, target : Node3D, payload : Variant) -> void:
	if target != null:
		if !is_instance_valid(target):
			# Target was freed (e.g. picked-up item) — clear dangling reference
			playerRef._clearFireTarget()
		else:
			# Check if locked-on target is still valid
			var targetValid := false
			if target is Enemy:
				targetValid = target.alive and target.active and !target.dying
			elif target is Item:
				targetValid = target.alive and target.active
			elif target is Interactable:
				targetValid = target.alive and target.active
			elif target is ExplodingBarrel:
				targetValid = target.alive and target.active

			if targetValid:
				# Fire at locked-on target
				if target is Enemy:
					if target.receiveFire(weaponFireType, payload):
						_playWeaponSound()
						playerRef._playerUi.showWeaponFire()
				elif target is Item:
					if target.receiveFire(weaponFireType, payload):
						playerRef.lookAtPosition(target.global_position)
				elif target is Interactable:
					if target.receiveFire(weaponFireType, payload):
						playerRef.lookAtPosition(target.global_position)
				elif target is ExplodingBarrel:
					if target.receiveFire(weaponFireType, payload):
						_playWeaponSound()
						playerRef._playerUi.showWeaponFire()
				return
			else:
				# Target is dead/invalid — clear it and fall through to auto-target
				playerRef._clearFireTarget()

	# No locked-on target — find closest visible on-screen target that matches
	# Prioritize enemies over items/interactables so items don't steal targeting during combat
	var candidates := playerRef._getVisibleTargets()
	for node in candidates:
		if node is Enemy:
			if node.receiveFire(weaponFireType, payload):
				if node.active and node.alive:
					playerRef.setFireTarget(node)
				_playWeaponSound()
				playerRef._playerUi.showWeaponFire()
				return
	for node in candidates:
		if node is Item:
			if node.receiveFire(weaponFireType, payload):
				if node.alive:
					playerRef.setFireTarget(node)
				return
		elif node is Interactable:
			if node.receiveFire(weaponFireType, payload):
				if node.alive:
					playerRef.setFireTarget(node)
				return
		elif node is ExplodingBarrel:
			if node.receiveFire(weaponFireType, payload):
				if node.alive:
					playerRef.setFireTarget(node)
				return

func _playWeaponSound() -> void:
	if playerRef != null and playerRef._currentWeapon != null:
		Game.playSound(playerRef._currentWeapon.fireSound)
