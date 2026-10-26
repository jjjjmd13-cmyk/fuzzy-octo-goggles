extends Node3D
## 임시 강아지 모형. 그래픽 교체 약속: 바닥이 원점, 앞이 -Z, 높이 약 0.7 m,
## 루트에 set_guest_state(이름) — "muddy"(진흙) / "foam"(거품) / "wet"(젖음) / "dry"(뽀송).
## 임시 모형은 GDD_V2 4.2 대로 색 + 크기로 구분: 갈색 → 흰 거품 구 → 진한 파랑 → 흰색 1.6배.

const COLORS := {
	"muddy": Color(0.45, 0.3, 0.15),
	"foam": Color(0.95, 0.95, 1.0),
	"wet": Color(0.1, 0.2, 0.55),
	"dry": Color(1.0, 1.0, 1.0),
}

@export var tint_meshes: Array[MeshInstance3D] = []
@export var foam: Node3D

var _material := StandardMaterial3D.new()


func _ready() -> void:
	for mesh in tint_meshes:
		mesh.material_override = _material


func set_guest_state(state_name: String) -> void:
	_material.albedo_color = COLORS.get(state_name, Color.MAGENTA)
	if foam != null:
		foam.visible = state_name == "foam"
	scale = Vector3.ONE * (1.6 if state_name == "dry" else 1.0)
