extends Resource
class_name EncounterCondition

var met : bool = false

## Called by EncounterPoint when its encounter (re)starts, before start
## actions run. Subclasses clear any per-encounter state here.
func reset() -> void:
	met = false

func check(_marker : RailMarker) -> bool:
	return false
