extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 6

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot

func save_game(slot: int, save_name: String, map_idx: int, player: Player, dead_entities: Array = []) -> bool:
	var data = {
		"version": 1,
		"name": save_name,
		"map_idx": map_idx,
		"map_name": player.get_tree().current_scene.MAP_NAMES[map_idx],
		"player": player.getState(),
		"dead_entities": dead_entities
	}
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_string)
	return true

func load_save(slot: int) -> Dictionary:
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data

func get_all_slots() -> Array[Dictionary]:
	var slots : Array[Dictionary] = []
	for i in MAX_SLOTS:
		slots.append(load_save(i))
	return slots
