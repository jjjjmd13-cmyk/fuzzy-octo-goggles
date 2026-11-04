extends SceneTree
# Fresh-project GLTFDocument loading; no cached imports or game dependencies.
var records: Array[Dictionary] = []
var failed := false
func _initialize() -> void:
 call_deferred("run")
func require_ok(ok: bool, text: String) -> void:
 if not ok:
  failed = true
  push_error(text)
func run() -> void:
 var dir: String = get_script().resource_path.get_base_dir().get_base_dir()
 for f in DirAccess.get_files_at(dir):
  if not f.ends_with(".glb"):
   continue
  var doc := GLTFDocument.new()
  var state := GLTFState.new()
  var err := doc.append_from_file(dir.path_join(f), state)
  require_ok(err == OK, f + " parse")
  var scene := doc.generate_scene(state)
  require_ok(scene != null, f + " scene")
  if scene == null:
   continue
  root.add_child(scene)
  var meshes := scene.find_children("*", "MeshInstance3D", true, false)
  var surfaces := 0
  for node in meshes:
   require_ok(node.mesh != null, f + " mesh")
   surfaces += node.mesh.get_surface_count()
   for s in node.mesh.get_surface_count():
    var m: Material = node.get_active_material(s)
    require_ok(m is StandardMaterial3D, f + " material")
    if m is StandardMaterial3D:
     require_ok(m.albedo_texture != null, f + " embedded colour texture")
  if f.begins_with("tub_"):
   for n in ["Stand", "Tub", "Plug"]:
    require_ok(scene.find_child(n, true, false) != null, f + " " + n)
  if f.begins_with("lamp_"):
   require_ok(scene.find_child("Bulb", true, false) != null, f + " Bulb")
  if f == "art_clock.glb":
   for n in ["Hand_H", "Hand_M"]:
    var hand: Node3D = scene.find_child(n, true, false)
    require_ok(hand != null, n)
    if hand != null:
     var before := hand.position
     require_ok(absf(before.x) < .0001 and absf(before.y) < .0001, n + " centre pivot")
     hand.rotate_z(.8)
     require_ok(hand.position.is_equal_approx(before), n + " fixed pivot during local Z rotation")
  records.append({"file": f, "meshes": meshes.size(), "surfaces": surfaces, "status": "PASS"})
  scene.free()
 require_ok(records.size() == 24, "24 GLBs")
 var output := FileAccess.open(dir.path_join("validation_godot.json"), FileAccess.WRITE)
 output.store_string(JSON.stringify({"godot": Engine.get_version_info().string, "method": "GLTFDocument fresh project, meshes/materials/textures/parts/Z-axis joints", "status": "FAIL" if failed else "PASS", "assets": records}, "  ") + "\n")
 print("DECOR GODOT: ", records.size(), " GLBs ", "FAIL" if failed else "PASS")
 quit(1 if failed else 0)
