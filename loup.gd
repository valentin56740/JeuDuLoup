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
		en_vue = true

func _on_HitBoxChase2_body_exited(body):
	if body.is_in_group("Mouton"):
		cibles_zone2.erase(body)
		if cibles_zone1.size() == 0 and cibles_zone2.size() == 0:
			en_vue = false

func chase(target: Node):
	var direction = (target.global_position - global_position).normalized()
	linear_velocity = direction * vitesse

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

	# Combine toutes les cibles des deux zones
	var toutes_cibles = cibles_zone1 + cibles_zone2

	if toutes_cibles.size() > 0:
		var closest_sheep = null
		var closest_distance = chase_radius
		for sheep in toutes_cibles:
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
