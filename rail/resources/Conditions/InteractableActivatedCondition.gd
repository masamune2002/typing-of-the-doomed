extends VariableCondition
class_name InteractableActivatedCondition

## Passes once the named Interactable has been activated (typed-out).
## Companion to EventBus.interactableActivated; reads the auto-set
## "interactable_<name>" Game variable so the check is sticky.
@export var interactable_name: String = ""

func check(encounterPoint: EncounterPoint) -> bool:
	if interactable_name == "":
		return false
	variable_name = "interactable_" + interactable_name
	expected_value = "true"
	return super.check(encounterPoint)
