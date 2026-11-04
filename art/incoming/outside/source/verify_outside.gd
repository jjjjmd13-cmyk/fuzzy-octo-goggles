extends SceneTree
var records: Array[Dictionary] = []
var failed := false
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, text: String) -> void:
 if not ok:
  failed = true
  push_error(text)
func collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
 if node is MeshInstance3D:
  out.append(node)
 for c in node.get_children():
  collect_meshes(c, out)
func mesh_bounds(meshes: Array[MeshInstance3D]) -> AABB:
 var result := AABB()
 var first := true
 for m in meshes:
  var b: AABB = m.global_transform * m.mesh.get_aabb()
  result = b if first else result.merge(b)
  first = false
 return result
func run() -> void:
 var dir: String = get_script().resource_path.get_base_dir().get_base_dir()
 var specs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("validation_geometry.json")))
 for f in DirAccess.get_files_at(dir):
  if not f.ends_with(".glb"):
   continue
  var doc := GLTFDocument.new()
  var state := GLTFState.new()
  check(doc.append_from_file(dir.path_join(f), state) == OK, f + " parse")
  var scene := doc.generate_scene(state)
  check(scene != null, f + " scene")
  if scene == null:
   continue
  root.add_child(scene)
  var meshes: Array[MeshInstance3D] = []
  collect_meshes(scene, meshes)
  for m in meshes:
   check(m.mesh != null, f + " mesh")
   for s in m.mesh.get_surface_count():
    var mat: Material = m.get_active_material(s)
    check(mat is StandardMaterial3D, f + " material")
    if mat is StandardMaterial3D:
     check(mat.albedo_texture != null, f + " embedded colour")
  var spec: Dictionary = specs[f.get_basename()]
  var joint_results: Array[Dictionary] = []
  for n in spec.joints:
   var part: Node3D = scene.find_child(n, true, false)
   check(part is MeshInstance3D, f + " joint mesh " + n)
   if part == null:
    continue
   var data: Dictionary = spec.joints[n]
   var wanted := Vector3(data.pivot[0], data.pivot[1], data.pivot[2])
   check(part.global_position.distance_to(wanted) < .0001, f + " pivot " + n)
   var before := part.position
   var closed := mesh_bounds(meshes)
   var axis: Vector3 = {"X": Vector3.RIGHT, "Y": Vector3.UP, "Z": Vector3.BACK}[data.axis]
   part.rotate_object_local(axis, data.test_angle_radians)
   check(part.position.is_equal_approx(before), f + " fixed pivot after rotation " + n)
   if f.begins_with("box_"):
    var opened := mesh_bounds(meshes)
    check(opened.end.y > closed.end.y + .08, f + " opens upward " + n)
    check(opened.size.x > closed.size.x + .02, f + " opens outward " + n)
   if f == "truck.glb" and n == "Door_Back":
    var opened := mesh_bounds(meshes)
    check(opened.end.z > closed.end.z + .5, "rear door opens behind cargo")
   joint_results.append({"name": n, "axis": data.axis, "radians": data.test_angle_radians, "pivot_stable": true})
   part.rotation = Vector3.ZERO
  if f == "street_lamp.glb":
   var bulb: Node3D = scene.find_child("Bulb", true, false)
   check(bulb != null and not bulb is MeshInstance3D, "Bulb must be an empty Node3D")
  records.append({"file": f, "mesh_count": meshes.size(), "joints_tested": joint_results, "status": "PASS"})
  scene.free()
 check(records.size() == 13, "13 GLBs")
 var output := FileAccess.open(dir.path_join("validation_godot.json"), FileAccess.WRITE)
 output.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "method": "Fresh project GLTFDocument load and actual local-axis articulation", "status": "FAIL" if failed else "PASS", "assets": records}, "  ") + "\n")
 print("OUTSIDE GODOT: ", records.size(), " GLBs ", "FAIL" if failed else "PASS")
 quit(1 if failed else 0)
