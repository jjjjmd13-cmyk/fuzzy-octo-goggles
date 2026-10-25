extends RefCounted
## 시드 기반 결정론적 난수. 같은 시드면 모든 피어(Windows/Linux 모두)가 같은 결과를 낸다.
##
## 호스트가 세션 시드 하나를 정해 클라이언트에 보내고, 각 시스템은 자기 이름의
## "흐름(stream)"으로 RNG 를 따로 만든다. 그래야 한 시스템이 난수를 더 뽑아도
## 다른 시스템(예: 던전 생성)의 결과가 바뀌지 않는다.
##
##   const SeededRng := preload("res://scripts/core/seeded_rng.gd")
##   var rng := SeededRng.make(session_seed, "dungeon")
##   var room_count := rng.randi_range(5, 9)
##
## 주의: 결정론이 필요한 곳에서는 전역 randi()/randf() 를 쓰지 말 것 (피어마다 다름).


## 새 세션 시드 (호스트만 부른다).
static func new_session_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return (rng.randi() << 31) ^ rng.randi()


## base_seed 와 흐름 이름으로 RNG 를 만든다.
static func make(base_seed: int, stream: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(base_seed, stream)
	return rng


## 흐름 이름을 섞은 시드. 엔진 hash() 대신 직접 계산해 엔진 버전이 바뀌어도 값이 같다.
static func derive_seed(base_seed: int, stream: String) -> int:
	var h := 2166136261  # FNV-1a 32비트
	for b in stream.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	h &= 0x7FFFFFFF
	return base_seed ^ (h << 32) ^ h
