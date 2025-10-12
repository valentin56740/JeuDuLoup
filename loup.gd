# Script de comportement pour un loup chasseur
# L'objectif du loup va être d'attraper les moutons 
extends RigidBody3D

# ===== PARAMÈTRES EXPORTÉS (modifiables dans l'éditeur) =====
# ===== PARAMÈTRES EXPORTÉS (modifiables dans l'éditeur) =====
@export var force = 45
@export var vitesse_max = 30
@export var search_rotation_speed = 1
@export var rotation_speed = 5.0
@export var distance_arret = 2.0

# ===== VARIABLES D'INSTANCE =====
var cibles = []
var ciblesLoin = []
var cible_lointaine_actuelle = null
var cible_actuelle = null

# ===== RÉFÉRENCES AUX NŒUDS =====
@onready var animation_player = $WolfModel/AnimationPlayer

# ===== SCÈNES PRÉCHARGÉES =====
@export var sang_scene : PackedScene = preload("res://sang.tscn")
@export var loup_scene : PackedScene = preload("res://loup.tscn")

# ===== SYSTÈME DE COORDINATION ENTRE LOUPS =====
static var moutons_reserves = {}

# ===== INITIALISATION =====
func _ready():
	linear_damp = 2.0
	angular_damp = 5.0
	add_to_group("Loup")

# ===== NETTOYAGE À LA DESTRUCTION =====
func _exit_tree():
	if cible_actuelle != null and is_instance_valid(cible_actuelle):
		_liberer_cible(cible_actuelle)

# ===== SYSTÈME DE RÉSERVATION DES CIBLES =====

func _reserver_cible(mouton: Node) -> bool:
	# Lit directement depuis GlobalSettings à chaque appel
	if not GlobalSettings.coordination_active:
		return true
	
	if not moutons_reserves.has(mouton) or not is_instance_valid(moutons_reserves[mouton]):
		moutons_reserves[mouton] = self
		return true
	
	var loup_reservant = moutons_reserves[mouton]
	if not is_instance_valid(loup_reservant):
		moutons_reserves[mouton] = self
		return true
	
	return false

func _liberer_cible(mouton: Node):
	if moutons_reserves.has(mouton) and moutons_reserves[mouton] == self:
		moutons_reserves.erase(mouton)

func _est_reserve_par_autre(mouton: Node) -> bool:
	# Lit directement depuis GlobalSettings à chaque appel
	if not GlobalSettings.coordination_active:
		return false
	
	if not moutons_reserves.has(mouton):
		return false
	
	var loup_reservant = moutons_reserves[mouton]
	
	if not is_instance_valid(loup_reservant):
		moutons_reserves.erase(mouton)
		return false
	
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
		# Libère la réservation
		if moutons_reserves.has(body):
			moutons_reserves.erase(body)
		
		if cible_actuelle == body:
			cible_actuelle = null
		
		# Lit directement depuis GlobalSettings au moment de la collision
		if GlobalSettings.reproduction_active:
			# Mode reproduction : crée un nouveau loup
			var nouveau_loup = loup_scene.instantiate()
			nouveau_loup.global_position = body.global_position
			get_parent().add_child(nouveau_loup)
			print("🐺 Reproduction : un nouveau loup est né !")
		else:
			# Mode sang : affiche une flaque de sang
			var sang_instance = sang_scene.instantiate()
			sang_instance.global_position = body.global_position
			get_parent().add_child(sang_instance)
			print(" Sang : le mouton a été mangé.")
		
		# Supprime le mouton
		body.queue_free()


# ===== BOUCLE PHYSIQUE =====

# Appelé à chaque frame de physique (généralement 60 fois par seconde)
func _physics_process(delta):
	_deplacement()  # Exécute la logique de déplacement
