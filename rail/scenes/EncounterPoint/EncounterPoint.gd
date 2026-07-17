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
	# Pass-through stations (no conditions) never hold, and neither do
	# debug skip runs (autoplay route validation visits hundreds of
	# stations; 0.5s each would add minutes per map).
	if conditions == null or conditions.is_empty():
		return true
	if SettingsManager != null and SettingsManager.debug_skip_encounters:
		return true
	return Time.get_ticks_msec() - _conditionsMetAtMs >= CONDITIONS_HOLD_SECS * 1000.0

func _checkConditions() -> void:
	if _checksSuspended():
		conditionsMet = false
		return
	conditionsMet = _checkConditionsOnce()

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
	for condition in conditions:
		if condition != null:
			condition.reset()
	await _runActions(startActions)
	_starting = false
	# End synchronously when the conditions already pass instead of waiting
	# for the next _process frame: a pass-through rail station otherwise
	# stops the player for a frame on every hop (velocity drops to zero,
	# head bob and weapon sway visibly restart). Gated stations skip one
	# physics frame instead — enemies activated by the start actions have
	# visible_to_player forced false until their next physics tick, so an
	# immediate check would read all of them as cleared — and then hold via
	# _process until their conditions stay true.
	if active and !_ending:
		if conditions == null or conditions.is_empty():
			_checkConditions()
			if conditionsMet:
				endEncounter()
		else:
			_checkAfterPhysicsFrame = maxi(_checkAfterPhysicsFrame, Engine.get_physics_frames() + 1)

func endEncounter() -> void:
	_ending = true
	await _runActions(endActions)
	active = false
	_ending = false
