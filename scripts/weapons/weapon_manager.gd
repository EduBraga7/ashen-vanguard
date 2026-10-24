extends Node3D
class_name WeaponManager
## Gerencia as armas ativas (nós filhos com auto-ataque) e os itens passivos do herói.
## Vive como filho do Knight. Cada arma expõe `set_level(level: int)`.

signal inventory_changed

const MAX_LEVEL: int = 5
const HEAL_ID: String = "heal"

const DEFS: Dictionary = {
	"orbit_blades": {
		"title": "Espadas Espectrais", "kind": "weapon", "max": 5,
		"scene": preload("res://scenes/weapons/orbit_blades.tscn"),
		"first": "Lâminas espectrais giram ao redor do Cavaleiro.",
		"up": "+1 espada, órbita mais larga e mais dano.",
	},
	"magic_darts": {
		"title": "Dardos Mágicos", "kind": "weapon", "max": 5,
		"scene": preload("res://scenes/weapons/magic_darts.tscn"),
		"first": "Dardos arcanos miram sozinhos no inimigo mais próximo.",
		"up": "Mais dardos por rajada, mais dano e recarga menor.",
	},
	"battle_axe": {
		"title": "Machado de Batalha", "kind": "weapon", "max": 5,
		"scene": preload("res://scenes/weapons/battle_axe.tscn"),
		"first": "Machado arremessado ao alto cai em arco e racha o chão em área.",
		"up": "Mais dano, área de impacto maior e mais machados.",
	},
	"fire_flask": {
		"title": "Frasco de Fogo", "kind": "weapon", "max": 5,
		"scene": preload("res://scenes/weapons/fire_flask.tscn"),
		"first": "Cria uma poça de chamas por 3s que queima quem pisar nela.",
		"up": "Poça maior, mais dano por tique e mais frascos.",
	},
	"magnet_amulet": {
		"title": "Amuleto de Ímã", "kind": "passive", "max": 5,
		"first": "Raio de coleta de cristais +30%.",
		"up": "Raio de coleta de cristais +30%.",
	},
	"agile_boots": {
		"title": "Botas Ágeis", "kind": "passive", "max": 5,
		"first": "Velocidade de movimento +10%.",
		"up": "Velocidade de movimento +10%.",
	},
	"iron_shield": {
		"title": "Escudo de Ferro", "kind": "passive", "max": 3,
		"first": "+1 de Armadura e regenera 1 HP a cada 5s.",
		"up": "+1 de Armadura e +1 HP a cada 5s.",
	},
}

@export var starting_weapon: String = "orbit_blades"
@export var magnet_bonus_per_level: float = 0.30
@export var speed_bonus_per_level: float = 0.10
@export var shield_armor_per_level: int = 1
@export var shield_regen_seconds_per_hp: float = 5.0
@export var heal_filler_amount: int = 30

var levels: Dictionary = {}

var _weapon_nodes: Dictionary = {}
var _player: Knight:
	get:
		if _player == null:
			_player = get_parent() as Knight
		return _player

func _ready() -> void:
	if starting_weapon != "" and get_level(starting_weapon) == 0:
		add_upgrade(starting_weapon)

func get_level(id: String) -> int:
	return int(levels.get(id, 0))

func get_title(id: String) -> String:
	return DEFS[id]["title"]

## Sobe o item em 1 nível (cria o nó da arma na primeira vez). Retorna o novo nível.
func add_upgrade(id: String) -> int:
	var new_level: int = mini(get_level(id) + 1, int(DEFS[id]["max"]))
	levels[id] = new_level
	if DEFS[id]["kind"] == "weapon":
		if not _weapon_nodes.has(id):
			var weapon: Node = (DEFS[id]["scene"] as PackedScene).instantiate()
			add_child(weapon)
			_weapon_nodes[id] = weapon
		_weapon_nodes[id].set_level(new_level)
	else:
		_apply_passives()
	inventory_changed.emit()
	return new_level

func get_available_ids() -> Array[String]:
	var available: Array[String] = []
	for id in DEFS.keys():
		if get_level(id) < int(DEFS[id]["max"]):
			available.append(id)
	return available

## Sorteia até `count` opções (armas novas/melhorias e passivos). Se faltarem upgrades, completa com cura.
func roll_options(count: int) -> Array[Dictionary]:
	var pool: Array[String] = get_available_ids()
	pool.shuffle()
	var options: Array[Dictionary] = []
	for id in pool.slice(0, count):
		options.append(_describe(id))
	if options.size() < count:
		options.append({
			"id": HEAL_ID, "title": "Banquete", "kind": "heal", "level": 0,
			"description": "Recupera %d HP." % heal_filler_amount,
		})
	return options

## Aplica a opção escolhida no menu de level up. Retorna o texto de log (usado pelo baú).
func apply_option(id: String) -> String:
	if id == HEAL_ID:
		if _player:
			_player.heal(heal_filler_amount)
		return "Banquete: +%d HP" % heal_filler_amount
	var new_level: int = add_upgrade(id)
	return "%s Nv. %d" % [get_title(id), new_level]

## Recompensa do baú: aplica `count` upgrades aleatórios imediatamente e devolve as linhas para exibir.
func grant_random_upgrades(count: int) -> Array[String]:
	var lines: Array[String] = []
	for i in count:
		var pool: Array[String] = get_available_ids()
		if pool.is_empty():
			lines.append(apply_option(HEAL_ID))
		else:
			lines.append(apply_option(pool.pick_random()))
	return lines

func _describe(id: String) -> Dictionary:
	var next_level: int = get_level(id) + 1
	return {
		"id": id,
		"title": DEFS[id]["title"],
		"kind": DEFS[id]["kind"],
		"level": next_level,
		"description": DEFS[id]["first"] if next_level == 1 else DEFS[id]["up"],
	}

func _apply_passives() -> void:
	if not _player:
		return
	var shield_level: int = get_level("iron_shield")
	_player.set_passive_bonuses(
		1.0 + magnet_bonus_per_level * get_level("magnet_amulet"),
		1.0 + speed_bonus_per_level * get_level("agile_boots"),
		shield_armor_per_level * shield_level,
		float(shield_level) / shield_regen_seconds_per_hp)
