extends "res://tests/qa_test.gd"
## 밸런스 리소스가 TUNING.md 시제품(✅) 값과 같은지, 인원별 표가 4칸인지 확인.


func run_test() -> void:
	var data: Resource = load("res://data/balance/balance.tres")
	check(data != null, "balance.tres 를 읽음")
	if data == null:
		return
	check_eq(Tuning.data.resource_path, data.resource_path, "Tuning 이 같은 파일을 씀")
	var expected := {
		"light_lantern_radius_low": 5.0, "light_lantern_radius_normal": 8.0, "light_lantern_radius_high": 12.0,
		"light_lantern_drain_low": 2.0, "light_lantern_drain_normal": 4.0, "light_lantern_drain_high": 8.0,
		"light_lantern_default_level": 1, "light_handlamp_radius": 3.0, "light_handlamp_drain": 0.5,
		"light_wick_radius": 2.0, "light_wick_duration": 60.0, "light_low_oil_threshold": 20.0,
		"oil_max": 100.0, "oil_start": 100.0, "oil_bottle_amount": 15.0, "oil_revive_cost": 5.0, "oil_tick_interval": 0.5,
		"dark_max": 100.0, "dark_gain_unlit": 4.0, "dark_gain_handlamp_only": 1.0, "dark_decay_lit": 10.0,
		"dark_no_oil_gain_mult": 2.0, "dark_stalk_threshold": 30.0, "dark_stalk_release_threshold": 30.0, "dark_full_hunt": 100.0,
		"player_walk_speed": 4.0, "player_run_speed": 6.0, "player_stamina": 5.0,
		"player_stamina_regen_delay": 3.0, "player_stamina_regen_rate": 1.0,
		"down_duration": 30.0, "down_crawl_speed": 1.0, "down_revive_time": 3.0,
		"stalker_think_hz": 10, "stalker_sync_hz": 20, "stalker_idle_time_min": 3.0, "stalker_idle_time_max": 8.0,
		"stalker_wander_speed": 2.5, "stalker_stalk_speed": 3.5, "stalker_flee_speed": 5.0, "stalker_detect_range": 20.0,
		"stalker_attack_range": 1.5, "stalker_attack_windup": 0.8, "stalker_light_flee_time": 0.5,
		"stalker_flee_duration": 4.0, "stalker_lose_interest_time": 5.0, "stalker_no_oil_speed_mult": 1.5,
		"stalker_ignores_handlamp": true,
	}
	for key in expected:
		check_eq(data.get(key), expected[key], key)
	check_eq(Array(data.party_oil_start), [90.0, 100.0, 100.0, 100.0], "party_oil_start")
	check_eq(Array(data.party_oil_drain_mult), [0.7, 1.0, 1.0, 1.0].map(func(v: float) -> float: return float(PackedFloat32Array([v])[0])), "party_oil_drain_mult")
	check_eq(data.party_value(data.party_oil_start, 2), 100.0, "2인 시작 기름")
	check_eq(data.party_value(data.party_oil_start, 9), 100.0, "4인 넘으면 4인 값")
