extends Node3D
## 임시 추적자 모형. 그래픽 교체 약속: 발바닥 원점, 앞 -Z, 키 약 2 m,
## set_state(이름) 을 받아 연출한다 ("idle", "wander", "stalk", "attack", "flee").
## 공격 준비("attack")일 때 눈이 밝게 빛나야 한다 (GDD 7.1 반응할 틈).

@export var eyes: Array[MeshInstance3D] = []
@export var warning_light: OmniLight3D

var _eye_material := StandardMaterial3D.new()


func _ready() -> void:
	_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for eye in eyes:
		eye.material_override = _eye_material
	set_state("idle")


func set_state(state_name: String) -> void:
	var attacking := state_name == "attack"
	_eye_material.albedo_color = Color(1.0, 0.15, 0.1) if attacking else Color(0.55, 0.5, 0.35)
	if warning_light != null:
		warning_light.visible = attacking
