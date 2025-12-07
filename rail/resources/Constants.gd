extends Resource
class_name Constants

const CHORD_TYPES : Array[Dictionary] = [
	{"suffix":"maj7", "intervals":[0,4,7,11], "difficulty": 5},
	{"suffix":"m7",   "intervals":[0,3,7,10], "difficulty": 6},
	{"suffix":"7",    "intervals":[0,4,7,10], "difficulty": 6},
	{"suffix":"m7b5", "intervals":[0,3,6,10], "difficulty": 6},
	{"suffix":"dim7", "intervals":[0,3,6,9], "difficulty": 5},
	{"suffix":"maj",  "intervals":[0,4,7], "difficulty": 1},
	{"suffix":"m",    "intervals":[0,3,7], "difficulty": 2},
	{"suffix":"aug",  "intervals":[0,4,8], "difficulty": 3},
	{"suffix":"dim",  "intervals":[0,3,6], "difficulty": 4},
	{"suffix":"", "intervals":[0], "difficulty": 0}
]

const SCALE_TYPES : Array[Dictionary] = [
	{"name": "Major", "intervals": [0, 2, 4, 5, 7, 9, 11], "difficulty": 0},
	{"name": "Minor", "intervals": [0, 2, 3, 5, 7, 8, 10], "difficulty": 1}
]

const PITCH_NAMES : Array[String] = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
