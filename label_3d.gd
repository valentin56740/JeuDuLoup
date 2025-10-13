extends Label3D


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	
	# Oriente le label pour qu’il regarde la caméra
	look_at(camera.global_position, Vector3.UP)
	
	# Optionnel : pour éviter qu’il soit à l’envers
	rotate_y(deg_to_rad(180))
