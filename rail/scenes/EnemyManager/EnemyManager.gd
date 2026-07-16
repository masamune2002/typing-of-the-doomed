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
	EventBus.weaponChanged.connect(_handleWeaponChanged)
	_attackTimer = Timer.new()
	_attackTimer.timeout.connect(_attackTimerTimeout)
	add_child(_attackTimer)

func _onEncounterStart() -> void:
	_attackTimer.start(attackSecs * randf_range(0.7, 1.3))

func _handlePlayerChanged(newPlayer : Player) -> void:
	if playerRef != null and is_instance_valid(playerRef) and playerRef.fireWeapon.is_connected(_handlePlayerFired):
		playerRef.fireWeapon.disconnect(_handlePlayerFired)
	playerRef = newPlayer
	if !playerRef || playerRef == null:
		push_warning('Enemy Manager needs player ref')
		return
	playerRef.fireWeapon.connect(_handlePlayerFired)
	_currentFireType = playerRef.getCurrentFireType()


func _weaponHasProjectile() -> bool:
	if playerRef != null and playerRef._currentWeapon != null:
		if "projectileScene" in playerRef._currentWeapon and playerRef._currentWeapon.projectileScene != null:
			return true
	return false

func _getWeaponDifficultyReduction() -> int:
	if playerRef != null and playerRef._currentWeapon != null and "difficultyReduction" in playerRef._currentWeapon:
		return playerRef._currentWeapon.difficultyReduction
	return 0

func _handleWeaponChanged() -> void:
	var reduction = _getWeaponDifficultyReduction()
	for potentialEnemy in get_tree().get_nodes_in_group("Enemies"):
		if potentialEnemy is Enemy:
			potentialEnemy.setWeakness(_currentFireType, reduction)

func _handleChangeFireType(newFireType : Enums.WEAPON_FIRE_TYPE) -> void:
	_currentFireType = newFireType
	var reduction = _getWeaponDifficultyReduction()
	var enemiesGroup = get_tree().get_nodes_in_group("Enemies")
	for potentialEnemy in enemiesGroup:
		if potentialEnemy is Enemy:
			var enemy : Enemy = potentialEnemy
			enemy.setWeakness(_currentFireType, reduction)


func _handleEnemySpawned(enemy : Enemy) -> void:
	enemy.setWeakness(_currentFireType, _getWeaponDifficultyReduction())
	enemy.died.connect(_handleEnemyDied)
	enemies.append(enemy)

func _handleEnemyDied(enemy : Enemy) -> void:
	enemies.erase(enemy)
	waitingEnemies.erase(enemy)

func _handleWait() -> void:
	_attackTimer.paused = true
	var enemiesGroup = get_tree().get_nodes_in_group("Enemies")
	for potentialEnemy in enemiesGroup:
		if potentialEnemy is Enemy and is_instance_valid(potentialEnemy):
			var enemy : Enemy = potentialEnemy
			if enemy.active:
				waitingEnemies.append(enemy)
			enemy.deactivate()

func _handleStopWait() -> void:
	for enemy : Enemy in waitingEnemies:
		if is_instance_valid(enemy) and enemy.alive:
			enemy.activate()
	_attackTimer.paused = false
	waitingEnemies.clear()

func _attackTimerTimeout() -> void:
	var enemiesGroup : Array[Node]= get_tree().get_nodes_in_group("Enemies")
	var candidateEnemies : Array[Enemy]= []
	for potentialEnemy : Node in enemiesGroup:
			if potentialEnemy is Enemy and is_instance_valid(potentialEnemy):
				var enemy : Enemy = potentialEnemy
				if enemy.active && enemy.alive && !enemy.dying && enemy.visible_to_player:
					candidateEnemies.append(enemy)
	if candidateEnemies.size() == 0:
		return
	var attackingEnemy : Enemy = candidateEnemies.pick_random()
	if attackingEnemy.alive && !attackingEnemy.dying && attackingEnemy.active:
		# Melee enemies (like Pinky) handle their own attack timing via movement
		if attackingEnemy.has_method("isMeleeOnly") and attackingEnemy.isMeleeOnly():
			_attackTimer.start(attackSecs * randf_range(0.7, 1.3))
			return
		attackingEnemy.startAttack(playerRef)
		_attackTimer.start(attackSecs * randf_range(0.7, 1.3))


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
				var defer = _weaponHasProjectile()
				if target is Enemy:
					if target.receiveFire(weaponFireType, payload, defer):
						_shotFired(target)
				elif target is Item:
					if target.receiveFire(weaponFireType, payload):
						playerRef.lookAtPosition(target.global_position)
				elif target is Interactable:
					if target.receiveFire(weaponFireType, payload):
						playerRef.lookAtPosition(target.global_position)
				elif target is ExplodingBarrel:
					if target.receiveFire(weaponFireType, payload):
						_shotFired(target)
				return
			else:
				# Target is dead/invalid — clear it and fall through to auto-target
				playerRef._clearFireTarget()

	# No locked-on target — find closest visible on-screen target that matches
	# Prioritize enemies over items/interactables so items don't steal targeting during combat
	var candidates := playerRef._getVisibleTargets()
	var defer = _weaponHasProjectile()
	for node in candidates:
		if node is Enemy:
			if node.receiveFire(weaponFireType, payload, defer):
				if node.active and node.alive:
					playerRef.setFireTarget(node)
				_shotFired(node)
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
				_shotFired(node)
				return

# A shot that actually landed: gun sound, HUD fire animation, projectile,
# and one round of ammo.
func _shotFired(target : Node3D) -> void:
	_playWeaponSound()
	playerRef._playerUi.showWeaponFire()
	_spawnProjectile(target)
	playerRef.consumeShot()

func _spawnProjectile(target: Node3D) -> void:
	if playerRef == null or playerRef._currentWeapon == null:
		return
	var weapon = playerRef._currentWeapon
	if not "projectileScene" in weapon or weapon.projectileScene == null:
		return
	var burst = 1
	if "burstCount" in weapon:
		burst = weapon.burstCount
	for i in burst:
		_spawnSingleProjectile(target, weapon, i == 0)
		if i < burst - 1:
			await get_tree().create_timer(weapon.firePhase1Time + weapon.firePhase2Time).timeout
			if !is_instance_valid(target):
				break

func _spawnSingleProjectile(target: Node3D, weapon, isPrimary: bool) -> void:
	var projectile = weapon.projectileScene.instantiate()
	projectile.target = target
	projectile.flyingSpriteNames = weapon.projectileFlyingSprites
	projectile.explosionSpriteNames = weapon.projectileExplosionSprites
	projectile.speed = weapon.projectileSpeed
	if isPrimary:
		if "projectileSplashRadius" in weapon:
			projectile.splashRadius = weapon.projectileSplashRadius
		if "projectileKillsAll" in weapon:
			projectile.splashKillsAll = weapon.projectileKillsAll
	projectile.global_position = playerRef.global_position + Vector3(0, 1.2, 0)
	get_tree().current_scene.add_child(projectile)

func _playWeaponSound() -> void:
	if playerRef != null and playerRef._currentWeapon != null:
		Game.playSound(playerRef._currentWeapon.fireSound)
