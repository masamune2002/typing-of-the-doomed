extends SleepAction
class_name SleepForTargetsAction

## SleepAction that only sleeps while a consumable pickup - health, armor,
## ammo or a weapon - is on screen for the player to grab. Enemies, doors,
## switches and barrels don't count: enemies and keys gate their stations
## via conditions, and the rest aren't worth stopping for. When nothing
## qualifies this finishes synchronously, so a pass-through station keeps
## the rail's momentum (see EncounterPoint.startEncounter's sync end).

const PICKUP_EFFECTS : Array[String] = ["health", "armor", "ammo", "weapon"]

func run(encounterPoint : EncounterPoint) -> void:
	if !_pickupOnScreen():
		finish()
		return
	await super.run(encounterPoint)

static func _pickupOnScreen() -> bool:
	var player = Game.getPlayer()
	if player == null:
		return false
	for node in player._getVisibleTargets():
		if node is Item and PICKUP_EFFECTS.has(node.itemDefinition.get("effect", "")):
			return true
	return false
