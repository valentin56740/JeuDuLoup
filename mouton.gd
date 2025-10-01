extends RigidBody3D

@export var speed: float = 20
@export var direction_change_interval: float = 2.0 # toutes les 2 sec environ
@export var scene_loup: PackedScene  # Référence à la scène du loup
@export var flee_radius: float = 10.0  # rayon de détection pour fuite

var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

var sx: float = 100
var sz: float = 100

var loup_proche: Node = null

func _ready():
	# Connecte les signaux de la zone de détection si tu utilises une Area3D
	# Sinon tu peux gérer la détection dans _process en cherchant les loups proches
	pass

func _process(delta: float) -> void:
	# Recherche du loup le plus proche dans le rayon flee_radius
	var loups = get_tree().get_nodes_in_group("Loup")
	var loup_detecte: Node = null
	var distance_min = flee_radius

	for loup in loups:
		var dist = global_position.distance_to(loup.global_position)
		if dist < distance_min:
			distance_min = dist
			loup_detecte = loup

	# Si un loup est détecté proche => fuite
	if loup_detecte:
		var dir_fuite = (global_position - loup_detecte.global_position).normalized()
		move_dir = dir_fuite
		timer = direction_change_interval  # reset timer pour ne pas override la fuite
	else:
		# décrémente le timer
		timer -= delta

		if timer <= 0.0:
			# choisit une nouvelle direction aléatoire
			var angle = randf() * TAU  # angle aléatoire [0..2π] 
			move_dir = Vector3(cos(angle), 0, sin(angle)).normalized() # Vecteur directionnel du mouton 
			timer = direction_change_interval

	# applique une force dans la direction choisie
	apply_central_force(move_dir * speed)

	# Gestion des bords de la zone (wrap)
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
		if not loup.is_in_group("Loup"):
			loup.add_to_group("Loup")
		queue_free()
