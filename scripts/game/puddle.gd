extends Node3D
## 물웅덩이 (TUNING_V2 2.2). 호스트가 만들고 지운다 (PuddleSpawner 가 복제).
## 밟은 플레이어는 자기 쪽에서 미끄러진다 (이동 권한이 본인에게 있으므로). 마지막 2초는 옅어진다.

const FADE_TIME := 2.0

var _age := 0.0
var _material: StandardMaterial3D

@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("puddles")
	var radius: float = Tuning.data.puddle_radius
	mesh.scale = Vector3(radius, 1.0, radius)
	_material = (mesh.get_surface_override_material(0) as StandardMaterial3D).duplicate()
	mesh.set_surface_override_material(0, _material)


func radius() -> float:
	return Tuning.data.puddle_radius


func _process(delta: float) -> void:
	_age += delta
	var left: float = Tuning.data.puddle_lifetime - _age
	_material.albedo_color.a = 0.55 * clampf(left / FADE_TIME, 0.0, 1.0)
	if Net.is_host() and left <= 0.0:
		queue_free()
