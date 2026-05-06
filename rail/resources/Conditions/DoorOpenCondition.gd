extends VariableCondition
class_name DoorOpenCondition

## Passes once the named door has opened at least once.
## Companion to EventBus.doorOpened; reads the auto-set
## "door_<name>" Game variable so the check is sticky even if the
## door later closes again.
@export var door_name: String = ""

func check(marker : RailMarker) -> bool:
	if door_name == "":
		return false
	variable_name = "door_" + door_name
	expected_value = "true"
	return super.check(marker)
