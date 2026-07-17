extends EncounterCondition
class_name NearbyEnemiesClearedCondition

## Enemies within this distance of the player must be killed to proceed.
@export var max_distance: float = 20.0

# Visibility is momentary — the rail camera pans, chasing enemies drift out
# of a frozen frame, the wait system suspends everyone — so an enemy latches
# as a blocker the first frame it is seen alive in range, and keeps blocking
# through short losses of visibility. Without the latch, any single frame
# with no visible enemy reads as "encounter cleared".
#
# The latch expires after ~3s of continuous invisibility: an enemy that has
# genuinely wandered off can't be typed at, so holding the rail on it would
# soft-lock the encounter (E1M2 Station24 stalled exactly this way). Expiry
# is measured in check ticks, not wall-clock time — checks are suspended
# while the wait system is active, so sitting in the pause menu must not
# age the latch. Enemies the rail never reveals still never gate.
const OFFSCREEN_GRACE_CHECKS := 180  # ~3s at one check per process frame

var _engaged : Dictionary = {}
var _tick : int = 0

func reset() -> void:
	super()
	_engaged.clear()
	_tick = 0

func check(_marker : RailMarker) -> bool:
	if SettingsManager != null and SettingsManager.debug_skip_encounters:
		return true
	var player = Game.getPlayer()
	if player == null:
		return true

	_tick += 1
	var blocked := false
	# Scan every enemy (no early exit): visible blockers must refresh their
	# latch timestamps even while another enemy is already blocking, or
	# they'd expire mid-fight and stop gating the moment the first one dies.
	for node in player.get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy:
			var enemy: Enemy = node
			var id := enemy.get_instance_id()
			if not enemy.alive or enemy.dying:
				_engaged.erase(id)
				continue
			if enemy.active and enemy.visible_to_player \
					and enemy.global_position.distance_to(player.global_position) <= max_distance:
				_engaged[id] = _tick
				blocked = true
			elif _engaged.has(id):
				if _tick - _engaged[id] <= OFFSCREEN_GRACE_CHECKS:
					blocked = true
				else:
					_engaged.erase(id)
	return not blocked
