extends RigidBody3D
@export var force = 45
@export var vitesse_max = 30  # Vitesse maximale
@export var search_rotation_speed = 1
@export var rotation_speed = 5.0
@export var sx: int = 100
@export var sz: int = 100
@export var distance_arret = 2.0  # Distance à laquelle le loup ralentit

var cibles = []
var ciblesLoin = []
var cible_lointaine_actuelle = null
@onready var animation_player = $WolfModel/AnimationPlayer
@export var sang_scene : PackedScene = preload("res://sang.tscn")
@export var loup_scene : PackedScene = preload("res://loup.tscn")

func _ready():
	# Augmenter le damping pour réduire le dérapage
	linear_damp = 2.0  # Freine naturellement le mouvement
	angular_damp = 5.0  # Réduit la rotation incontrôlée

func _on_zone_proche_body_entered(body):
	if body.is_in_group("Mouton"):
		if not cibles.has(body):
			cibles.append(body)
		if ciblesLoin.has(body):
			ciblesLoin.erase(body)
		cible_lointaine_actuelle = null

func _on_zone_proche_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles.erase(body)

func _on_champs_loin_body_entered(body):
	if body.is_in_group("Mouton"):
		if not cibles.has(body) and not ciblesLoin.has(body):
			ciblesLoin.append(body)

func _on_champs_loin_body_exited(body):
	if body.is_in_group("Mouton"):
		ciblesLoin.erase(body)

func _mouton_plus_proche():
	var mouton_plus_proche: Node = null
	var distance_min = INF
	
	for mouton in cibles:
		if is_instance_valid(mouton):
			var dist = global_position.distance_to(mouton.global_position)
			if dist < distance_min:
				distance_min = dist
				mouton_plus_proche = mouton
	
	return mouton_plus_proche

func _tourner_vers_cible(cible_position: Vector3, delta: float):
	var direction = cible_position - global_position
	direction.y = 0
	
	if direction.length() > 0.01:
		direction = direction.normalized()
		var angle_cible = atan2(direction.x, direction.z)
		var angle_actuel = rotation.y
		var angle_diff = angle_cible - angle_actuel
		
		while angle_diff > PI:
			angle_diff -= 2 * PI
		while angle_diff < -PI:
			angle_diff += 2 * PI
		
		rotation.y += sign(angle_diff) * min(abs(angle_diff), rotation_speed * delta)

func _deplacement():
	var delta = get_physics_process_delta_time()
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")
	
	# Wrap aux bords
	if position.x > sx / 2:
		position.x = -sx / 2
	elif position.x < -sx / 2:
		position.x = sx / 2
	if position.z > sz / 2:
		position.z = -sz / 2
	elif position.z < -sz / 2:
		position.z = sz / 2
	
	# Limiter la vitesse horizontale
	var vitesse_horizontale = Vector3(linear_velocity.x, 0, linear_velocity.z)
	if vitesse_horizontale.length() > vitesse_max:
		var vitesse_limitee = vitesse_horizontale.normalized() * vitesse_max
		linear_velocity.x = vitesse_limitee.x
		linear_velocity.z = vitesse_limitee.z
	
	# Priorité 1 : Mouton proche
	var cible = _mouton_plus_proche()
	if cible != null and is_instance_valid(cible):
		cible_lointaine_actuelle = null
		var distance = global_position.distance_to(cible.global_position)
		_tourner_vers_cible(cible.global_position, delta)
		
		# Réduire la force quand on est proche pour éviter de tourner autour
		var multiplicateur_force = 1.0
		if distance < distance_arret:
			multiplicateur_force = distance / distance_arret
		
		var direction = (cible.global_position - global_position).normalized()
		apply_central_force(direction * force * multiplicateur_force)
		return
	
	# Priorité 2 : Mouton lointain
	if cible_lointaine_actuelle != null and is_instance_valid(cible_lointaine_actuelle):
		_tourner_vers_cible(cible_lointaine_actuelle.global_position, delta)
		var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
		apply_central_force(direction * force)
		return
	
	if ciblesLoin.size() > 0:
		for i in range(ciblesLoin.size() - 1, -1, -1):
			if not is_instance_valid(ciblesLoin[i]):
				ciblesLoin.remove_at(i)
		
		if ciblesLoin.size() > 0:
			cible_lointaine_actuelle = ciblesLoin[0]
			_tourner_vers_cible(cible_lointaine_actuelle.global_position, delta)
			var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
			apply_central_force(direction * force)
			return
	
	# Mode recherche
	cible_lointaine_actuelle = null
	rotation.y += search_rotation_speed * delta
	
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Mouton"):
		var sang_instance = sang_scene.instantiate()
		sang_instance.global_position = body.global_position
		get_parent().add_child(sang_instance)
		body.queue_free()

func _physics_process(delta):
	_deplacement()
