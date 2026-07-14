extends EncounterAction
class_name EpisodeFinaleAction

## Ends the episode with the text-wall ending (E2M8's boss arena: the level
## ends when the Cyberdemon falls, there is no exit switch). In autoplay the
## finale counts as level complete, mirroring AdvanceToNextStationAction's
## end-of-rail handling.
func run(encounterPoint : EncounterPoint) -> void:
	if SettingsManager.autoplay:
		print("[AUTOPLAY] DONE map=%s last_station=%s (episode finale)" % [
			SettingsManager.autoplay_map, encounterPoint.name])
		if SettingsManager.autoplay_chain:
			finish()
			EventBus.emit_signal.call_deferred("levelExitReached")
			return
		encounterPoint.get_tree().quit(0)
		return
	EventBus.episodeFinale.emit()
	finish()
