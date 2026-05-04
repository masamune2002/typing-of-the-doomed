extends Resource
class_name WadGame

# WAD file
@export var wad_file_name: String = ""
@export var wad_res_path: String = ""

# Maps
@export var map_names: Array[String] = []
@export var first_map_idx: int = 0

# Thing types
@export var thing_type_player_start: int = 1
@export var barrel_thing_type: int = -1

# Scenes
@export var player_scene: PackedScene
@export var animated_sprite_script: GDScript

# Entity definitions — populated by subclass
var enemies: Dictionary = {}
var item_definitions: Dictionary = {}
var decoration_definitions: Dictionary = {}
var decoration_lights: Dictionary = {}
var weapon_pickup_definitions: Dictionary = {}

# Key system
var keys: Dictionary = {}              # key_id -> display_name
var key_equivalents: Dictionary = {}   # key_id -> [equivalent key_ids]
var key_map: Dictionary = {}           # key_id -> [slot, card_tex_idx, skull_tex_idx]
var key_type_to_id: Dictionary = {}    # WAD keyType int -> key_id string

# WAD node/group names (standard godotWad addon structure)
const GROUP_LEVEL = "level"
const GROUP_INTERACTABLES = "Interactables"
const GROUP_LEVEL_OBJECT = "levelObject"
const NODE_ENTITIES = "Entities"
const NODE_GEOMETRY = "Geometry"
const NODE_INTERACTABLES = "Interactables"
const SECTOR_PREFIX_UPPER = "Sector "
const SECTOR_PREFIX_LOWER = "sector "
const INTERACTABLES_SECTOR_PATH = "Interactables/Sector "

# WAD data keys
const KEY_THINGS_PARSED = "thingsParsed"
const KEY_SECTORS_PARSED = "sectorsParsed"
const KEY_SECTOR_TO_INTERACTION = "sectorToInteraction"
const KEY_FLOOR_HEIGHT = "floorHeight"
const KEY_SECTOR = "sector"

# WAD node property names
const PROP_TRIGGER_TYPE = "triggerType"
const PROP_KEY_TYPE = "keyType"
const PROP_SECRET = "secret"
const PROP_OVERLAPPING_BODIES = "overlappingBodies"
const PROP_WALK_OVER_BODIES = "walkOverBodies"
const PROP_SECTOR_INFO = "sectorInfo"
const PROP_TARGETS = "targets"
const PROP_LINE_START = "lineStart"
const PROP_LINE_END = "lineEnd"
const PROP_CUR_H = "curH"

# WAD script suffixes
const SCRIPT_LEVEL_CHANGE = "levelChange.gd"
const SCRIPT_LIFT = "lift.gd"
const SCRIPT_STAIRS = "stairs.gd"
