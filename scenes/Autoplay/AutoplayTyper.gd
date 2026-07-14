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
const INTERACTABLE_COOLDOWN_MSEC := 10000  # don't re-type a completed door

var _accum := 0.0
var _cooldown : Dictionary = {}         # interactable instance id -> msec usable again
var _last_itarget : Node3D = null       # last interactable we typed at
var _last_itarget_rem : int = 0         # its remaining chars at our last keystroke
var _futile : Dictionary = {}           # instance id -> re-arms seen this station
var _futile_enc : Node = null           # encounter the futility counts belong to
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

	# A completed interactable re-arms when its door closes; without a
	# cooldown the bot re-opens it forever and starves item pickups.
	if _last_itarget != null and (!is_instance_valid(_last_itarget) or !_isTypeable(_last_itarget)):
		if is_instance_valid(_last_itarget):
			_cooldown[_last_itarget.get_instance_id()] = Time.get_ticks_msec() + INTERACTABLE_COOLDOWN_MSEC
		_last_itarget = null
	elif _last_itarget != null and _remaining(_last_itarget) >= _last_itarget_rem:
		# Remaining didn't shrink: the word re-armed between our keystrokes
		# (a 1-char word resets to the same length). Some doors refuse to
		# move (E1M4's walk-only ambush closets) and reset within a frame —
		# faster than the completion check above can see. A few strikes and
		# the door is futile for this station. (Don't null _last_itarget:
		# stolen keystrokes are possible, so let the count accumulate.)
		var fid := _last_itarget.get_instance_id()
		_futile[fid] = _futile.get(fid, 0) + 1
	# Futility is judged per station: a door that's useless for this gate
	# may be exactly what the next one needs.
	if player.currentEncounter != _futile_enc:
		_futile_enc = player.currentEncounter
		_futile.clear()

	var target := _pickTarget(player)
	if target is Interactable:
		_last_itarget = target
		_last_itarget_rem = _remaining(target)
	if target == null:
		# Nothing typeable on screen. The camera is rail-driven (mouse-look
		# is a debug tool, not a player ability), so the bot must NOT look
		# around — if a gate's key or switch is off-screen here, that's a
		# level bug the stall detector should surface.
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
	# Interactables (doors/lifts/switches) are only fair game when the route
	# actually demands one: the current station's gate is unmet, or the rail
	# is physically blocked (door closed in our face mid-ride). Typing every
	# visible interactable toggles lifts under the player's own feet and
	# drops them off-route (E1M2's lift shaft).
	var wants_interactable : bool = \
		(player.currentEncounter != null and player.currentEncounter.active \
			and !player.currentEncounter.conditionsMet) \
		or (player._moving and player._stuck_frames > 30)
	# A locked target receives every keystroke first, so finish it — unless
	# it's an interactable we should no longer be touching, or a barrel
	# (a stray matched char can lock one; finishing it blows up in our face).
	var locked = player._currentFireTarget
	if locked != null and is_instance_valid(locked) and _isTypeable(locked):
		if locked is ExplodingBarrel or (locked is Interactable and not wants_interactable):
			player._clearFireTarget()
		else:
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
	# Keys outrank everything but enemies: gates literally wait on them, and
	# a dud door must never starve the key pickup.
	for c in candidates:
		if c is Item and _isTypeable(c) and c.itemDefinition.get("effect", "") == "key":
			return c
	# Then progression (doors/switches/lifts/exits), then loot
	if wants_interactable:
		var blocked : bool = player._moving and player._stuck_frames > 30
		var now := Time.get_ticks_msec()
		for c in candidates:
			if c is Interactable and _isTypeable(c):
				# Recently-completed doors are exhausted leads, and a door
				# that re-armed twice without its gate passing is a dud
				# (walk-only ambush closets) — skip both, unless the rail
				# is physically blocked and needs a door NOW
				if !blocked and _cooldown.get(c.get_instance_id(), 0) > now:
					continue
				if _futile.get(c.get_instance_id(), 0) >= 3:
					continue
				return c
	for c in candidates:
		if c is ExplodingBarrel:
			# Never type barrels: the bot fights at close range and the
			# splash damage costs more health than the barrel is worth.
			continue
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

func _remaining(t: Node3D) -> int:
	var w = _weaknessOf(t)
	if w == null:
		return 0
	var n := 0
	for hp in w.hitPoints:
		if hp.full:
			n += 1
	return n

func _nextChar(t: Node3D) -> String:
	var w := _weaknessOf(t)
	if w == null:
		return ""
	var hp := w.getFirstFullHitPoint()
	if hp == null:
		return ""
	return hp.toString()
