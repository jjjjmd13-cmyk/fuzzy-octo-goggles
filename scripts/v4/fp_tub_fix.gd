extends RefCounted
## 꾸미기 목욕통 개발 보정표 (대표 요청 2026-11-11 ③): 받은 모형이 동물을 가리면 게임에서 고쳐 씀 (모형 파일은 그대로).
## 목욕통 id → {mesh: 고칠 메시 이름, lid_from: 이 높이 (모형 기준 m) 위를, lid_scale: 이 배로 낮춤}.
## - tub_shell: 뒤쪽 높은 조개 부채 (뚜껑, 꼭대기 1.5 m) 가 동물 등을 다 가림 → 앞 테두리 높이 (1.21 m) 위를 0.2 배로 (0.25 면 고양이 등 뒤 한 방향이 아직 가림).
##   부채 모양은 그대로 남고 (꼭대기 약 1.27 m, 다른 목욕통 테두리 1.27~1.29 m 와 같음) 둘레 어디서나 등이 보임.
## 그래픽을 다시 받으면 (뚜껑이 낮은 모형) 이 줄을 지우면 됨. 확인: tests/game/test_v4_tub_reach.gd (목욕통마다 둘레 12 방향).

const FIX := {
	"tub_shell": {"mesh": "Tub", "lid_from": 1.21, "lid_scale": 0.2},
}


## 꾸미기 목욕통 모형에 보정표를 적용 (없으면 그대로)
static func apply(model: Node3D, id: String) -> void:
	if not FIX.has(id) or model == null:
		return
	var fix: Dictionary = FIX[id]
	var view := model.find_child(fix.mesh, true, false) as MeshInstance3D
	if view == null or view.mesh == null:
		return
	view.mesh = squashed(view.mesh, fix.lid_from, fix.lid_scale)


## mesh 에서 from 높이 위 꼭짓점을 from 쪽으로 scale 배 낮춘 새 메시 (재질·면 그대로, 노멀은 다시 계산하지 않음)
static func squashed(mesh: Mesh, from: float, scale: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			if verts[i].y > from:
				verts[i].y = from + (verts[i].y - from) * scale
		arrays[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, mesh.surface_get_material(surface))
		out.surface_set_name(surface, mesh.surface_get_name(surface))
	return out
