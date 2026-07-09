extends WadGame
class_name DoomGame

# ── Sounds ───────────────────────────────────────────────────────────────

# Menu
const MENU_NAVIGATE = "DSPSTOP"
const MENU_CONFIRM = "DSPISTOL"
const MENU_INVALID = "DSOOF"

# Doors & switches
const DOOR_OPEN = "DSDOROPN"
const SWITCH_ON = "DSSWTCHN"
const SWITCH_OFF = "DSSWTCHX"

# Combat
const BARREL_EXPLODE = "DSBAREXP"
const PLAYER_DEATH = "DSPLDETH"
const PLAYER_PAIN = "DSPLPAIN"
const DEMON_ACTIVE = "DSDMACT"

# Pickups
const WEAPON_PICKUP = "DSWPNUP"
const ITEM_PICKUP = "DSITEMUP"
const CHAINSAW_PICKUP = "DSSAWUP"
const POWERUP_PICKUP = "DSGETPOW"

# ── Sprites ──────────────────────────────────────────────────────────────

const TITLE_SCREEN = "TITLEPIC"
const SKULL_1 = "M_SKULL1"
const SKULL_2 = "M_SKULL2"
const STATUS_BAR = "STBAR"
const INTERMISSION_BG = "INTERPIC"

# ── Colors ───────────────────────────────────────────────────────────────

const COLOR_GOLD := Color(1.0, 0.8, 0.2)
const COLOR_RED := Color(1.0, 0.2, 0.2)
const COLOR_WHITE := Color(1.0, 1.0, 1.0)
const COLOR_HEALTH := Color(0.2, 1.0, 0.2)
const COLOR_ARMOR := Color(0.2, 0.5, 1.0)
const COLOR_WEAPON := Color(1.0, 0.6, 0.2)
const COLOR_BARREL := Color(1.0, 0.4, 0.1)

# ── Maps ─────────────────────────────────────────────────────────────────

const MAP_NAMES_CONST: Array[String] = ["E1M1", "E1M2", "E1M3", "E1M4", "E1M5", "E1M6", "E1M7", "E1M8", "E1M9"]
const MAP_DESCRIPTIONS = {
	"E1M1": "Hangar",
	"E1M2": "Nuclear Plant",
	"E1M3": "Toxin Refinery",
	"E1M4": "Command Control",
	"E1M5": "Phobos Lab",
	"E1M6": "Central Processing",
	"E1M7": "Computer Station",
	"E1M8": "Phobos Anomaly",
	"E1M9": "Military Base (Secret)",
}

# ── Thing Flags ──────────────────────────────────────────────────────────

const THING_FLAG_HARD = 0b100       # Appears on Hard (UV) difficulty
const THING_FLAG_MULTIPLAYER = 0b10000  # Multiplayer only (not single player)

# ── Keys ─────────────────────────────────────────────────────────────────

const RED_CARD = "red_keycard"
const BLUE_CARD = "blue_keycard"
const YELLOW_CARD = "yellow_keycard"
const RED_SKULL = "red_skull"
const BLUE_SKULL = "blue_skull"
const YELLOW_SKULL = "yellow_skull"

func _init():
	wad_file_name = "DOOM.wad"
	wad_res_path = "res://DOOM.wad"
	map_names = MAP_NAMES_CONST
	first_map_idx = 0
	thing_type_player_start = 1
	barrel_thing_type = 2035
	player_scene = preload("res://scenes/DoomPlayer/DoomPlayer.tscn")
	animated_sprite_script = preload("res://scenes/AnimatedSprite/AnimatedDoomSprite.gd")

	enemies = {
		3004: { "name": "Zombieman",    "scene": preload("res://wads/doom/enemies/Zombieman/Zombieman.tscn") },
		9:    { "name": "ShotgunGuy",   "scene": preload("res://wads/doom/enemies/ShotgunGuy/ShotgunGuy.tscn") },
		3001: { "name": "Imp",          "scene": preload("res://wads/doom/enemies/Imp/Imp.tscn"),                "npc_trigger": "imp" },
		3002: { "name": "Pinky",        "scene": preload("res://wads/doom/enemies/Pinky/Pinky.tscn") },
		3005: { "name": "Cacodemon",    "scene": preload("res://wads/doom/enemies/Cacodemon/Cacodemon.tscn"),    "npc_trigger": "cacodemon" },
		3003: { "name": "BaronOfHell",  "scene": preload("res://wads/doom/enemies/BaronOfHell/BaronOfHell.tscn"),"npc_trigger": "baron of hell" },
		3006: { "name": "LostSoul",     "scene": preload("res://wads/doom/enemies/LostSoul/LostSoul.tscn") },
		16:   { "name": "Cyberdemon",   "scene": preload("res://wads/doom/enemies/Cyberdemon/Cyberdemon.tscn"),  "npc_trigger": "cyberdemon" },
		7:    { "name": "SpiderDemon",  "scene": preload("res://wads/doom/enemies/SpiderDemon/SpiderDemon.tscn"),"npc_trigger": "spider mastermind" },
	}

	item_definitions = {
		2011: { "name": "Stimpack",    "sprites": ["STIMA0"],                                 "effect": "health", "amount": 10,  "overheal": false, "sound": ITEM_PICKUP },
		2012: { "name": "Medkit",      "sprites": ["MEDIA0"],                                 "effect": "health", "amount": 25,  "overheal": false, "sound": ITEM_PICKUP },
		2013: { "name": "Soulsphere",  "sprites": ["SOULA0", "SOULB0", "SOULC0", "SOULD0"],   "effect": "health", "amount": 100, "overheal": true,  "sound": POWERUP_PICKUP },
		2014: { "name": "HealthBonus", "sprites": ["BON1A0", "BON1B0", "BON1C0", "BON1D0"],   "effect": "health", "amount": 1,   "overheal": true,  "sound": ITEM_PICKUP },
		2015: { "name": "ArmorBonus",  "sprites": ["BON2A0", "BON2B0", "BON2C0", "BON2D0"],   "effect": "armor",  "amount": 1,   "armor_type": "NONE",  "sound": ITEM_PICKUP },
		2018: { "name": "GreenArmor",  "sprites": ["ARM1A0", "ARM1B0"],                       "effect": "armor",  "amount": 100, "armor_type": "GREEN", "sound": ITEM_PICKUP },
		2019: { "name": "BlueArmor",   "sprites": ["ARM2A0"],                                 "effect": "armor",  "amount": 200, "armor_type": "BLUE",  "sound": POWERUP_PICKUP },
		5:    { "name": "BlueKeycard",  "sprites": ["BKEYA0", "BKEYB0"],                       "effect": "key", "key": BLUE_CARD,    "sound": ITEM_PICKUP },
		6:    { "name": "YellowKeycard","sprites": ["YKEYA0", "YKEYB0"],                       "effect": "key", "key": YELLOW_CARD,  "sound": ITEM_PICKUP },
		13:   { "name": "RedKeycard",   "sprites": ["RKEYA0", "RKEYB0"],                       "effect": "key", "key": RED_CARD,     "sound": ITEM_PICKUP },
		40:   { "name": "BlueSkullKey", "sprites": ["BSKUA0", "BSKUB0"],                       "effect": "key", "key": BLUE_SKULL,   "sound": ITEM_PICKUP },
		38:   { "name": "YellowSkullKey","sprites": ["YSKUA0", "YSKUB0"],                      "effect": "key", "key": YELLOW_SKULL, "sound": ITEM_PICKUP },
		39:   { "name": "RedSkullKey",  "sprites": ["RSKUA0", "RSKUB0"],                       "effect": "key", "key": RED_SKULL,    "sound": ITEM_PICKUP },
	}

	decoration_definitions = {
		2028: { "name": "FloorLamp",      "sprites": ["COLUA0"],                         "blocking": true },
		2035: { "name": "ExplodingBarrel","sprites": ["BAR1A0", "BAR1B0"],               "blocking": true },
		35:   { "name": "Candelabra",     "sprites": ["CBRAA0"],                         "blocking": true },
		48:   { "name": "TallTechnoPillar","sprites": ["ELECA0"],                        "blocking": true },
		2048: { "name": "TallTechColumn", "sprites": ["COL1A0"],                         "blocking": true },
		2046: { "name": "BurningBarrel",  "sprites": ["FCANA0", "FCANB0", "FCANC0"],     "blocking": true },
		30:   { "name": "TallGreenPillar2","sprites": ["COL1A0"],                        "blocking": true },
		31:   { "name": "ShortGreenPillar","sprites": ["COL2A0"],                        "blocking": true },
		32:   { "name": "TallRedPillar",  "sprites": ["COL4A0"],                         "blocking": true },
		33:   { "name": "ShortRedPillar", "sprites": ["COL6A0"],                         "blocking": true },
		34:   { "name": "Candle",         "sprites": ["CANDA0"],                         "blocking": false },
		44:   { "name": "TallBlueTorch",  "sprites": ["TBLUA0", "TBLUB0", "TBLUC0", "TBLUD0"], "blocking": true },
		45:   { "name": "TallGreenTorch", "sprites": ["TGRNA0", "TGRNB0", "TGRNC0", "TGRND0"], "blocking": true },
		46:   { "name": "TallRedTorch",   "sprites": ["Treda0", "TREDB0", "TREDC0", "TREDD0"], "blocking": true },
		55:   { "name": "ShortBlueTorch", "sprites": ["SMBTA0", "SMBTB0", "SMBTC0", "SMBTD0"], "blocking": true },
		56:   { "name": "ShortGreenTorch","sprites": ["SMGTA0", "SMGTB0", "SMGTC0", "SMGTD0"], "blocking": true },
		57:   { "name": "ShortRedTorch",  "sprites": ["SMRTA0", "SMRTB0", "SMRTC0", "SMRTD0"], "blocking": true },
		47:   { "name": "Stalagtite",     "sprites": ["SMITA0"],                         "blocking": true },
		43:   { "name": "BurntTree",      "sprites": ["TRE1A0"],                         "blocking": true },
		54:   { "name": "BigTree",        "sprites": ["TRE2A0"],                         "blocking": true },
		10:   { "name": "BloodyMess",     "sprites": ["PLAYW0"],                         "blocking": false },
		12:   { "name": "BloodyMess2",    "sprites": ["PLAYW0"],                         "blocking": false },
		15:   { "name": "DeadPlayer",     "sprites": ["PLAYN0"],                         "blocking": false },
		18:   { "name": "DeadZombieman",  "sprites": ["POSSN0"],                         "blocking": false },
		19:   { "name": "DeadShotgunGuy", "sprites": ["SPOTN0"],                         "blocking": false },
		20:   { "name": "DeadImp",        "sprites": ["TROOM0"],                         "blocking": false },
		21:   { "name": "DeadDemon",      "sprites": ["SARGN0"],                         "blocking": false },
		22:   { "name": "DeadCacodemon",  "sprites": ["HEADL0"],                         "blocking": false },
		23:   { "name": "DeadLostSoul",   "sprites": ["SKULK0"],                         "blocking": false },
		24:   { "name": "PoolOfFlesh",    "sprites": ["POL5A0"],                         "blocking": false },
		25:   { "name": "ImpaledHuman",   "sprites": ["POL1A0"],                         "blocking": true },
		26:   { "name": "TwitchingImpaled","sprites": ["POL6A0", "POL6B0"],              "blocking": true },
		27:   { "name": "SkullPole",      "sprites": ["POL4A0"],                         "blocking": true },
		28:   { "name": "SkullShishKebab","sprites": ["POL2A0"],                         "blocking": true },
		29:   { "name": "SkullsOnPole",   "sprites": ["POL3A0", "POL3B0"],              "blocking": true },
		49:   { "name": "HangingBody1",   "sprites": ["GOR1A0"],                         "blocking": true },
		50:   { "name": "HangingBody2",   "sprites": ["GOR2A0"],                         "blocking": false },
		51:   { "name": "HangingBody3",   "sprites": ["GOR3A0"],                         "blocking": false },
		52:   { "name": "HangingBody4",   "sprites": ["GOR4A0"],                         "blocking": false },
		53:   { "name": "HangingBody5",   "sprites": ["GOR5A0"],                         "blocking": true },
		73:   { "name": "HangingLeg",     "sprites": ["HDB1A0"],                         "blocking": true },
		74:   { "name": "HangingLeg2",    "sprites": ["HDB2A0"],                         "blocking": false },
		75:   { "name": "HangingVictim",  "sprites": ["HDB3A0"],                         "blocking": false },
		76:   { "name": "HangingArms",    "sprites": ["HDB4A0"],                         "blocking": false },
		77:   { "name": "HangingLeg3",    "sprites": ["HDB5A0"],                         "blocking": false },
		78:   { "name": "HangingLeg4",    "sprites": ["HDB6A0"],                         "blocking": false },
	}

	decoration_lights = {
		2028: { "color": Color(1.0, 1.0, 0.8), "energy": 8.0, "range": 12.0 },
		35:   { "color": Color(1.0, 0.9, 0.6), "energy": 8.0, "range": 12.0 },
		34:   { "color": Color(1.0, 0.85, 0.5), "energy": 3.0, "range": 6.0 },
		2046: { "color": Color(1.0, 0.6, 0.2), "energy": 8.0, "range": 10.0 },
		44:   { "color": Color(0.4, 0.5, 1.0), "energy": 6.0, "range": 10.0 },
		45:   { "color": Color(0.3, 1.0, 0.3), "energy": 6.0, "range": 10.0 },
		46:   { "color": Color(1.0, 0.3, 0.2), "energy": 6.0, "range": 10.0 },
		55:   { "color": Color(0.4, 0.5, 1.0), "energy": 4.0, "range": 8.0 },
		56:   { "color": Color(0.3, 1.0, 0.3), "energy": 4.0, "range": 8.0 },
		57:   { "color": Color(1.0, 0.3, 0.2), "energy": 4.0, "range": 8.0 },
	}

	weapon_pickup_definitions = {
		2001: { "name": "Shotgun",        "sprites": ["SHOTA0"],             "weapon_scene": preload("res://wads/doom/weapons/Shotgun/Shotgun.tscn"),        "sound": WEAPON_PICKUP },
		2002: { "name": "Chaingun",       "sprites": ["MGUNA0"],             "weapon_scene": preload("res://wads/doom/weapons/Chaingun/Chaingun.tscn"),      "sound": WEAPON_PICKUP },
		2003: { "name": "RocketLauncher", "sprites": ["LAUNA0"],             "weapon_scene": preload("res://wads/doom/weapons/RocketLauncher/RocketLauncher.tscn"), "sound": WEAPON_PICKUP },
		2004: { "name": "PlasmaRifle",    "sprites": ["PLASA0"],             "weapon_scene": preload("res://wads/doom/weapons/PlasmaRifle/PlasmaRifle.tscn"),"sound": WEAPON_PICKUP },
		2005: { "name": "Chainsaw",       "sprites": ["CSAWA0"],             "weapon_scene": preload("res://wads/doom/weapons/Chainsaw/Chainsaw.tscn"),      "sound": CHAINSAW_PICKUP },
		2006: { "name": "BFG9000",        "sprites": ["BFUGA0"],             "weapon_scene": preload("res://wads/doom/weapons/BFG/BFG.tscn"),                "sound": WEAPON_PICKUP },
	}

	key_equivalents = {
		BLUE_CARD: [BLUE_CARD, BLUE_SKULL],
		YELLOW_CARD: [YELLOW_CARD, YELLOW_SKULL],
		RED_CARD: [RED_CARD, RED_SKULL],
	}

	key_type_to_id = {
		0: RED_CARD,
		2: BLUE_CARD,
		3: YELLOW_CARD,
	}

	key_map = {
		BLUE_CARD: [0, 0, -1],
		BLUE_SKULL: [0, -1, 3],
		YELLOW_CARD: [1, 1, -1],
		YELLOW_SKULL: [1, -1, 4],
		RED_CARD: [2, 2, -1],
		RED_SKULL: [2, -1, 5],
	}
