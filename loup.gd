extends RigidBody3D

@export var force = 25  # Force appliquée pour déplacer le loup
@export var vitesse = 10  # Vitesse de déplacement du loup
@export var sx: int = 100  # Taille de la zone sur l'axe X
@export var sz: int = 100  # Taille de la zone sur l'axe Z
@export var chase_radius = 20.0  # Rayon de détection pour la chasse

var cibles = []  # Liste des moutons détectés

# Fonction appelée quand un mouton entre dans la zone de détection
func _on_HitBoxChase_body_entered(body):
	# Vérifie si le corps détecté est dans le groupe "Mouton"
	if body.is_in_group("Mouton"):
		cibles.append(body)  # Ajoute le mouton à la liste des cibles

# Fonction appelée quand un mouton sort de la zone de détection
func _on_HitBoxChase_body_exited(body):
	# Vérifie si le corps sortant est un mouton
	if body.is_in_group("Mouton"):
		cibles.erase(body)  # Retire le mouton de la liste des cibles

# Fonction pour chasser le mouton le plus proche
func chase(target: Node):
	# Calculer la direction vers le mouton le plus proche
	var direction = (target.global_position - global_position).normalized()
	linear_velocity = direction * vitesse  # Applique la vitesse pour se diriger vers le mouton

# Fonction principale pour traiter la logique à chaque frame
func _process(delta: float) -> void:
	# Correction de la position pour que le loup ne sorte pas de la zone
	if position.x > sx / 2:
		position.x = sx / 2
	if position.x < -sx / 2:
		position.x = -sx / 2

	if position.z > sz / 2:
		position.z = sz / 2
	if position.z < -sz / 2:
		position.z = -sz / 2

	# Si le loup a des cibles à poursuivre, on le fait
	if cibles.size() > 0:
		# Trouver le mouton le plus proche
		var closest_sheep = null
		var closest_distance = chase_radius

		for sheep in cibles:
			var distance = global_position.distance_to(sheep.global_position)
			if distance <= chase_radius and distance < closest_distance:
				closest_sheep = sheep
				closest_distance = distance

		# Si un mouton est dans le rayon de chasse, on le poursuit
		if closest_sheep:
			chase(closest_sheep)
