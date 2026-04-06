class_name Enemy
extends CharacterBody3D

const ANIMATION_NAME_DIE = 'die'
const ANIMATION_NAME_IDLE = 'idle'

@onready var animationPlayer : AnimationPlayer = get_node_or_null("EnemyMeshContainer/AnimationPlayer")
@onready var enemyTargetLabel : Label3D = $EnemyTargetLabel
@onready var stateLabel : Label3D = $StateLabel
@onready var stateMachine : StateMachine = $StateMachine

var difficulty : int
var active : bool
var dying : bool
var alive : bool
var animationLibraryName : String
var targetTypedText : PackedStringArray
var _currentWeaknessType : Enums.WEAPON_FIRE_TYPE
var weaknesses : Dictionary[Enums.WEAPON_FIRE_TYPE, Weakness]
var currentTarget : Player
var visible_to_player : bool = false
var _prev_visible_to_player : bool = false
var baseDamageMin : int = 5
var baseDamageMax : int = 10
var attackSound : String = "DSPISTOL"

# Telegraph/attack internals
var _telegraphTween : Tween
var _telegraphMat : StandardMaterial3D
var _attackToken : int = 0

signal startedDying
signal died

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	dying = false
	alive = true
	stateMachine.setState(Enums.ENEMY_STATE.INACTIVE)
	enemyTargetLabel.hide()
	var midiScaleWeakness = MidiScaleWeakness.new()
	var typingWeakness = TypingWeakness.new()
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.MIDI, midiScaleWeakness)
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.TYPING, typingWeakness)
	for weakness : Weakness in weaknesses.values():
		weakness.setup(difficulty)
	add_to_group('Enemies')
	EventBus.enemySpawned.emit(self)
	if animationPlayer != null:
		var animationName = animationLibraryName + "/" + ANIMATION_NAME_IDLE
		animationPlayer.play(animationName)
	

func _applyDoomFont(label: Label3D) -> void:
	var doomFont = Game.getDoomFont()
	if doomFont != null:
		label.font = doomFont
		label.font_size = 16
		label.pixel_size = 0.02
		label.modulate = Color.WHITE

func activate() -> void:
	if animationPlayer != null:
		animationPlayer.stop(false)
	stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func setWeakness(fireType : Enums.WEAPON_FIRE_TYPE):
	if weaknesses.get(fireType) != null:
		_currentWeaknessType = fireType
		_applyDoomFont(enemyTargetLabel)
		enemyTargetLabel.text = weaknesses.get(_currentWeaknessType).getLabelText().to_upper()

func changeLabel(text : String):
	enemyTargetLabel.text = text.to_upper()

func updateStateLabel():
	stateLabel.text = Enums.ENEMY_STATE.find_key(stateMachine.currentStateKey)

func deactivate() -> void:
	stateMachine.setState(Enums.ENEMY_STATE.INACTIVE)

func receiveFire(weaponFireType : Enums.WEAPON_FIRE_TYPE, payload : Variant) -> bool:
	if !alive || !active || !visible_to_player || _currentWeaknessType != weaponFireType:
		return false
	var hit = weaknesses.get(_currentWeaknessType).receiveHit(payload)
	enemyTargetLabel.text = weaknesses.get(_currentWeaknessType).getLabelText().to_upper()
	if hit && weaknesses.get(_currentWeaknessType).isHealthBarEmpty():
		die()
	return hit

func startAttack(target : Player) -> void:
	currentTarget = target
	stateMachine.setState(Enums.ENEMY_STATE.ATTACKING)

func telegraphAndAttackCurrentTarget() -> void:
	if !_canAttack(): return

	var mesh : MeshInstance3D = _getMesh()
	if mesh == null: return

	cancelTelegraph()

	var mat : StandardMaterial3D = _prepare_telegraph_material(mesh)
	if mat == null: return

	var token : int = _newAttackToken()
	_runTelegraph(mat, token)

func _canAttack() -> bool:
	return currentTarget != null && alive && !dying

func _getMesh() -> MeshInstance3D:
	var skeleton: Skeleton3D = %Skeleton3D
	if skeleton == null: return null
	return skeleton.get_child(0) as MeshInstance3D

func _prepare_telegraph_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	var src : Material = mesh.get_active_material(0)
	if !(src is StandardMaterial3D): return null

	var inst : StandardMaterial3D= (src as StandardMaterial3D).duplicate()
	inst.resource_local_to_scene = true
	inst.emission_enabled = true
	inst.emission = Color(1, 0, 0)
	inst.emission_energy_multiplier = 0.0

	mesh.set_surface_override_material(0, inst)
	_telegraphMat = inst
	return inst

func _newAttackToken() -> int:
	_attackToken += 1
	return _attackToken

func _runTelegraph(inst: StandardMaterial3D, token: int) -> void:
	_telegraphTween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).bind_node(self)

	# rise
	_telegraphTween.tween_property(inst, "emission_energy_multiplier", 2.0, 1.0)

	# peak -> attack if still valid
	_telegraphTween.tween_callback(func ():
		_attackIfValid(token)
	)

	# fall
	_telegraphTween.tween_property(inst, "emission_energy_multiplier", 0.0, 0.25)

	# cleanup
	_telegraphTween.finished.connect(func ():
		_telegraphTween = null
	)

func _attackIfValid(token: int) -> void:
	if alive && !dying && token == _attackToken && is_instance_valid(currentTarget):
		_attack(currentTarget)

func cancelTelegraph() -> void:
	# Invalidate pending callbacks
	_attackToken += 1
	# Kill tween if running
	if _telegraphTween != null && _telegraphTween.is_running():
		_telegraphTween.kill()
	_telegraphTween = null
	# Snap emission off
	if _telegraphMat != null:
		_telegraphMat.emission_energy_multiplier = 0.0

func getDamage() -> int:
	return randi_range(baseDamageMin, baseDamageMax)

func _attack(target : Player) -> void:
	if dying || !alive:
		return
	if stateMachine.currentStateKey == Enums.ENEMY_STATE.ATTACKING:
		Game.playSound(attackSound)
		target.receiveHit(getDamage())
		stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func die() -> void:
	stateMachine.setState(Enums.ENEMY_STATE.DYING)

func _physics_process(_delta: float) -> void:
	if !active || !alive || dying:
		visible_to_player = false
		_prev_visible_to_player = false
		return

	visible_to_player = _check_line_of_sight()

	if visible_to_player:
		enemyTargetLabel.show()
	else:
		enemyTargetLabel.hide()

	if _prev_visible_to_player && !visible_to_player:
		var player : Player = Game.getPlayer()
		if player != null && player._currentFireTarget == self:
			EventBus.releasePlayerTarget.emit()

	_prev_visible_to_player = visible_to_player

const MAX_VISIBILITY_DISTANCE: float = 30.0

func _check_line_of_sight() -> bool:
	var player : Player = Game.getPlayer()
	if player == null:
		return false
	var distance = global_position.distance_to(player.global_position)
	if distance > MAX_VISIBILITY_DISTANCE:
		return false
	var space_state = get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from = player.global_position + Vector3(0, 1.6, 0)
	var to = global_position + Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	query.exclude = [self.get_rid(), player.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()
