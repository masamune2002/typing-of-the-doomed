extends EncounterCondition
class_name NearbyEnemiesClearedCondition

## Enemies within this distance of the player must be killed to proceed.
@export var max_distance: float = 20.0

func check(marker : RailMarker) -> bool:
	if SettingsManager != null and SettingsManager.debug_skip_encounters:
		return true
	var player = Game.getPlayer()
	if player == null:
		return true

	for node in player.get_tree().get_nodes_in_group("Enemies"):
		if node is Enemy:
			var enemy: Enemy = node
			if enemy.active and enemy.alive and not enemy.dying and enemy.visible_to_player:
				if enemy.global_position.distance_to(player.global_position) <= max_distance:
					return false
	return true
