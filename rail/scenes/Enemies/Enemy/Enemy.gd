class_name Enemy
extends CharacterBody3D

const ANIMATION_NAME_DIE = 'die'
const ANIMATION_NAME_IDLE = 'idle'

@onready var animationPlayer : AnimationPlayer = get_node_or_null("EnemyMeshContainer/AnimationPlayer")
@onready var enemyTargetLabel : Label3D = $EnemyTargetLabel
var pipsLabel : Label3D
var pipsDefeatedLabel : Label3D
var typedLabel : Label3D
var debugLabel : Label3D
var _labelHomes : Array = [] # natural label positions for clampLabelsToView
var _labelLine : MeshInstance3D # leader line shown when the label strays from home
@onready var stateLabel : Label3D = $StateLabel
@onready var stateMachine : StateMachine = $StateMachine

var difficulty : int
var _difficultyReduction : int = 0
var numHealthBars : int = 1
var _currentHealthBar : int = 0
# Encounter conditions read visible_to_player the same frame an enemy is
# (re)activated, but the cached value is forced false the whole time it was
# inactive — recompute it immediately on activation so a just-woken enemy
# is never mistaken for a cleared one.
var active : bool :
	set(value):
		active = value
		if active and is_inside_tree():
			refreshVisibility()
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
var seeSound : String = ""
var painSound : String = ""
var deathSound : String = ""
var activeSound : String = ""
var _startDead : bool = false
# Sector light at the enemy's position (0..1). Sprites are tinted by it
# like DOOM lights its sprites; near-black enemies keep their (fullbright)
# labels but the words are long unreadable garble - hard to fight what
# you can't see.
var _sector_light : float = 1.0
const DARK_WORD_LIGHT := 40.0 / 255.0
const DARK_WORD_CHARS := "abcdefghijklmnopqrstuvwxyz0123456789-=[];'./"

var _hasPlayedSeeSound : bool = false
# DOOM's A_Chase plays the monster's activesound with a 3/256 roll per
# chase tic — one grunt every ~8s per awake monster, uncorrelated.
const ACTIVE_SOUND_MEAN_SECS : float = 8.0
# Wake barks are staggered per enemy (DOOM staggers them via line-of-sight
# and noise propagation; we activate whole encounters on one frame).
const SEE_SOUND_MAX_STAGGER : float = 1.0

# Telegraph/attack internals
var _telegraphTween : Tween
var _telegraphMat : StandardMaterial3D
var _attackToken : int = 0

@warning_ignore("unused_signal")
signal startedDying
@warning_ignore("unused_signal")
signal died

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Enemies must never body-block the player - the rail steers straight
	# through them. Layer 2 is world/player, so strip it; enemies still
	# collide with level geometry through their own collision mask.
	collision_layer &= ~2
	# Blocking-line walls (layer 16) stop enemy bodies as in DOOM
	collision_mask |= 16
	dying = false
	alive = true
	stateMachine.setState(Enums.ENEMY_STATE.INACTIVE)
	enemyTargetLabel.hide()
	_initOverlayLabels()
	var midiScaleWeakness = MidiScaleWeakness.new()
	var typingWeakness = TypingWeakness.new()
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.MIDI, midiScaleWeakness)
	weaknesses.set(Enums.WEAPON_FIRE_TYPE.TYPING, typingWeakness)
	for weakness : Weakness in weaknesses.values():
		weakness.setup(difficulty)
	_currentHealthBar = 0
	_updatePips()
	add_to_group('Enemies')
	EventBus.enemySpawned.emit(self)
	if animationPlayer != null:
		var animationName = animationLibraryName + "/" + ANIMATION_NAME_IDLE
		animationPlayer.play(animationName)
	

func _initOverlayLabels() -> void:
	if typedLabel != null:
		return
	# typedLabel kept as a reference but not used as a separate overlay
	typedLabel = enemyTargetLabel
	enemyTargetLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemyTargetLabel.render_priority = 10
	# Create pips labels (white base + red overlay for defeated bars)
	var pipsPos := enemyTargetLabel.position + Vector3(0, -0.3, 0)
	pipsLabel = Label3D.new()
	pipsLabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pipsLabel.no_depth_test = true
	pipsLabel.render_priority = 10
	pipsLabel.modulate = Color.WHITE
	pipsLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pipsLabel.position = pipsPos
	add_child(pipsLabel)
	pipsLabel.hide()
	pipsDefeatedLabel = Label3D.new()
	pipsDefeatedLabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pipsDefeatedLabel.no_depth_test = true
	pipsDefeatedLabel.render_priority = 11
	pipsDefeatedLabel.modulate = Color.RED
	pipsDefeatedLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pipsDefeatedLabel.position = pipsPos
	add_child(pipsDefeatedLabel)
	pipsDefeatedLabel.hide()
	# Debug label — shows WAD thing name/id below weakness label
	debugLabel = Label3D.new()
	debugLabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debugLabel.no_depth_test = true
	debugLabel.render_priority = 10
	debugLabel.modulate = Color(0.5, 1.0, 0.5)
	debugLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debugLabel.position = enemyTargetLabel.position + Vector3(0, -0.3, 0)
	debugLabel.text = name
	if has_meta("thing_index"):
		debugLabel.text += " #%d" % get_meta("thing_index")
	add_child(debugLabel)
	debugLabel.hide()
	# Natural label layout; clampLabelsToView shifts the whole group from
	# these homes when the player is too close to see them (melee range).
	_labelHomes = [enemyTargetLabel.position, pipsLabel.position, pipsDefeatedLabel.position]
	_labelLine = Utils.makeLabelLeaderLine(self)

func _applyDoomFont(label: Label3D) -> void:
	if label == null:
		return
	var doomFont = Game.getDoomFont()
	if doomFont != null:
		label.font = doomFont
		label.font_size = 16
		label.pixel_size = 0.02
		# fitLabelsToScreen scales pixel_size down from this base each frame
		label.set_meta("base_pixel_size", label.pixel_size)

func activate() -> void:
	if _startDead:
		return
	if animationPlayer != null:
		animationPlayer.stop(false)
	stateMachine.setState(Enums.ENEMY_STATE.IDLE)
	# Wake bark: once per enemy, staggered so a room activating on one
	# frame growls as a ragged chorus instead of a single chord.
	if !_hasPlayedSeeSound and seeSound != "":
		_hasPlayedSeeSound = true
		get_tree().create_timer(randf() * SEE_SOUND_MAX_STAGGER).timeout.connect(func():
			if is_instance_valid(self) and alive and active and !dying:
				Game.playSoundAt(seeSound, self))

func setDead() -> void:
	_startDead = true
	dying = false
	alive = false
	active = false
	collision_layer = 0
	collision_mask = 0
	enemyTargetLabel.hide()
	if typedLabel != null:
		typedLabel.hide()
	if pipsLabel != null:
		pipsLabel.hide()
	if pipsDefeatedLabel != null:
		pipsDefeatedLabel.hide()
	# Show corpse sprite immediately if sprites already loaded
	_showCorpse()

func _showCorpse() -> void:
	# Override in subclasses to show corpse sprite
	pass

func setSectorLight(level01 : float) -> void:
	var was := _sector_light
	_sector_light = clampf(level01, 0.0, 1.0)
	var spr = get("sprite")
	if spr is Sprite3D:
		spr.modulate = baseTint()
	# Turning dark re-rolls the weakness into garble (spawn order: the
	# EnemyManager assigns the normal word before main knows the sector)
	if _sector_light < DARK_WORD_LIGHT and was >= DARK_WORD_LIGHT \
			and weaknesses.has(_currentWeaknessType):
		setWeakness(_currentWeaknessType, _difficultyReduction)

## A long unreadable string of letters, digits and symbols for enemies
## lurking in near-black sectors.
func _darkWord() -> String:
	var n := 12 + difficulty * 2
	var out := ""
	for i in n:
		out += DARK_WORD_CHARS[randi() % DARK_WORD_CHARS.length()]
	return out

## The sprite's resting tint under its sector's light. Telegraph flashes
## multiply against this so they stay dark in dark rooms.
func baseTint() -> Color:
	return Color(_sector_light, _sector_light, _sector_light)

func setWeakness(fireType : Enums.WEAPON_FIRE_TYPE, difficultyReduction : int = 0):
	if _startDead:
		return
	_difficultyReduction = difficultyReduction
	if weaknesses.get(fireType) != null:
		_initOverlayLabels()
		_currentWeaknessType = fireType
		# Re-setup weakness with adjusted difficulty
		var weakness = weaknesses.get(fireType)
		weakness.hitPoints.clear()
		if fireType == Enums.WEAPON_FIRE_TYPE.TYPING and _sector_light < DARK_WORD_LIGHT:
			weakness.setup(maxi(difficulty - _difficultyReduction, 0), [_darkWord()])
		else:
			weakness.setup(maxi(difficulty - _difficultyReduction, 0))
		_applyDoomFont(enemyTargetLabel)
		_applyDoomFont(typedLabel)
		_setFullWordLabel()
		_updateTypedLabel()
		_updatePips()

func changeLabel(text : String):
	enemyTargetLabel.text = text.to_upper()
	if typedLabel != null:
		typedLabel.text = ""
		typedLabel.hide()

func updateStateLabel():
	stateLabel.text = Enums.ENEMY_STATE.find_key(stateMachine.currentStateKey)

func deactivate() -> void:
	stateMachine.setState(Enums.ENEMY_STATE.INACTIVE)

func receiveFire(weaponFireType : Enums.WEAPON_FIRE_TYPE, payload : Variant, deferDamage : bool = false) -> bool:
	if !alive || !active || !visible_to_player || _currentWeaknessType != weaponFireType:
		return false
	var hit = weaknesses.get(_currentWeaknessType).receiveHit(payload)
	_updateTypedLabel()
	if hit && weaknesses.get(_currentWeaknessType).isHealthBarEmpty():
		if deferDamage:
			# Store pending action for when the projectile arrives
			_pendingHealthBarAdvance = true
		else:
			_applyHealthBarAdvance()
	return hit

var _pendingHealthBarAdvance : bool = false

func applyDeferredDamage() -> void:
	if _pendingHealthBarAdvance:
		_pendingHealthBarAdvance = false
		if alive and !dying:
			_applyHealthBarAdvance()

func _applyHealthBarAdvance() -> void:
	_currentHealthBar += 1
	if _currentHealthBar >= numHealthBars:
		die()
	else:
		if painSound != "":
			Game.playSoundAt(painSound, self)
		if has_method("playPain"):
			call("playPain")
		_resetWeakness()
		_updatePips()

func _setFullWordLabel() -> void:
	var weakness = weaknesses.get(_currentWeaknessType)
	var fullWord := ""
	for hp in weakness.hitPoints:
		fullWord += hp.toString()
	enemyTargetLabel.text = fullWord.to_upper()

func _updateTypedLabel() -> void:
	# Show only remaining (untyped) characters
	var weakness = weaknesses.get(_currentWeaknessType)
	var remaining := ""
	for hp in weakness.hitPoints:
		if hp.full:
			remaining += hp.toString()
	enemyTargetLabel.text = remaining.to_upper()

func showRemainingLabel() -> void:
	_updateTypedLabel()

func showFullLabel() -> void:
	_setFullWordLabel()
	_updateTypedLabel()

func _resetWeakness() -> void:
	var weakness = weaknesses.get(_currentWeaknessType)
	weakness.hitPoints.clear()
	if _currentWeaknessType == Enums.WEAPON_FIRE_TYPE.TYPING and _sector_light < DARK_WORD_LIGHT:
		weakness.setup(maxi(difficulty - _difficultyReduction, 0), [_darkWord()])
	else:
		weakness.setup(maxi(difficulty - _difficultyReduction, 0))
	_applyDoomFont(enemyTargetLabel)
	_applyDoomFont(typedLabel)
	_setFullWordLabel()
	_updateTypedLabel()

func _updatePips() -> void:
	if pipsLabel == null:
		return
	if numHealthBars <= 1:
		pipsLabel.text = ""
		pipsLabel.hide()
		if pipsDefeatedLabel != null:
			pipsDefeatedLabel.text = ""
			pipsDefeatedLabel.hide()
		return
	_applyDoomFont(pipsLabel)
	_applyDoomFont(pipsDefeatedLabel)
	var allPips := ""
	for i in numHealthBars:
		if i > 0:
			allPips += " "
		allPips += "."
	pipsLabel.text = allPips
	# Defeated overlay: periods for defeated bars, rest invisible
	var defeated := ""
	for i in numHealthBars:
		if i > 0:
			defeated += " "
		if i < _currentHealthBar:
			defeated += "."
		else:
			break
	if pipsDefeatedLabel != null:
		pipsDefeatedLabel.text = defeated
		if _currentHealthBar > 0:
			pipsDefeatedLabel.show()
		else:
			pipsDefeatedLabel.hide()
	if _currentHealthBar < numHealthBars:
		pipsLabel.show()

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
	if alive && !dying && is_inside_tree() && token == _attackToken && is_instance_valid(currentTarget):
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
		Game.playSoundAt(attackSound, self)
		target.receiveHit(getDamage())
		stateMachine.setState(Enums.ENEMY_STATE.IDLE)

func die() -> void:
	if deathSound != "":
		Game.playSoundAt(deathSound, self)
	stateMachine.setState(Enums.ENEMY_STATE.DYING)

func _physics_process(_delta: float) -> void:
	if !active || !alive || dying:
		visible_to_player = false
		_prev_visible_to_player = false
		enemyTargetLabel.hide()
		if typedLabel != null:
			typedLabel.hide()
		if pipsLabel != null:
			pipsLabel.hide()
		if pipsDefeatedLabel != null:
			pipsDefeatedLabel.hide()
		Utils.hideLabelLeaderLine(_labelLine)
		return

	# DOOM active sound: occasional random grunt while awake, positional so
	# distance does the mixing.
	if activeSound != "" and randf() < _delta / ACTIVE_SOUND_MEAN_SECS:
		Game.playSoundAt(activeSound, self)

	refreshVisibility()
	_updateLabelRenderPriority()

	if visible_to_player:
		# Text must be current before the fit pass measures its width
		_setFullWordLabel()
		_updateTypedLabel()
		var labelGroup := [enemyTargetLabel, pipsLabel, pipsDefeatedLabel]
		var stray : Vector3 = Utils.clampLabelsToView(self, labelGroup, _labelHomes)
		stray += Utils.fitLabelsToScreen(self, labelGroup)
		enemyTargetLabel.show()
		Utils.updateLabelLeaderLine(_labelLine, enemyTargetLabel, global_position + Vector3(0, 1.0, 0), stray)
		if numHealthBars > 1 and pipsLabel != null:
			pipsLabel.show()
		if numHealthBars > 1 and pipsDefeatedLabel != null and _currentHealthBar > 0:
			pipsDefeatedLabel.show()
		if debugLabel != null:
			if SettingsManager.debug_show_thing_ids:
				_applyDoomFont(debugLabel)
				debugLabel.show()
			else:
				debugLabel.hide()
	else:
		enemyTargetLabel.hide()
		if pipsLabel != null:
			pipsLabel.hide()
		if pipsDefeatedLabel != null:
			pipsDefeatedLabel.hide()
		if debugLabel != null:
			debugLabel.hide()
		Utils.hideLabelLeaderLine(_labelLine)

	if _prev_visible_to_player && !visible_to_player:
		var player : Player = Game.getPlayer()
		if player != null && player._currentFireTarget == self:
			EventBus.releasePlayerTarget.emit()

	_prev_visible_to_player = visible_to_player

const MAX_VISIBILITY_DISTANCE: float = 30.0

func refreshVisibility() -> void:
	visible_to_player = _check_line_of_sight() and _is_on_screen()

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
	if result.is_empty():
		return true
	# Low decorative colliders (E1M8's pentagram floor inlay) clip the
	# knee-height ray while the enemy towers in plain sight — try again
	# at head height before declaring it hidden.
	query = PhysicsRayQueryParameters3D.create(from, global_position + Vector3(0, 2.2, 0))
	query.collision_mask = 2
	query.exclude = [self.get_rid(), player.get_rid()]
	return space_state.intersect_ray(query).is_empty()

func _is_on_screen() -> bool:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return false
	# An enemy at melee range (a pinky in your face) pushes its label anchor
	# out of the frustum — keep it targetable; clampLabelsToView pulls the
	# label back into view. Enemies behind the player still hide as before.
	if Utils.labelCloseBypass(self):
		return true
	var world_pos = global_position + Vector3(0, 1.0, 0)
	if camera.is_position_behind(world_pos):
		return false
	var screen_pos = camera.unproject_position(world_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	return screen_pos.x >= 0 and screen_pos.x <= viewport_size.x and screen_pos.y >= 0 and screen_pos.y <= viewport_size.y

func _updateLabelRenderPriority() -> void:
	var player : Player = Game.getPlayer()
	if player == null:
		return
	var distance = global_position.distance_to(player.global_position)
	# Closer enemies get higher render_priority so their labels draw on top.
	# Map distance [0..MAX] to priority [100..0] — base layer for white labels,
	# +1 for red overlay labels so they always sit on top of their white counterpart.
	var base_priority : int = clampi(int(100.0 - (distance / MAX_VISIBILITY_DISTANCE) * 100.0), 0, 100)
	enemyTargetLabel.render_priority = base_priority
	if typedLabel != null:
		typedLabel.render_priority = base_priority + 1
	if pipsLabel != null:
		pipsLabel.render_priority = base_priority
	if pipsDefeatedLabel != null:
		pipsDefeatedLabel.render_priority = base_priority + 1
