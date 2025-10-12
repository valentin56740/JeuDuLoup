# Script de comportement pour un loup chasseur
# L'objectif du loup va être d'attraper les moutons 
extends RigidBody3D

# ===== PARAMÈTRES EXPORTÉS (modifiables dans l'éditeur) =====
@export var force = 45  # Force appliquée pour le déplacement du loup
@export var vitesse_max = 30  # Vitesse maximale du loup (empêche une accélération infinie)
@export var search_rotation_speed = 1  # Vitesse de rotation en mode recherche
@export var rotation_speed = 5.0  # Vitesse de rotation vers une cible
@export var distance_arret = 2.0  # Distance à laquelle le loup ralentit pour éviter de dépasser la cible
@export var coordination_active = true  # Active/désactive le système de réservation des moutons entre loups

# ===== VARIABLES D'INSTANCE =====
var cibles = []  # Liste des moutons dans la zone proche
var ciblesLoin = []  # Liste des moutons dans la zone lointaine
var cible_lointaine_actuelle = null  # Mouton lointain actuellement visé
var cible_actuelle = null  # Mouton proche actuellement poursuivi (réservé par ce loup)

# ===== RÉFÉRENCES AUX NŒUDS =====
@onready var animation_player = $WolfModel/AnimationPlayer  # Contrôleur d'animations du loup

# ===== SCÈNES PRÉCHARGÉES =====
@export var sang_scene : PackedScene = preload("res://sang.tscn")  # Scène de l'effet de sang
@export var loup_scene : PackedScene = preload("res://loup.tscn")  # Scène du loup (pour reproduction)

# ===== SYSTÈME DE COORDINATION ENTRE LOUPS =====
# Dictionnaire statique (partagé entre toutes les instances de loups)
# Clé : référence au mouton | Valeur : référence au loup qui le chasse
# Permet d'éviter que plusieurs loups ne poursuivent le même mouton
static var moutons_reserves = {}

# ===== INITIALISATION =====
func _ready():
	# Configure l'amortissement pour un mouvement plus réaliste
	linear_damp = 2.0  # Freine naturellement le mouvement linéaire (évite le dérapage)
	angular_damp = 5.0  # Réduit la rotation incontrôlée (stabilise l'orientation)
	
	# Ajoute ce loup au groupe "Loup" pour pouvoir le retrouver facilement
	# (utile pour les requêtes de groupe dans Godot)
	add_to_group("Loup")

# ===== NETTOYAGE À LA DESTRUCTION =====
func _exit_tree():
	# Quand le loup est supprimé de la scène, libère sa cible
	# pour qu'un autre loup puisse la poursuivre
	if cible_actuelle != null and is_instance_valid(cible_actuelle):
		_liberer_cible(cible_actuelle)

# ===== SYSTÈME DE RÉSERVATION DES CIBLES =====

# Tente de réserver un mouton pour ce loup
# Retourne true si la réservation réussit, false sinon
func _reserver_cible(mouton: Node) -> bool:
	# Si la coordination est désactivée, autoriser toujours (comportement simple)
	if not coordination_active:
		return true
	
	# Si le mouton n'est pas encore réservé ou si le loup réservant n'existe plus
	if not moutons_reserves.has(mouton) or not is_instance_valid(moutons_reserves[mouton]):
		moutons_reserves[mouton] = self  # Réserver pour ce loup
		return true
	
	# Vérifier si le loup qui a réservé existe encore
	var loup_reservant = moutons_reserves[mouton]
	if not is_instance_valid(loup_reservant):
		# Le loup réservant a disparu, on peut récupérer la cible
		moutons_reserves[mouton] = self
		return true
	
	# Le mouton est déjà réservé par un autre loup valide
	return false

# Libère la réservation d'un mouton
# Permet à d'autres loups de le poursuivre
func _liberer_cible(mouton: Node):
	# Vérifie que c'est bien ce loup qui a réservé le mouton avant de libérer
	if moutons_reserves.has(mouton) and moutons_reserves[mouton] == self:
		moutons_reserves.erase(mouton)

# Vérifie si un mouton est réservé par un autre loup
# Retourne true si un autre loup le poursuit déjà
func _est_reserve_par_autre(mouton: Node) -> bool:
	# Si coordination désactivée, aucun mouton n'est considéré comme réservé
	if not coordination_active:
		return false
	
	# Si le mouton n'est pas dans le dictionnaire, il n'est pas réservé
	if not moutons_reserves.has(mouton):
		return false
	
	# Récupère le loup qui a réservé ce mouton
	var loup_reservant = moutons_reserves[mouton]
	
	# Si le loup réservant n'existe plus, nettoyer la réservation
	if not is_instance_valid(loup_reservant):
		moutons_reserves.erase(mouton)
		return false
	
	# Retourne true si un autre loup (pas celui-ci) a réservé le mouton
	return loup_reservant != self

# ===== DÉTECTION DES MOUTONS (ZONE PROCHE) =====

# Appelé quand un corps entre dans la zone de détection proche
func _on_zone_proche_body_entered(body):
	if body.is_in_group("Mouton"):
		# Ajoute le mouton à la liste des cibles proches (si pas déjà présent)
		if not cibles.has(body):
			cibles.append(body)
		
		# Retire de la liste lointaine et annule la cible lointaine
		if ciblesLoin.has(body):
			ciblesLoin.erase(body)
		cible_lointaine_actuelle = null

# Appelé quand un corps sort de la zone de détection proche
func _on_zone_proche_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles.erase(body)  # Retire le mouton de la liste des cibles proches

# ===== DÉTECTION DES MOUTONS (ZONE LOINTAINE) =====

# Appelé quand un corps entre dans la zone de détection lointaine
func _on_champs_loin_body_entered(body):
	if body.is_in_group("Mouton"):
		# Ajoute uniquement si le mouton n'est ni proche ni déjà dans la liste lointaine
		if not cibles.has(body) and not ciblesLoin.has(body):
			ciblesLoin.append(body)

# Appelé quand un corps sort de la zone de détection lointaine
func _on_champs_loin_body_exited(body):
	if body.is_in_group("Mouton"):
		ciblesLoin.erase(body)  # Retire le mouton de la liste lointaine

# ===== SÉLECTION DE LA CIBLE =====

# Trouve le mouton le plus proche parmi les cibles disponibles
# Ignore les moutons déjà réservés par d'autres loups
# Retourne null si aucun mouton disponible
func _mouton_plus_proche():
	var mouton_plus_proche: Node = null
	var distance_min = INF  # Commence avec une distance infinie
	
	# Parcourt tous les moutons proches
	for mouton in cibles:
		if is_instance_valid(mouton):  # Vérifie que le mouton existe encore
			# Ignore les moutons déjà réservés par d'autres loups
			if _est_reserve_par_autre(mouton):
				continue
			
			# Calcule la distance entre le loup et le mouton
			var dist = global_position.distance_to(mouton.global_position)
			
			# Garde le mouton le plus proche
			if dist < distance_min:
				distance_min = dist
				mouton_plus_proche = mouton
	
	return mouton_plus_proche

# ===== ROTATION VERS LA CIBLE =====

# Fait tourner progressivement le loup vers la position de la cible
# Utilise une interpolation pour une rotation fluide
func _tourner_vers_cible(cible_position: Vector3, delta: float):
	# Calcule la direction vers la cible (ignore l'axe Y pour rester horizontal)
	var direction = cible_position - global_position
	direction.y = 0
	
	# Si la direction est significative (pas sur place)
	if direction.length() > 0.01:
		direction = direction.normalized()  # Normalise pour avoir un vecteur unitaire
		
		# Calcule l'angle cible en radians
		var angle_cible = atan2(direction.x, direction.z)
		var angle_actuel = rotation.y
		
		# Calcule la différence d'angle
		var angle_diff = angle_cible - angle_actuel
		
		# Normalise la différence d'angle entre -PI et PI
		# (pour toujours tourner dans la direction la plus courte)
		while angle_diff > PI:
			angle_diff -= 2 * PI
		while angle_diff < -PI:
			angle_diff += 2 * PI
		
		# Applique la rotation progressive (limitée par rotation_speed)
		rotation.y += sign(angle_diff) * min(abs(angle_diff), rotation_speed * delta)

# ===== LOGIQUE DE DÉPLACEMENT PRINCIPALE =====

# Gère le comportement de déplacement du loup selon les priorités :
# 1. Poursuivre un mouton proche
# 2. Se diriger vers un mouton lointain
# 3. Mode recherche (rotation sur place)
func _deplacement():
	var delta = get_physics_process_delta_time()
	
	# Lance l'animation de course
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")
	
	# ===== LIMITATION DE VITESSE =====
	# Empêche le loup d'accélérer indéfiniment
	var vitesse_horizontale = Vector3(linear_velocity.x, 0, linear_velocity.z)
	if vitesse_horizontale.length() > vitesse_max:
		# Plafonne la vitesse à vitesse_max
		var vitesse_limitee = vitesse_horizontale.normalized() * vitesse_max
		linear_velocity.x = vitesse_limitee.x
		linear_velocity.z = vitesse_limitee.z
	
	# ===== PRIORITÉ 1 : MOUTON PROCHE =====
	var cible = _mouton_plus_proche()
	if cible != null and is_instance_valid(cible):
		# Gestion du changement de cible
		if cible_actuelle != cible:
			# Libère l'ancienne cible si elle existe
			if cible_actuelle != null:
				_liberer_cible(cible_actuelle)
			
			# Tente de réserver la nouvelle cible
			if _reserver_cible(cible):
				cible_actuelle = cible
			else:
				# La cible est déjà prise, on cherche ailleurs
				cible_actuelle = null
				cible = null
		
		# Si on a une cible valide
		if cible != null:
			print("Cas 1 : mouton proche")
			cible_lointaine_actuelle = null  # Annule la cible lointaine
			
			# Calcule la distance à la cible
			var distance = global_position.distance_to(cible.global_position)
			
			# Tourne vers la cible
			_tourner_vers_cible(cible.global_position, delta)
			
			# Réduit la force quand on s'approche pour éviter de tourner autour
			# (multiplicateur entre 0 et 1 selon la distance)
			var multiplicateur_force = 1.0
			if distance < distance_arret:
				multiplicateur_force = distance / distance_arret
			
			# Applique la force pour se déplacer vers la cible
			var direction = (cible.global_position - global_position).normalized()
			apply_central_force(direction * force * multiplicateur_force)
			return
	else:
		# Plus de cible proche valide, libère la réservation
		if cible_actuelle != null:
			_liberer_cible(cible_actuelle)
			cible_actuelle = null
	
	# ===== PRIORITÉ 2 : MOUTON LOINTAIN =====
	# Vérifie si on a déjà une cible lointaine
	if cible_lointaine_actuelle != null and is_instance_valid(cible_lointaine_actuelle):
		# Vérifie qu'elle n'est pas réservée par un autre loup
		if not _est_reserve_par_autre(cible_lointaine_actuelle):
			_tourner_vers_cible(cible_lointaine_actuelle.global_position, delta)
			print("Cas 2 : mouton loin")
			
			# Applique la force pour se déplacer vers la cible lointaine
			var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
			apply_central_force(direction * force)
			return
		else:
			# La cible lointaine a été réservée entre-temps
			cible_lointaine_actuelle = null
	
	# Cherche une nouvelle cible lointaine si nécessaire
	if ciblesLoin.size() > 0:
		# Nettoie les références invalides dans la liste
		for i in range(ciblesLoin.size() - 1, -1, -1):
			if not is_instance_valid(ciblesLoin[i]):
				ciblesLoin.remove_at(i)
		
		# S'il reste des cibles lointaines valides
		if ciblesLoin.size() > 0:
			# Cherche le premier mouton lointain non réservé
			for mouton in ciblesLoin:
				if not _est_reserve_par_autre(mouton):
					cible_lointaine_actuelle = mouton
					_tourner_vers_cible(cible_lointaine_actuelle.global_position, delta)
					
					# Applique la force vers cette cible
					var direction = (cible_lointaine_actuelle.global_position - global_position).normalized()
					apply_central_force(direction * force)
					return
	
	# ===== PRIORITÉ 3 : MODE RECHERCHE =====
	# Aucune cible disponible, le loup tourne sur place pour chercher
	cible_lointaine_actuelle = null
	print("Recherche")
	
	# Rotation continue pour balayer la zone
	rotation.y += search_rotation_speed * delta
	
	# Passe à l'animation idle (au repos)
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Idle")

# ===== GESTION DES COLLISIONS =====

# Appelé quand le loup entre en collision avec un autre corps
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Mouton"):
		# Le loup a attrapé un mouton !
		
		# Libère la réservation du mouton
		if moutons_reserves.has(body):
			moutons_reserves.erase(body)
		
		# Réinitialise la cible actuelle
		if cible_actuelle == body:
			cible_actuelle = null
		
		# Crée un nouveau loup à la position du mouton mangé (reproduction)
		var sang_instance = loup_scene.instantiate()
		sang_instance.global_position = body.global_position
		get_parent().add_child(sang_instance)
		
		# Supprime le mouton de la scène
		body.queue_free()

# ===== BOUCLE PHYSIQUE =====

# Appelé à chaque frame de physique (généralement 60 fois par seconde)
func _physics_process(delta):
	_deplacement()  # Exécute la logique de déplacement
