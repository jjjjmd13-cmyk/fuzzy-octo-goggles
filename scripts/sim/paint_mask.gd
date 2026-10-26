extends RefCounted
## 동물 몸 칠하기 마스크 (GDD_V3 3.1 "더러움 마스크 붓질").
##
## 모형의 UV 를 쓰지 않고, 몸 중심에서 본 방향(구 모양 투영, 위경도)을 마스크 좌표로 쓴다.
## 그래서 ChatGPT 모형의 UV 가 어떻든 동작하고, 셰이더도 같은 계산으로 마스크를 읽는다.
## 채널마다 0~255 값을 갖고, 칠한 비율은 칠하는 순간 같이 갱신한다 (전체를 다시 세지 않음).
## 비율은 구 표면 넓이로 가중한다 (극 근처 픽셀은 작으므로 sin(위도) 를 곱함).
##
## 채널: wet(적시기) scrub(문지르기 = 진흙 지움) rinse(헹구기) towel(수건) dry(드라이어)
## 셰이더용 텍스처(RGBA8): R=wet, G=scrub, B=rinse, A=dry
##
## 배 밑(목욕대에 닿는 쪽, 방향 y < UNDERSIDE_Y)은 작업대 시점에서 손이 닿지 않으므로
## 비율 계산에서 뺀다 (칠할 수는 있음). 안 빼면 90% 를 채울 수 없다.

const CHANNELS := ["wet", "scrub", "rinse", "towel", "dry"]
const TEXTURE_CHANNEL := {"wet": 0, "scrub": 1, "rinse": 2, "dry": 3}
const UNDERSIDE_Y := -0.6

var size: int
var texture: ImageTexture
var mud_texture: ImageTexture

var _dirs := PackedVector3Array()
var _weights := PackedFloat32Array()
var _total_weight := 0.0
var _values := {}  # 채널 → PackedByteArray
var _sums := {}  # 채널 → 칠한 가중 합
var _mud := PackedByteArray()
var _rgba := PackedByteArray()
var _image: Image
var _dirty := false


func _init(resolution: int = 256) -> void:
	size = resolution
	_dirs.resize(size * size)
	_weights.resize(size * size)
	for y in size:
		var theta := PI * (y + 0.5) / size
		var sin_t := sin(theta)
		for x in size:
			var phi := TAU * (x + 0.5) / size - PI
			var i := y * size + x
			_dirs[i] = Vector3(sin_t * sin(phi), cos(theta), sin_t * cos(phi))
			_weights[i] = sin_t if cos(theta) >= UNDERSIDE_Y else 0.0
			_total_weight += _weights[i]
	for channel in CHANNELS:
		var values := PackedByteArray()
		values.resize(size * size)
		_values[channel] = values
		_sums[channel] = 0.0
	_rgba.resize(size * size * 4)
	_image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, _rgba)
	texture = ImageTexture.create_from_image(_image)
	set_mud_pattern(PackedByteArray())


## 방향 → 마스크 좌표 (0~1). 셰이더(sim_fur.gdshader)도 같은 식을 쓴다.
static func dir_to_uv(dir: Vector3) -> Vector2:
	var d := dir.normalized()
	return Vector2((atan2(d.x, d.z) + PI) / TAU, acos(clampf(d.y, -1.0, 1.0)) / PI)


## 칠하기. dir = 몸 중심에서 칠할 곳 방향, angle = 붓 반경(라디안), amount = 0~1 (한 번에 더할 양).
## 붓 가장자리는 부드럽게 줄어든다. 새로 칠해진 비율(0~1)을 돌려준다.
func paint(channel: String, dir: Vector3, angle: float, amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var values: PackedByteArray = _values[channel]
	var d := dir.normalized()
	var uv := dir_to_uv(d)
	var cos_limit := cos(angle)
	var cy := uv.y * size
	var row_span := ceili(angle / PI * size) + 1
	var y0 := maxi(int(cy) - row_span, 0)
	var y1 := mini(int(cy) + row_span, size - 1)
	var added := 0.0
	var tex_channel: int = TEXTURE_CHANNEL.get(channel, -1)
	for y in range(y0, y1 + 1):
		var sin_t := sin(PI * (y + 0.5) / size)
		var x_span := size / 2 if sin_t < 0.05 else mini(ceili(angle / (TAU * sin_t) * size) + 1, size / 2)
		var cx := int(uv.x * size)
		for dx in range(-x_span, x_span + 1):
			var x := posmod(cx + dx, size)
			var i := y * size + x
			var dot := _dirs[i].dot(d)
			if dot < cos_limit:
				continue
			# 가운데 1, 가장자리 0 으로 부드럽게
			var falloff := clampf((dot - cos_limit) / maxf(1.0 - cos_limit, 0.0001) * 2.0, 0.0, 1.0)
			var old := values[i]
			var new := mini(old + ceili(amount * falloff * 255.0), 255)
			if new == old:
				continue
			values[i] = new
			var delta := _weights[i] * (new - old) / 255.0
			added += delta
			if tex_channel >= 0:
				_rgba[i * 4 + tex_channel] = new
	_sums[channel] += added
	if added > 0.0:
		_dirty = true
	return added / _total_weight


## 채널의 칠한 비율 (0~1, 넓이 가중).
func ratio(channel: String) -> float:
	return _sums[channel] / _total_weight


## 이 방향 근처가 아직 덜 칠해졌는가 (반짝임·시험용).
func value_at(channel: String, dir: Vector3) -> float:
	var uv := dir_to_uv(dir)
	var x := clampi(int(uv.x * size), 0, size - 1)
	var y := clampi(int(uv.y * size), 0, size - 1)
	return _values[channel][y * size + x] / 255.0


## 채널을 통째로 채운다 (다른 사람 화면에서 진행 비율만 받을 때, 테스트).
func fill(channel: String, value: float) -> void:
	var values: PackedByteArray = _values[channel]
	var byte := clampi(int(value * 255.0), 0, 255)
	values.fill(byte)
	_sums[channel] = _total_weight * byte / 255.0
	var tex_channel: int = TEXTURE_CHANNEL.get(channel, -1)
	if tex_channel >= 0:
		for i in size * size:
			_rgba[i * 4 + tex_channel] = byte
	_dirty = true


## 칠한 것이 있으면 텍스처에 올린다 (프레임마다 한 번 부르면 됨).
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	_image.set_data(size, size, false, Image.FORMAT_RGBA8, _rgba)
	texture.update(_image)


## 텍스처에 올라가는 이미지 (시험용: 헤드리스에서는 texture.get_image() 가 비어 있음).
func get_image() -> Image:
	return _image


## 더러움 무늬 (0~255, size×size). 비어 있으면 깨끗한 몸.
func set_mud_pattern(pattern: PackedByteArray) -> void:
	var bytes := pattern
	if bytes.size() != size * size:
		bytes = PackedByteArray()
		bytes.resize(size * size)
	_mud = bytes
	mud_texture = ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_L8, bytes))


## 이 방향의 진흙 양 (0~1, 문질러 지운 만큼 뺌).
func mud_at(dir: Vector3) -> float:
	var uv := dir_to_uv(dir)
	var i := clampi(int(uv.y * size), 0, size - 1) * size + clampi(int(uv.x * size), 0, size - 1)
	return _mud[i] / 255.0 * (1.0 - _values["scrub"][i] / 255.0)


## 더러움 무늬 만들기. kind: 0 = 발(아래쪽), 1 = 등 큰 얼룩, 2 = 온몸 점박이. rng 로 위치가 달라진다.
func make_mud_pattern(kind: int, rng: RandomNumberGenerator) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size * size)
	var blobs: Array = []
	match kind:
		0:
			blobs = [[Vector3.DOWN, 1.15]]
		1:
			var back := Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.5, 0.5)).normalized()
			blobs = [[back, 0.9]]
		_:
			for n in 9:
				var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
				blobs.append([p, rng.randf_range(0.25, 0.45)])
	for i in size * size:
		var best := 0.0
		for blob in blobs:
			var dot: float = _dirs[i].dot(blob[0])
			var c := cos(blob[1])
			if dot > c:
				best = maxf(best, clampf((dot - c) / maxf(1.0 - c, 0.0001) * 3.0, 0.0, 1.0))
		bytes[i] = int(best * 255.0)
	return bytes
