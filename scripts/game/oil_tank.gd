extends Node
## 팀 공용 기름 (GDD 5.2~5.3). 값은 호스트만 바꾸고 Sync 로 모든 피어에 보낸다.
## 기름 0 → 심지 시간(light_wick_duration) → 완전한 어둠.

var oil := 100.0
var wick_left := 60.0


func has_oil() -> bool:
	return oil > 0.0


func is_low() -> bool:
	return oil <= Tuning.data.light_low_oil_threshold


func in_wick() -> bool:
	return oil <= 0.0 and wick_left > 0.0


## 심지까지 꺼진 완전한 어둠.
func is_dark() -> bool:
	return oil <= 0.0 and wick_left <= 0.0


## 호스트 전용. 기름을 쓰고(음수면 채우고) 0 ~ 최대치로 자른다.
func consume(amount: float) -> void:
	oil = clampf(oil - amount, 0.0, Tuning.data.oil_max)


func add(amount: float) -> void:
	consume(-amount)
	if oil > 0.0:
		wick_left = Tuning.data.light_wick_duration


func reset(start_oil: float) -> void:
	oil = clampf(start_oil, 0.0, Tuning.data.oil_max)
	wick_left = Tuning.data.light_wick_duration
