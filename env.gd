extends Node3D


@export var spawn_area : CollisionShape3D

@export var cameras : Array[Camera3D] = [] 
var index = 0 
var mouton = preload("res://mouton.tscn")

func _ready() -> void:
	update_camera()
	spawn_moutons()

func update_camera():
	for i in range(cameras.size()):
		cameras[i].current = (i == index)



func spawn_moutons():
	var shape = spawn_area.shape as BoxShape3D
	var extents = shape.size / 2.0

	for i in range(10):
		var pos = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
		
		var m = mouton.instantiate()
		add_child(m)  # Ajoute-le avant de changer la position (sinon global/local mélange)
		m.global_position = spawn_area.global_position + pos
		
		m.add_to_group("Mouton") 

		print("Mouton ajouté :", m.name, " | Groupe Mouton :", m.is_in_group("Mouton"))



func _on_button_pressed() -> void:
	index = (index + 1) % cameras.size()
	update_camera()
