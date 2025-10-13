extends Node3D


@export var spawn_area : CollisionShape3D
@export var cameras : Array[Camera3D] = [] 
@export var loups = 3
@export var moutons = 60 

@onready var all_moutons: Array[RigidBody3D] = []

var index = 0 
var mouton = preload("res://mouton.tscn")
var loup = preload("res://loup.tscn")

func _ready() -> void:
	update_camera()
	spawn()

func update_camera():
	for i in range(cameras.size()):
		cameras[i].current = (i == index)




func spawn():
	var shape = spawn_area.shape as BoxShape3D
	var extents = shape.size / 2.0

	for i in range(moutons):
		var pos = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
		
		var m = mouton.instantiate()
		all_moutons.append(m)
		add_child(m)  # Ajoute-le avant de changer la position (sinon global/local mélange)
		m.global_position = spawn_area.global_position + pos
		
		m.add_to_group("Mouton") 

	for i in range(loups):
		var pos = Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
		
		var l = loup.instantiate()
		add_child(l)  # Ajoute-le avant de changer la position (sinon global/local mélange)
		l.global_position = spawn_area.global_position + pos
		
		l.add_to_group("Loup") 



func _on_button_pressed() -> void:
	index = (index + 1) % cameras.size()
	update_camera()
