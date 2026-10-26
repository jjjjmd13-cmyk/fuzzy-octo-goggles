extends "res://tests/qa_test.gd"
## 수치 리소스가 TUNING_V2.md 시제품(✅) 값과 같은지 (GDD_V2 4.2 완료 조건 9).


func run_test() -> void:
	var data: Resource = load("res://data/balance/bath_balance.tres")
	if not check(data != null, "bath_balance.tres 를 읽음"):
		return
	check_eq(Tuning.data.resource_path, data.resource_path, "Tuning 이 같은 파일을 씀")
	var expected := {
		"player_walk_speed": 4.5, "player_carry_speed": 4.0, "player_dash_distance": 2.5, "player_dash_cooldown": 0.8,
		"player_interact_range": 1.2, "player_push_strength": 1.0,
		"guest_hearts": 3, "guest_heart_time": 20.0, "guest_heart_blink_last": true, "guest_patience_pause_in_machine": true,
		"guest_angry_leave_time": 1.5, "guest_seats": 3, "guest_queue_max": 3, "guest_walk_speed": 2.0,
		"escape_shake_time": 0.5, "escape_shake_splash_radius": 1.5, "escape_speed": 3.5, "escape_turn_interval": 2.0,
		"escape_avoid_player_range": 2.0, "escape_puddle_interval": 0.6,
		"puddle_radius": 0.6, "puddle_lifetime": 12.0, "puddle_max": 20, "puddle_slide_distance": 2.5,
		"puddle_slide_time": 0.6, "puddle_affects_guests": false,
		"machine_bath_time": 4.0, "machine_dryer_time": 3.0, "machine_done_wait_heart_mult": 1.0,
		"machine_auto_eject_solo": false,
		"shop_duration": 180.0, "result_star3_requires_no_angry": true, "result_show_time": 0.0, "intro_text_time": 3.0,
	}
	for key in expected:
		check_eq(data.get(key), expected[key], key)
	var tables := {
		"party_guest_interval": [30, 20, 15, 12], "party_first_guest_delay": [3, 3, 3, 3],
		"party_star1_guests": [3, 5, 6, 8], "party_star2_guests": [5, 7, 9, 12], "party_star3_guests": [6, 9, 12, 15],
	}
	for key in tables:
		check_eq(Array(data.get(key)), tables[key].map(func(v: int) -> float: return float(v)), key)
