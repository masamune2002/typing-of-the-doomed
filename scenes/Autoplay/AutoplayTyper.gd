extends Node
class_name AutoplayTyper

## Simulated typing player for --playthrough autoplay. Instead of skipping
## encounters, it plays for real: picks the most urgent visible target
## (closest enemy > interactable > item), synthesizes a key event for the
## target's next character at a fixed cadence, picks up items
## opportunistically, and retries a level once on death before ending the
## session with a summary.

const KEYS_PER_SEC := 5.0          # ~60 WPM
const LEVEL_TIMEOUT_SECS := 600.0  # hard backstop: report and quit

var _accum := 0.0
var _retries : Dictionary = {}     # map name -> deaths used
var _dead_handled := false
var _level_time := 0.0
var _level_kills := 0
var _level_pickups := 0
var _total_kills := 0
var _total_pickups := 0
var _levels_cleared := 0
var _session_msec : int = 0
# Captured while they're valid: the exit handler runs mid map-teardown,
# when autoplay_map already names the next level and the player is gone.
var _current_map := ""
var _last_health := -1
var _last_armor := -1

func _ready() -> void:
	_session_msec = Time.get_ticks_msec()
	EventBus.enemyKilled.connect(_onEnemyKilled)
	EventBus.levelExitReached.connect(_onLevelExit)
	# Per-LEVEL reset must key off map creation: EventBus.startEncounter is
	# re-emitted by every station along the route.
	if Game.wadLoader != null:
		Game.wadLoader.mapCreated.connect(_onLevelStart)

func _onEnemyKilled(_enemy) -> void:
	_level_kills += 1
	_total_kills += 1

func _onItemPicked(_item) -> void:
	_level_pickups += 1
	_total_pickups += 1

func _onLevelStart() -> void:
	_current_map = Game.wadLoader.map_name
	_level_time = 0.0
	_level_kills = 0
	_level_pickups = 0
	# Items don't announce themselves globally — hook each one's pickup
	# signal. Runs after main's mapCreated handler, so items exist.
	_hookItems.call_deferred()

func _hookItems() -> void:
	for item in get_tree().get_nodes_in_group("Items"):
		if item is Item and not item.pickedUp.is_connected(_onItemPicked):
			item.pickedUp.connect(_onItemPicked)

func _onLevelExit() -> void:
	_levels_cleared += 1
	print("[BOT] LEVEL CLEAR %s: kills=%d pickups=%d health=%d armor=%d time=%.0fs" % [
		_current_map, _level_kills, _level_pickups, _last_health, _last_armor, _level_time])

func _physics_process(delta: float) -> void:
	var player : Player = Game.getPlayer()
	if player == null:
		return

	_level_time += delta
	if _level_time > LEVEL_TIMEOUT_SECS:
		print("[BOT] LEVEL TIMEOUT on %s (kills=%d pickups=%d)" % [
			_current_map, _level_kills, _level_pickups])
		_printFinal("timed out on %s" % _current_map)
		get_tree().quit(1)
		return

	if !player._alive:
		_handleDeath(player)
		return
	_dead_handled = false
	_last_health = player._health
	_last_armor = player._armor

	# A blocking dialog eats fire input — acknowledge it like a player would
	if player._playerUi != null and player._playerUi.dialogBox != null \
			and player._playerUi.dialogBox.showingDialog:
		var ea := InputEventAction.new()
		ea.action = "ui_accept"
		ea.pressed = true
		Input.parse_input_event(ea)
		return

	_accum += delta * KEYS_PER_SEC
	if _accum < 1.0:
		return
	_accum = minf(_accum - 1.0, 1.0)  # never burst more than 1 key per frame

	var target := _pickTarget(player)
	if target == null:
		return
	var ch := _nextChar(target)
	if ch == "":
		return
	# Typing activity counts as progress for the stall detector — long
	# stationary fights are not stalls.
	SettingsManager.autoplay_last_hit_msec = Time.get_ticks_msec()
	var ev := InputEventKey.new()
	ev.pressed = true
	# TypingGun reads as_text_key_label(), which stringifies key_label —
	# synthesized events must set it (keycode alone reads as "(Unset)")
	ev.key_label = OS.find_keycode_from_string(ch.to_upper())
	ev.keycode = ev.key_label
	player._fireWeapon(ev)

func _handleDeath(player: Player) -> void:
	if !player._deathReady or _dead_handled:
		return
	_dead_handled = true
	var mn : String = _current_map
	var used : int = _retries.get(mn, 0)
	print("[BOT] DIED on %s after %.0fs (kills=%d pickups=%d, retry %d used)" % [
		mn, _level_time, _level_kills, _level_pickups, used])
	if used >= 1:
		_printFinal("died twice on %s" % mn)
		get_tree().quit(0)
		return
	_retries[mn] = used + 1
	_level_time = 0.0
	# Mirror Player._input's any-key death restart
	player._deathReady = false
	player._playerUi.closeGameOver()
	player.set_process_input(false)
	Game.restartLevel()

func _printFinal(reason: String) -> void:
	var mins := (Time.get_ticks_msec() - _session_msec) / 60000.0
	print("[BOT] SESSION OVER (%s): levels_cleared=%d kills=%d pickups=%d elapsed=%.1f min" % [
		reason, _levels_cleared, _total_kills, _total_pickups, mins])

# ── Target selection ─────────────────────────────────────────────────────

func _pickTarget(player: Player) -> Node3D:
	# A locked target receives every keystroke first, so always finish it
	var locked = player._currentFireTarget
	if locked != null and is_instance_valid(locked) and _isTypeable(locked):
		return locked
	var candidates := player._getVisibleTargets()
	# Closest enemy is the most urgent threat
	var best : Node3D = null
	var best_d := INF
	for c in candidates:
		if c is Enemy and _isTypeable(c):
			var d : float = c.global_position.distance_to(player.global_position)
			if d < best_d:
				best = c
				best_d = d
	if best != null:
		return best
	# Then progression (doors/switches/lifts/exits), then loot
	for c in candidates:
		if c is Interactable and _isTypeable(c):
			return c
	for c in candidates:
		if not (c is Enemy) and not (c is Interactable) and _isTypeable(c):
			return c
	return null

func _isTypeable(t: Node3D) -> bool:
	if t is Enemy:
		if !(t.alive and t.active and !t.dying and t.visible_to_player):
			return false
	elif "alive" in t and "active" in t and "visible_to_player" in t:
		if !(t.alive and t.active and t.visible_to_player):
			return false
	var w = _weaknessOf(t)
	return w != null and w.getFirstFullHitPoint() != null

func _weaknessOf(t: Node3D) -> Weakness:
	if t is Enemy:
		return t.weaknesses.get(Enums.WEAPON_FIRE_TYPE.TYPING)
	if "weakness" in t:
		return t.weakness
	return null

func _nextChar(t: Node3D) -> String:
	var w := _weaknessOf(t)
	if w == null:
		return ""
	var hp := w.getFirstFullHitPoint()
	if hp == null:
		return ""
	return hp.toString()
