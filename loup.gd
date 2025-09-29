extends RigidBody3D

@export var force = 10 

var sx:float = 100
var sz:float = 100 

func _process(delta:float) -> void:
	var fz = randf()-0.5 
	apply_central_force( Vector3(force,0,fz))
	
	if position.x > sx/2:
		position.x =-sx/2

	if position.x < -sx/2:
		position.x = sx/2

	if position.z > sz/2:
		position.z=-sz/2

	if position.z < -sz/2:
		position.z = sz/2
