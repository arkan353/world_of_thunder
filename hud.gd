extends CanvasLayer

## Emitted when the player clicks one of the between-wave perk cards.
signal perk_chosen(perk_id: int)

@onready var health_bar: ProgressBar = $HealthBar
@onready var armor_bar: ProgressBar = $ArmorBar
@onready var shield_bar: ProgressBar = $ShieldBar
@onready var wave_label: Label = $WaveLabel
@onready var message_label: Label = $MessageLabel
@onready var perks_label: Label = $PerksLabel
@onready var multifire_label: Label = $MultifireLabel
@onready var restart_button: Button = $RestartButton
@onready var perk_panel: PanelContainer = $PerkPanel
@onready var perk_buttons: Array[Button] = [
	$PerkPanel/VBox/Perk0,
	$PerkPanel/VBox/Perk1,
	$PerkPanel/VBox/Perk2,
]

var max_hp: int = 100
var current_hp: int = 100
var max_armor: int = 0
var current_armor: int = 0
var max_shield: int = 0
var current_shield: int = 0

var _offer: Array = []

func _ready() -> void:
	add_to_group("hud")
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	armor_bar.max_value = maxi(max_armor, 1)
	armor_bar.value = current_armor
	armor_bar.visible = max_armor > 0
	shield_bar.max_value = maxi(max_shield, 1)
	shield_bar.value = current_shield
	shield_bar.visible = max_shield > 0
	message_label.visible = false
	restart_button.visible = false
	perk_panel.visible = false
	perks_label.text = ""
	multifire_label.text = ""
	restart_button.pressed.connect(_on_restart_pressed)
	for i in perk_buttons.size():
		perk_buttons[i].pressed.connect(_on_perk_button.bind(i))

# --- Health ---

func set_max_hp(value: int) -> void:
	max_hp = maxi(value, 1)
	health_bar.max_value = max_hp
	health_bar.value = mini(current_hp, max_hp)

func take_damage(amount: int) -> void:
	set_hp(current_hp - amount)

func heal(amount: int) -> void:
	set_hp(current_hp + amount)

func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)
	update_health_bar()

func update_health_bar() -> void:
	health_bar.value = current_hp

# --- Armor ---

func set_max_armor(value: int) -> void:
	max_armor = maxi(value, 0)
	armor_bar.max_value = maxi(max_armor, 1)
	armor_bar.value = mini(current_armor, max_armor)
	armor_bar.visible = max_armor > 0

func set_armor(value: int) -> void:
	current_armor = clampi(value, 0, maxi(max_armor, 1))
	armor_bar.value = current_armor

# --- Shield ---

func set_max_shield(value: int) -> void:
	max_shield = maxi(value, 0)
	shield_bar.max_value = maxi(max_shield, 1)
	shield_bar.value = mini(current_shield, max_shield)
	shield_bar.visible = max_shield > 0

func set_shield(value: int) -> void:
	current_shield = clampi(value, 0, maxi(max_shield, 1))
	shield_bar.value = current_shield

# --- Wave & perks readout ---

func set_wave(current: int, total: int) -> void:
	wave_label.text = "Wave %d / %d" % [current, total]

func set_perks(text: String) -> void:
	perks_label.text = text

func set_multifire(unlocked: bool, time_left: float, _cooldown: float) -> void:
	if not unlocked:
		if multifire_label.text != "":
			multifire_label.text = ""
		return
	if time_left <= 0.0:
		multifire_label.text = "МУЛЬТИПЛАМЯ [Q]: ГОТОВО"
		multifire_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		multifire_label.text = "МУЛЬТИПЛАМЯ [Q]: %dс" % int(ceil(time_left))
		multifire_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

# --- Perk selection ---

func show_perk_choices(perks: Array) -> void:
	_offer = perks
	for i in perk_buttons.size():
		var button := perk_buttons[i]
		if i < perks.size():
			var id: int = perks[i]
			button.visible = true
			button.text = "%s\n%s" % [Perks.title(id), Perks.description(id)]
		else:
			button.visible = false
	perk_panel.visible = true

func _hide_perk_choices() -> void:
	perk_panel.visible = false
	_offer = []

func _on_perk_button(index: int) -> void:
	if index < 0 or index >= _offer.size():
		return
	var id: int = _offer[index]
	_hide_perk_choices()
	perk_chosen.emit(id)

# --- Messages ---

func show_message(text: String, color: Color = Color.WHITE) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.visible = true

func hide_message() -> void:
	message_label.visible = false

func show_restart() -> void:
	restart_button.visible = true
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()