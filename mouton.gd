extends RigidBody3D

@export var speed: float = 20
@export var direction_change_interval: float = 2.0 # toutes les 2 sec environ
@export var scene_loup: PackedScene  # Référence à la scène du loup

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

var sx: float = 100
var sz: float = 100 

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _process(delta: float) -> void:
	# décrémente le timer
	timer -= delta

	if timer <= 0.0:
		# choisit une nouvelle direction aléatoire
		var angle = randf() * TAU  # angle aléatoire [0..2π] 
		move_dir = Vector3(cos(angle), 0, sin(angle)).normalized() # Vecteur directionnel du mouton 
		timer = direction_change_interval

	# applique une force dans la direction choisie
	apply_central_force(move_dir * speed)

	# Gestion des bords de la zone
	if position.x > sx / 2:
		position.x = -sx / 2
	elif position.x < -sx / 2:
		position.x = sx / 2

	if position.z > sz / 2:
		position.z = -sz / 2
	elif position.z < -sz / 2:
		position.z = sz / 2

func _on_body_entered(body):
	print("Touché")
	if body.is_in_group("Loup"):
		transformer_en_loup()

func transformer_en_loup():
	if scene_loup:
		var loup = scene_loup.instantiate()
		loup.global_position = global_position
		get_parent().add_child(loup)
		# Ajoute le loup au groupe "Loup" (au cas où ce n’est pas fait dans la scène loup)
		if not loup.is_in_group("Loup"):
			loup.add_to_group("Loup")
		queue_free()  # Supprime le mouton
