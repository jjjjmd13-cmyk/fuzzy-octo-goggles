extends CharacterBody3D
## V4 1인칭 시제품: 걷기(WASD) + 마우스 시점. 카메라 가운데 점으로 조준한다.
## 마우스는 잡혀 있고(보이지 않음), Esc 를 누르면 시제품 씬이 메뉴로 돌아간다.

const SPEED := 3.2
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.55

@onready var camera: Camera3D = $Camera

var _pitch := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.35, 1.35)
		camera.rotation.x = _pitch


func _physics_process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var move := (transform.basis * Vector3(input.x, 0, input.y)).normalized() * SPEED
	velocity.x = move.x
	velocity.z = move.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()


## 화면 가운데에서 앞으로 나가는 광선
func aim_ray(length: float) -> Array[Vector3]:
	var from := camera.global_position
	return [from, from - camera.global_basis.z * length]
