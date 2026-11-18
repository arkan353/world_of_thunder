# Static catalogue of the upgrades the player can pick between waves.
# The actual effect is applied by the player in CharacterBody2D.apply_perk().
class_name Perks

enum Id { VAMPIRISM, EXTRA_DAMAGE, MULTIFIRE, SHIELD }

## How many times each perk can be taken.
const MAX_STACKS := {
	Id.VAMPIRISM: 5,
	Id.EXTRA_DAMAGE: 8,
	Id.MULTIFIRE: 1,
	Id.SHIELD: 5,
}

const DATA := {
	Id.VAMPIRISM: {
		"name": "Вампиризм",
		"desc": "+15% здоровья от нанесённого урона. Стакается.",
	},
	Id.EXTRA_DAMAGE: {
		"name": "Доп. урон",
		"desc": "+25% урона снарядов. Усиливает вампиризм.",
	},
	Id.MULTIFIRE: {
		"name": "Мультипламя",
		"desc": "Q: круговой залп, снаряды пробивают всех. КД 60 сек.",
	},
	Id.SHIELD: {
		"name": "Щит",
		"desc": "+40 щита. Щит восстанавливается вне боя.",
	},
}

static func title(id: int) -> String:
	return DATA[id]["name"]

static func description(id: int) -> String:
	return DATA[id]["desc"]

static func all_ids() -> Array:
	return [Id.VAMPIRISM, Id.EXTRA_DAMAGE, Id.MULTIFIRE, Id.SHIELD]

static func max_stacks(id: int) -> int:
	return MAX_STACKS[id]