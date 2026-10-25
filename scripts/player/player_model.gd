extends Node3D
## 임시 플레이어 모형 (캡슐 + 앞쪽 표시용 상자).
##
## 그래픽 교체 약속: 진짜 모델 씬도 이 스크립트(또는 같은 함수를 가진 스크립트)를
## 루트에 붙이고, 발바닥이 원점·앞이 -Z 를 보게 둔다. 키 약 1.8m.

## 이 색을 입힐 메시들. 비어 있으면 색을 바꾸지 않는다.
@export var tint_meshes: Array[MeshInstance3D] = []


func set_player_color(color: Color) -> void:
	for mesh in tint_meshes:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		mesh.material_override = material
