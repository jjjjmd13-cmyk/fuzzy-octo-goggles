extends RefCounted
## 2D 그림 교체 지점 (GDD_V3 8.1-2 완료 조건 6). 사람 대표가 ChatGPT 로 만든 PNG 를
## assets/ui/<이름>.png 로 넣으면 그 그림을 쓰고, 없으면 지금의 임시 도형을 그린다.
## 이름 목록과 크기는 assets/ui/README.md.

const FOLDER := "res://assets/ui/"

static var _cache := {}


## 그림이 있으면 Texture2D, 없으면 null.
static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := FOLDER + name + ".png"
	var result: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = result
	return result
