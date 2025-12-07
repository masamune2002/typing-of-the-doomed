extends EncounterAction
class_name PrintAction

@export var stringToPrint : String
const DEFAULT_MESSAGE : String = "Hello, World!"

func run(_encounterPoint : EncounterPoint) -> void:

	if stringToPrint == null:
		print(DEFAULT_MESSAGE)
		return
	var packedString = stringToPrint.strip_edges()
	if packedString == '':
		print(DEFAULT_MESSAGE)
		return
	else:
		print(packedString)
	finish()
