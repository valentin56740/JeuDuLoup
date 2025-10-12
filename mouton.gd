extends RigidBody3D

# --- CONFIGURATION EXPORTS --------------------------------------------------
# Vitesses configurables pour les différents états.
@export var wander_speed: float = 17.0    # vitesse quand le mouton erre (WANDER)
@export var flee_speed: float = 22.0      # vitesse quand il fuit (FLEE)
@export var safe_speed: float = 13.0      # vitesse en mode d'évitement prudent (SAFE)

# Fréquence de changement de direction en mode errance (secondes)
@export var direction_change_interval: float = 2.0

# Références aux scènes (préchargées pour instancier si besoin)
@export var sang_scene : PackedScene = preload("res://sang.tscn")
@export var loup_scene : PackedScene = preload("res://loup.tscn")

# --- ÉTAT INTERNE ----------------------------------------------------------
# Gestion du broutage (grazing)
var grazing: bool = false
var grazing_timer: float = 0.0
var next_graze_time: float = 0.0

# Références utilitaires aux nœuds enfants (animations, modèle 3D, ...)
@onready var animation_player = $Sheep_Model/AnimationPlayer
@onready var sheep_model = $Sheep_Model

# Listes (remplacent des références uniques) — permettent la gestion multi-loups
# dangerous_wolves : loups dans la zone SAFE (proches mais pas immédiats)
# close_wolves     : loups dans la zone DANGER (immédiatement menaçants)
var dangerous_wolves: Array[RigidBody3D] = []
var close_wolves: Array[RigidBody3D] = []

# Modes du comportement du mouton
enum Mode { WANDER, SAFE, FLEE }
var mode = Mode.WANDER  # état initial : errance

# Direction courante souhaitée (unit vector) et timer pour changements aléatoires
var move_dir: Vector3 = Vector3.ZERO
var timer: float = 0.0

# --- INITIALISATION --------------------------------------------------------
func _ready() -> void:
	# Initialise le prochain moment de broutage aléatoire pour varier le comportement.
	_set_next_graze_time()

func _set_next_graze_time() -> void:
	# Temps aléatoire avant que le mouton commence à brouter (évite la synchronisation entre individus).
	next_graze_time = randf_range(5.0, 15.0)

# --- BOUCLE PHYSIQUE -------------------------------------------------------
func _physics_process(delta: float) -> void:
	# Logique de transition d'états en priorité (FLEE > SAFE > WANDER)
	match mode:
		Mode.FLEE:
			# Si des loups sont en danger immédiat -> fuite
			if close_wolves.size() > 0:
				flee_from_wolves(delta)
			else:
				# Plus de menace immédiate mais il reste des loups proches (SAFE) ?
				if dangerous_wolves.size() > 0:
					mode = Mode.SAFE
				else:
					mode = Mode.WANDER

		Mode.SAFE:
			# Si un loup entre en DANGER, passer en FLEE
			if close_wolves.size() > 0:
				mode = Mode.FLEE
			# Si toujours des loups dans SAFE, éviter prudemment
			elif dangerous_wolves.size() > 0:
				safe_avoid_wolves(delta)
			else:
				mode = Mode.WANDER

		Mode.WANDER:
			# Détecte les loups ; bascule d'état si nécessaire
			if close_wolves.size() > 0:
				mode = Mode.FLEE
			elif dangerous_wolves.size() > 0:
				mode = Mode.SAFE
			else:
				wander(delta)

	# Rotation fluide du modèle vers la direction de déplacement pour l'animation
	if linear_velocity.length() > 0.1:
		var dir = linear_velocity.normalized()
		# atan2 prend (x, z) pour obtenir l'angle autour de Y (yaw)
		var target_yaw = atan2(dir.x, dir.z)
		# lerp_angle gère la continuité angulaire (ex. passage -pi -> +pi)
		sheep_model.rotation.y = lerp_angle(sheep_model.rotation.y, target_yaw, delta * 5.0)

# -------------------------------
# DÉTECTION DES LOUPS (SIGNALS)
# -------------------------------
# Ces méthodes sont prévues pour être connectées aux Area3D (ex : area_safe, area_danger)
# Elles stockent/retirent les références aux RigidBody3D des loups et mettent à jour l'état.

func _on_area_safe_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		# Ajout unique
		if not dangerous_wolves.has(w):
			dangerous_wolves.append(w)
		# Si on errait, devenir prudent
		if mode == Mode.WANDER:
			mode = Mode.SAFE

func _on_area_safe_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		dangerous_wolves.erase(w)

func _on_area_danger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		if not close_wolves.has(w):
			close_wolves.append(w)
		# Menace immédiate -> fuite
		mode = Mode.FLEE

func _on_area_danger_body_exited(body: Node3D) -> void:
	if body.is_in_group("Loup") and body is RigidBody3D:
		var w := body as RigidBody3D
		close_wolves.erase(w)
		# Si plus de loups en danger, re-évaluer selon la zone SAFE
		if close_wolves.is_empty():
			mode = Mode.SAFE if dangerous_wolves.size() > 0 else Mode.WANDER

# -------------------------------
# COMPORTEMENTS DÉTAILLÉS
# -------------------------------

func wander(delta: float) -> void:
	# Comportement d'errance avec broutage aléatoire :
	# - Le mouton marche aléatoirement
	# - De temps en temps, il s'arrête pour brouter (idle eating)
	# - Les changements de direction sont espacés par direction_change_interval
	if grazing:
		# Compte à rebours du broutage
		grazing_timer -= delta
		if grazing_timer <= 0.0:
			grazing = false
			_set_next_graze_time()
		else:
			# Pendant le broutage, reste immobile et en animation d'alimentation
			return

	# Décompte avant le prochain broutage
	next_graze_time -= delta
	if next_graze_time <= 0.0:
		_start_grazing()
		return

	# Animation de marche (chemin d'animation dépend du modèle importé)
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")

	# Changement aléatoire de direction à intervalles
	timer -= delta
	if timer <= 0.0:
		var angle = randf() * TAU
		move_dir = Vector3(cos(angle), 0, sin(angle)).normalized()
		timer = direction_change_interval

	# Applique une force centrale vers la direction de mouvement desired
	apply_central_force(move_dir * wander_speed)


func _start_grazing() -> void:
	# Démarre l'état "broutage" (immobilise le mouton pendant une durée aléatoire)
	grazing = true
	grazing_timer = randf_range(2.0, 5.0)
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Idle_Eating")


# Helper: calcule une direction de répulsion agrégée à partir d'une liste de loups.
# Principes :
# - Chaque loup contribue par un vecteur allant du loup vers le mouton.
# - Contribution pondérée par 1/d^2 pour donner plus d'importance aux plus proches.
# - Si toutes les contributions s'annulent (loups symétriques), fallback vers le loup le plus proche.
# - La fonction retourne un vecteur unit (normalized).
func _compute_repulsion_dir(wolves: Array[RigidBody3D]) -> Vector3:
	var dir := Vector3.ZERO
	var closest: RigidBody3D = null
	var closest_d2 := INF
	var d2 = 0.0

	for w in wolves:
		# Skip si l'instance n'existe plus (sécurité si loup détruit)
		if not is_instance_valid(w):
			continue
		var delta := global_position - w.global_position
		# Protection contre division par 0 : clamp la distance^2 minimale
		d2 = max(delta.length_squared(), 0.0001)
		# Ajoute la contribution pondérée (équivalent direction * (1/d^2))
		dir += delta / d2
		if d2 < closest_d2:
			closest_d2 = d2
			closest = w

	# Si la somme est quasi nulle (ex : loups opposés), on fuit directement du plus proche.
	if dir.length_squared() < 1e-6 and closest != null:
		return (global_position - closest.global_position).normalized()

	# Normalise pour obtenir une direction unitaire
	return dir.normalized()


func safe_avoid_wolves(delta: float) -> void:
	# Mode prudent : s'éloigne des loups détectés dans la zone SAFE sans paniquer.
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Walk")

	if dangerous_wolves.is_empty():
		mode = Mode.WANDER
		return
	else:
		# Direction de base : répulsion combinée des loups
		var base_dir := _compute_repulsion_dir(dangerous_wolves)

		# On ajoute une petite variation aléatoire d'angle pour éviter un comportement trop "robotique"
		var random_angle = randf_range(-0.5, 0.5)
		var rot = Basis(Vector3.UP, random_angle)
		var final_dir = (rot * base_dir).normalized()

		apply_central_force(final_dir * safe_speed)


func flee_from_wolves(delta: float) -> void:
	# Mode fuite : priorité à la mise à distance rapide des loups en DANGER
	animation_player.play("AnimalArmature|AnimalArmature|AnimalArmature|Run")

	# Si plus de loups immédiats, on bascule selon la présence éventuelle de loups SAFE
	if close_wolves.is_empty():
		mode = Mode.SAFE if dangerous_wolves.size() > 0 else Mode.WANDER
		return

	# Direction de fuite basée sur la répulsion des loups très proches
	var flee_dir := _compute_repulsion_dir(close_wolves)

	# Mélange direction actuelle et direction de fuite pour un mouvement plus fluide
	var v := linear_velocity
	if v.length() > 0.1:
		var blended := (flee_dir * 0.7 + v.normalized() * 0.3).normalized()
		flee_dir = blended

	apply_central_force(flee_dir * flee_speed)
