extends PanelContainer
class_name DialogBox

@export var dialog : Dialog
var currentPage = -1
var showingDialog = false
var speaker : PlayerCharacter

func showDialog(newDialog : Dialog) -> void:
	dialog = newDialog
	if dialog.lines.size() == 0:
		return
	currentPage = 0
	showingDialog = true
	_showCurrentPage()
	if newDialog.speakerIsPlayer:
		var playerCharacter = Game.getPlayer().playerCharacter
		%NameLabel.text = playerCharacter.name
		%SpeakerPortrait.texture = playerCharacter.portrait
	else:
		%NameLabel.text = newDialog.speaker.name
		%SpeakerPortrait.texture = newDialog.speaker.portrait

func _showCurrentPage() -> void:
	%DialogTextLabel.text = dialog.lines[currentPage]

func showNextPage() -> void:
	if currentPage >= dialog.lines.size() - 1:
		showingDialog = false
		dialog.actionToFinish.finished.emit()
	else:
		currentPage += 1
		_showCurrentPage()
