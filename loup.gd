extends RigidBody3D
@export var force = 25
@export var vitesse = 10
@export var search_rotation_speed = 1  # Vitesse de rotation en recherche
@export var sx: int = 100
@export var sz: int = 100
var cibles = []
var ciblesLoin = []
var cible_lointaine_actuelle = null  # Garde la cible lointaine en mémoire


#Un mouton rentre dans la zone proche du mouton 
func _on_zone_proche_body_entered(body):
	if body.is_in_group("Mouton"):
		# Priorité à la zone proche
		if not cibles.has(body):
			cibles.append(body)
		# Retirer de la zone lointaine
		if ciblesLoin.has(body):
			ciblesLoin.erase(body)
		# Annuler la poursuite lointaine si un mouton entre en zone proche
		cible_lointaine_actuelle = null

func _on_zone_proche_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles.erase(body)

func _on_champs_loin_body_entered(body):
	if body.is_in_group("Mouton"):
		# Ajouter seulement si pas déjà en zone proche
		if not cibles.has(body) and not ciblesLoin.has(body):
			ciblesLoin.append(body)

func _on_champs_loin_body_exited(body):
	if body.is_in_group("Mouton"):
		ciblesLoin.erase(body)
		# On continue de poursuivre même si le mouton sort de la zone lointaine 
		#le seul moyen d'arreter est si un mouton est plus proche 

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

func _deplacement():
	var delta = get_physics_process_delta_time()
	
	# Gestion des bords de la zone (wrap)
	if position.x > sx / 2:
		position.x = -sx / 2
	elif position.x < -sx / 2:
		position.x = sx / 2
	if position.z > sz / 2:
		position.z = -sz / 2
	elif position.z < -sz / 2:
		position.z = sz / 2
	
	# Priorité 1 : Mouton en zone proche - CHASE LE PLUS PROCHE
	var cible = _mouton_plus_proche()
	if cible != null and is_instance_valid(cible):
		cible_lointaine_actuelle = null  # Annuler toute poursuite lointaine
		var direction = (cible.global_position - global_position).normalized()
		apply_central_force(direction * force)
		return
	
	# Priorité 2 : Mouton en zone lointaine
	# Si on a déjà une cible lointaine et qu'elle est encore valide, continuer de la poursuivre
	if cible_lointaine_actuelle != null and is_instance_valid(cible_lointaine_actuelle):
		var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
		apply_central_force(direction * force)
		return
	
	# Sinon, chercher une nouvelle cible lointaine
	if ciblesLoin.size() > 0:
		# Nettoyer les cibles invalides
		for i in range(ciblesLoin.size() - 1, -1, -1):
			if not is_instance_valid(ciblesLoin[i]):
				ciblesLoin.remove_at(i)
		
		if ciblesLoin.size() > 0:
			# Prendre le mouton le plus proche de la zone lointaine
			cible_lointaine_actuelle = ciblesLoin[0]
			var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
			apply_central_force(direction * force)
			return
	
	# Priorité 3 : Mode recherche - Tourner lentement
	cible_lointaine_actuelle = null
	rotation.y += search_rotation_speed * delta

func _physics_process(delta):
	_deplacement()
