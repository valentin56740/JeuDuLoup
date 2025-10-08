extends RigidBody3D

@export var force = 25
@export var vitesse = 10
@export var sx: int = 100
@export var sz: int = 100
@export var chase_radius = 20.0
@export var en_vue = false

@export var hitbox_chase1: Area3D
@export var hitbox_chase2: Area3D

var cibles_zone1 = []
var cibles_zone2 = []
var cible_lockee = null # ← Cible actuelle poursuivie si lock

func _ready():
	hitbox_chase1.body_entered.connect(_on_HitBoxChase1_body_entered)
	hitbox_chase1.body_exited.connect(_on_HitBoxChase1_body_exited)
	hitbox_chase2.body_entered.connect(_on_HitBoxChase2_body_entered)
	hitbox_chase2.body_exited.connect(_on_HitBoxChase2_body_exited)

# Zone 1
func _on_HitBoxChase1_body_entered(body):
	if body.is_in_group("Mouton"):
		if not cibles_zone1.has(body):
			cibles_zone1.append(body)
		# Si le mouton locké entre dans zone 1, on le délocke
		if body == cible_lockee:
			cible_lockee = null
		en_vue = true

func _on_HitBoxChase1_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles_zone1.erase(body)
		if cibles_zone1.size() == 0 and cibles_zone2.size() == 0:
			en_vue = false

# Zone 2
func _on_HitBoxChase2_body_entered(body):
	if body.is_in_group("Mouton"):
		if not cibles_zone2.has(body):
			cibles_zone2.append(body)
		# Ne plus lock la cible dans la zone 2 (comportement comme zone 1)
		en_vue = true

func _on_HitBoxChase2_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles_zone2.erase(body)
		# Ne plus délocker ici, uniquement dans zone 1
		if cibles_zone1.size() == 0 and cibles_zone2.size() == 0:
			en_vue = false

# Fonction de chasse
func chase(target: Node):
	var direction = (target.global_position - global_position).normalized()
	linear_velocity = direction * vitesse

# Fonction principale par frame
func _process(delta: float) -> void:
	# Empêche de sortir de la zone
	if position.x > sx / 2:
		position.x = sx / 2
	if position.x < -sx / 2:
		position.x = -sx / 2
	if position.z > sz / 2:
		position.z = sz / 2
	if position.z < -sz / 2:
		position.z = -sz / 2

	# Si une cible est lockée, on la poursuit jusqu'à ce qu'elle entre dans zone 1 ou sorte du chase_radius
	if cible_lockee != null and is_instance_valid(cible_lockee):
		var distance = global_position.distance_to(cible_lockee.global_position)
		if distance <= chase_radius:
			chase(cible_lockee)
		else:
			# Délock la cible si trop loin
			cible_lockee = null
			linear_velocity = Vector3.ZERO
			return # Ne pas chercher d'autres cibles

	# Sinon, comportement normal avec recherche de cible
	var cibles_a_poursuivre = []
	if cibles_zone1.size() > 0:
		cibles_a_poursuivre = cibles_zone1
	elif cibles_zone2.size() > 0:
		cibles_a_poursuivre = cibles_zone2

	if cibles_a_poursuivre.size() > 0:
		var closest_sheep = null
		var closest_distance = chase_radius
		for sheep in cibles_a_poursuivre:
			if not is_instance_valid(sheep):
				continue
			var distance = global_position.distance_to(sheep.global_position)
			if distance < closest_distance:
				closest_sheep = sheep
				closest_distance = distance
		if closest_sheep != null:
			chase(closest_sheep)
		else:
			linear_velocity = Vector3.ZERO
	else:
		linear_velocity = Vector3.ZERO
