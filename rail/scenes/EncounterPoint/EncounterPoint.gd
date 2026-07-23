@tool
extends RailMarker
class_name EncounterPoint

## A scripted RailMarker: runs startActions on entry, polls conditions
## while active, runs endActions and finalizes once they pass.

@export var startActions : Array[EncounterAction] = []
@export var endActions : Array[EncounterAction] = []

## Conditions read momentary enemy state (active, visible_to_player) that
## legitimately blanks for a frame or longer: the wait system (pause menu,
## dialogs, death) deactivates every enemy while the tree keeps running,
## and enemies reactivated by stopWait keep a stale visible_to_player until
## their next physics tick. A single passing frame must therefore never end
## an encounter: checks are suspended while waiting (and for one physics
## frame after), and gated stations must hold a passing result for this
## long before their end actions run.
const CONDITIONS_HOLD_SECS := 0.5

var _starting : bool = false
var _ending : bool = false
var conditionsMet : bool
var active : bool
var _waiting : bool = false
var _checkAfterPhysicsFrame : int = 0
var _conditionsMetAtMs : int = -1
# True once a real (unsuspended) check has failed this encounter. Flickers
# only exist on a blocked->passing transition, so the hold only applies
# then — stations whose conditions are satisfied from the first fresh
# check end immediately and the rail rides through without stopping.
var _everBlocked : bool = false

func _ready() -> void:
	super()
	if !Engine.is_editor_hint():
		EventBus.wait.connect(_onWait)
		EventBus.stopWait.connect(_onStopWait)

func _onWait() -> void:
	_waiting = true

func _onStopWait() -> void:
	_waiting = false
	# Enemies reactivated by stopWait recompute visible_to_player in their
	# next _physics_process; a check before then reads stale false values
	# and mistakes every suspended enemy for a cleared one.
	_checkAfterPhysicsFrame = maxi(_checkAfterPhysicsFrame, Engine.get_physics_frames() + 1)

func _checksSuspended() -> bool:
	return _waiting or Engine.get_physics_frames() < _checkAfterPhysicsFrame

func _process(_delta: float) -> void:
	# In the editor, only RailMarker's condition-range viz should run.
	if Engine.is_editor_hint():
		super(_delta)
		return
	if !active or _starting or _ending:
		return
	_checkConditions()
	if !conditionsMet:
		_conditionsMetAtMs = -1
		return
	if _conditionsMetAtMs < 0:
		_conditionsMetAtMs = Time.get_ticks_msec()
	if _holdSatisfied():
		endEncounter()

func _holdSatisfied() -> bool:
	# Only encounters that actually blocked need the hold; a station whose
	# conditions passed from the start is a pass-through and must not stop
	# the rail. Debug skip runs never hold either (autoplay route
	# validation visits hundreds of stations; 0.5s each adds minutes).
	if conditions == null or conditions.is_empty() or !_everBlocked:
		return true
	if SettingsManager != null and SettingsManager.debug_skip_encounters:
		return true
	return Time.get_ticks_msec() - _conditionsMetAtMs >= CONDITIONS_HOLD_SECS * 1000.0

func _checkConditions() -> void:
	if _checksSuspended():
		# Suspended is "unknown", not "blocked" — it must neither end the
		# encounter nor arm the hold.
		conditionsMet = false
		return
	conditionsMet = _checkConditionsOnce()
	if !conditionsMet:
		_everBlocked = true

func _on_player_entered(player: Player) -> void:
	player.setCurrentEncounter(self)

func _runActions(actions : Array[EncounterAction]) -> void:
	for action in actions:
		if action == null:
			continue
		action._finished = false
		action.run(self)
		if action.blocking and !action.isFinished():
			await action.finished

func startEncounter() -> void:
	_has_triggered = true
	EventBus.startEncounter.emit()
	active = true
	_starting = true
	_conditionsMetAtMs = -1
	_everBlocked = false
	for condition in conditions:
		if condition != null:
			condition.reset()
	await _runActions(startActions)
	_starting = false
	# End synchronously when the conditions already pass instead of waiting
	# for the next _process frame: a station that doesn't gate must never
	# stop the player, even for a frame (velocity drops to zero, head bob
	# and weapon sway visibly restart). This reads fresh flags even for
	# enemies the start actions just activated — Enemy.active's setter
	# recomputes visible_to_player on activation. Stations that do gate
	# hold via _process until their conditions stay true.
	if active and !_ending:
		_checkConditions()
		if conditionsMet and _holdSatisfied():
			endEncounter()

func endEncounter() -> void:
	_ending = true
	await _runActions(endActions)
	active = false
	_ending = false
