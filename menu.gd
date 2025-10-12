extends Node

@onready var coordination_checkbox = $CanvasLayer/VBoxContainer/CoordinationCheckBox
@onready var reproduction_checkbox = $CanvasLayer/VBoxContainer/ReproductionCheckBox
@onready var start_button = $CanvasLayer/VBoxContainer/StartButton

func _ready():
	# Pause le jeu pendant que le menu est visible
	get_tree().paused = true
	
	# Connecte le bouton Start
	start_button.pressed.connect(_on_start_pressed)
	
	# Connecte les signaux des CheckBox pour afficher les changements
	coordination_checkbox.toggled.connect(_on_coordination_toggled)
	reproduction_checkbox.toggled.connect(_on_reproduction_toggled)
	
	# Initialise l'état des CheckBox depuis GlobalSettings (optionnel)
	coordination_checkbox.button_pressed = GlobalSettings.coordination_active
	reproduction_checkbox.button_pressed = GlobalSettings.reproduction_active
	
	# Affiche l'état initial
	print("Menu prêt. Coordination:", coordination_checkbox.button_pressed, "Reproduction:", reproduction_checkbox.button_pressed)

func _on_coordination_toggled(is_pressed: bool):
	print("Coordination checkbox changée:", is_pressed)

func _on_reproduction_toggled(is_pressed: bool):
	print("Reproduction checkbox changée:", is_pressed)

func _on_start_pressed():
	# Récupère l'état des CheckBox avec button_pressed
	GlobalSettings.coordination_active = coordination_checkbox.button_pressed
	GlobalSettings.reproduction_active = reproduction_checkbox.button_pressed
	
	print("Start pressé !")
	print("Coordination active:", GlobalSettings.coordination_active)
	print("Reproduction active:", GlobalSettings.reproduction_active)
	
	# Relance le jeu
	get_tree().paused = false
	
	# Cache le menu
	$CanvasLayer.visible = false
