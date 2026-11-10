extends RefCounted
class_name RaceEngine

var track: Dictionary
var race_drivers: Array = []
var active_quali_drivers: Array = []
var eliminated_drivers: Array = []
var full_grid: Array = []

var current_lap: int = 0
var total_laps: int = 58
var is_race_running: bool = false
var is_race_finished: bool = false
var race_elapsed_time: float = 0.0

# --- EVOLUÇÃO DA PISTA (EMBORRACHAMENTO) ---
var track_grip: float = 0.0 
var quali_total_elapsed_time: float = 0.0 
var track_condition_time_accumulator: float = 0.0
const WATER_GAIN_PER_LAP: float = 3.0
const WATER_DRYING_PER_LAP: float = 7.0
const GRIP_LOSS_PER_WET_LAP: float = 5.0
const GRIP_GAIN_PER_DRY_LAP: float = 2.0

# --- SISTEMA DE CLIMA DINÂMICO E GRADUAL ---
var is_wet_race: bool = false
var weather_state: String = "☀️ Ensolarado"
var water_level: float = 0.0     # <--- Representa a umidade/água na pista (0 a 100%)
var rain_intensity: float = 0.0  
var weather_forecast: String = "☀️ Tempo Estável"
var forecast_laps_left: int = 0
var pending_weather_change: String = "NONE"

var quali_phase: String = "Q1"
var quali_time_elapsed: float = 0.0
var quali_durations: Dictionary = {"Q1": 1080.0, "Q2": 900.0, "Q3": 720.0}
var quali_checker_flag: bool = false

var safety_car_status: String = "NONE"
var safety_car_laps_left: int = 0
var incident_sector: int = 0 
var red_flag_active: bool = false
var pending_red_flag_modal: bool = false

var session_best_sectors: Dictionary = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
var session_fastest_lap: Dictionary = {"driver": "", "time": 999.0}

var race_logs: Array = []
var pit_logs: Array = []
var manager_tire_rule_warning_logged: bool = false

func is_quali_done() -> bool:
	return quali_phase == "FINISHED"

func is_finished() -> bool:
	return is_race_finished

func format_time_f1(time_sec: float) -> String:
	if time_sec >= 900.0:
		return "--:--.---"
	var mins = int(time_sec / 60.0)
	var secs = int(time_sec) % 60
	var msecs = int((time_sec - int(time_sec)) * 1000.0)
	return "%d:%02d.%03d" % [mins, secs, msecs]

func format_session_clock(time_sec: float) -> String:
	var mins = int(time_sec / 60.0)
	var secs = int(time_sec) % 60
	return "%02d:%02d" % [mins, secs]

func _get_base_track_lap_time() -> float:
	var km = float(track.get("ComprimentoKM", 5.278))
	var kmh = float(track.get("VelocidadeMediaKMH", 220.0))
	if kmh <= 0.0:
		kmh = 220.0
	return (km / kmh) * 3600.0

func get_water_lap_time_multiplier() -> float:
	return lerpf(1.0, 1.30, clampf(water_level, 0.0, 100.0) / 100.0)

func get_grip_lap_time_multiplier() -> float:
	return lerpf(1.02, 0.98, clampf(track_grip, 0.0, 100.0) / 100.0)

func get_track_condition_lap_time_multiplier() -> float:
	return get_water_lap_time_multiplier() * get_grip_lap_time_multiplier()

func _is_manager_controlled_team(team_name: String) -> bool:
	if str(Database.game_mode) != "manager":
		return false
	var manager_team := str(Database.user_team.get("nome", Database.user_team.get("Nome", "")))
	if manager_team.is_empty():
		manager_team = str(Database.selected_manager_team.get("Nome", Database.selected_manager_team.get("nome", "")))
	if manager_team.is_empty():
		manager_team = "Ferrari"
	return team_name.strip_edges().to_lower() == manager_team.strip_edges().to_lower()

func _calculate_lap_sectors(total_lap_time: float) -> Dictionary:
	var s1 = total_lap_time * 0.30 + randf_range(-0.04, 0.04)
	var s2 = total_lap_time * 0.40 + randf_range(-0.04, 0.04)
	var s3 = total_lap_time - (s1 + s2)
	return {"s1": s1, "s2": s2, "s3": s3}

func setup_race(selected_track: Dictionary) -> void:
	track = selected_track
	Database.race_finished = false
	total_laps = track.get("Voltas", 58)
	current_lap = 0
	is_race_running = false
	is_race_finished = false
	race_elapsed_time = 0.0
	quali_phase = "Q1"
	quali_time_elapsed = 0.0
	quali_total_elapsed_time = 0.0
	track_condition_time_accumulator = 0.0
	track_grip = 0.0
	quali_checker_flag = false
	safety_car_status = "NONE"
	safety_car_laps_left = 0
	incident_sector = 0
	red_flag_active = false
	pending_red_flag_modal = false
	
	# TRAVA DE SEGURANÇA: Garante 22 pilotos ativos no Database antes de montar a sessão
	if Database.has_method("ensure_full_grid"):
		Database.ensure_full_grid()
	
	session_best_sectors = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
	session_fastest_lap = {"driver": "", "time": 999.0}
	
	race_logs.clear()
	pit_logs.clear()
	
	is_wet_race = randf() < track.get("ChanceChuva", 0.20)
	if is_wet_race:
		rain_intensity = randf_range(1.0, 2.0)
		water_level = randf_range(15.0, 35.0)
		weather_state = "🌧️ Chuva Leve"
		weather_forecast = "🌧️ Chuva Contínua"
		race_logs.append("🌧️ CLIMA: Início de sessão sob chuva leve (" + str(snapped(water_level, 1.0)) + "% de água na pista).")
	else:
		rain_intensity = 0.0
		water_level = 0.0
		weather_state = "☀️ Ensolarado"
		weather_forecast = "☀️ Tempo Limpo"
		race_logs.append("☀️ CLIMA: Pista seca e tempo limpo para a largada.")

	race_drivers.clear()
	active_quali_drivers.clear()
	eliminated_drivers.clear()
	full_grid.clear()
	
	for d in Database.drivers:
		var eq_name = str(d.get("Equipe", "")).strip_edges()
		if eq_name != "Free Agent" and eq_name != "Aposentado" and not eq_name.is_empty():
			var entry = d.duplicate()
			entry["TempoTotal"] = 0.0
			entry["Status"] = "Na Pista"
			entry["QualiStatus"] = "Na Pista"
			entry["BestQualiTime"] = 999.0
			entry["LastLapTime"] = 999.0
			entry["retired_lap"] = 999
			entry["is_in_pit"] = false
			
			entry["quali_state"] = "Box"
			entry["timer_state"] = randf_range(10.0, 40.0)
			entry["quali_retry_allowed"] = true
			entry["force_in_lap"] = true
			entry["quali_lap_duration"] = _get_base_track_lap_time() * 1.08
			entry["pending_lap_time"] = 0.0
			entry["estilo"] = str(entry.get("estilo", "Normal"))
			entry["manager_controlled"] = _is_manager_controlled_team(eq_name)
			entry["pit_requested"] = false
			
			entry["last_sectors"] = {"s1": 0.0, "s2": 0.0, "s3": 0.0}
			entry["best_personal_sectors"] = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
			entry["sector_colors"] = {"s1": "⬜", "s2": "⬜", "s3": "⬜"}
			
			entry["tire_compound"] = _get_ideal_compound_for_water(water_level)
			entry["used_compounds"] = [entry["tire_compound"]]
			entry["tire_wear"] = 100.0
			entry["tire_degradation_per_5pct"] = randf_range(0.01, 0.07)
			entry["stint_lap"] = 0
			entry["pit_stops"] = 0
			entry["grid_start_pos"] = 0
			entry["pit_window_offset"] = randi_range(-2, 2)
			
			var team_info = Database._get_team_by_name(eq_name)
			entry["Confiabilidade"] = float(team_info.get("Confiabilidade", 80.0)) if not team_info.is_empty() else 80.0
			
			race_drivers.append(entry)
			active_quali_drivers.append(entry)

	active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])

func _reset_session_sectors_for_race() -> void:
	session_best_sectors = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
	session_fastest_lap = {"driver": "", "time": 999.0}
	for d in race_drivers:
		d["best_personal_sectors"] = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
		d["sector_colors"] = {"s1": "⬜", "s2": "⬜", "s3": "⬜"}

# --- ORDEM CORRETA DE PNEUS CONFORME A UMIDADE ---
func _get_ideal_compound_for_water(w_level: float) -> String:
	if w_level >= 50.0:
		return "Wet"     # >= 50%: Wet é o melhor pneu
	elif w_level >= 16.0:
		return "Inter"   # 16 - 49%: Intermediário é o melhor pneu
	return "Soft"        # 0 - 15%: Slicks são os melhores pneus

func _calculate_tire_lap_delta(compound: String, stint_lap: int) -> float:
	var lap = float(clamp(stint_lap, 1, 60))
	match compound.to_upper():
		"SOFT", "MACIO", "S":
			if lap <= 8.0: return 0.0 + (lap - 1.0) * 0.035
			elif lap <= 15.0: return 0.25 + (lap - 8.0) * 0.07
			else: return 0.74 + pow(lap - 15.0, 1.28) * 0.125
		"MEDIUM", "MÉDIO", "M", "INTER", "INTERMEDIÁRIO", "I", "WET", "CHUVA", "W":
			if lap <= 15.0: return 0.70 + (lap - 1.0) * 0.022
			else: return 1.01 + pow(lap - 15.0, 1.15) * 0.031
		"HARD", "DURO", "H":
			return 1.50 + (lap - 1.0) * 0.023
		_:
			return 0.70 + (lap - 1.0) * 0.025

func _process_driver_sectors(driver: Dictionary, total_lap_time: float) -> void:
	var sectors = _calculate_lap_sectors(total_lap_time)
	driver["last_sectors"] = sectors
	if not driver.has("best_personal_sectors"):
		driver["best_personal_sectors"] = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
	if not driver.has("sector_colors"):
		driver["sector_colors"] = {"s1": "🟨", "s2": "🟨", "s3": "🟨"}
	
	for sec_key in ["s1", "s2", "s3"]:
		var sec_time = sectors[sec_key]
		var best_personal = float(driver["best_personal_sectors"].get(sec_key, 999.0))
		var best_session = float(session_best_sectors.get(sec_key, 999.0))
		
		if sec_time < best_session:
			session_best_sectors[sec_key] = sec_time
			driver["best_personal_sectors"][sec_key] = sec_time
			driver["sector_colors"][sec_key] = "🟪"
		elif sec_time < best_personal:
			driver["best_personal_sectors"][sec_key] = sec_time
			driver["sector_colors"][sec_key] = "🟩"
		else:
			driver["sector_colors"][sec_key] = "🟨"

func _update_single_sector_color(driver: Dictionary, sec_key: String, sec_time: float) -> void:
	var best_personal = float(driver["best_personal_sectors"].get(sec_key, 999.0))
	var best_session = float(session_best_sectors.get(sec_key, 999.0))
	
	if sec_time < best_session:
		session_best_sectors[sec_key] = sec_time
		driver["best_personal_sectors"][sec_key] = sec_time
		driver["sector_colors"][sec_key] = "🟪"
	elif sec_time < best_personal:
		driver["best_personal_sectors"][sec_key] = sec_time
		driver["sector_colors"][sec_key] = "🟩"
	else:
		driver["sector_colors"][sec_key] = "🟨"

func skip_to_end_of_quali_session() -> void:
	if is_quali_done():
		return
	var current_target_phase = quali_phase
	while quali_phase == current_target_phase and not is_quali_done():
		process_quali_tick(5.0)

func _advance_quali_session() -> void:
	quali_time_elapsed = 0.0
	quali_checker_flag = false
	
	if quali_phase == "Q1":
		active_quali_drivers.sort_custom(func(a, b):
			return _compare_lap_times(
				float(a.get("BestQualiTime", 999.0)),
				float(b.get("BestQualiTime", 999.0)),
				str(a.get("Nome", "")),
				str(b.get("Nome", ""))
			)
		)
		var cutoff = max(0, active_quali_drivers.size() - 6)
		var next_drivers: Array = []
		var q1_elim_this_phase: Array = []
		
		for i in range(active_quali_drivers.size()):
			if i >= cutoff:
				var elim = active_quali_drivers[i]
				elim["QualiStatus"] = "ELIMINADO Q1"
				elim["quali_state"] = "Box"
				q1_elim_this_phase.append(elim)
			else:
				active_quali_drivers[i]["BestQualiTime"] = 999.0
				active_quali_drivers[i]["LastLapTime"] = 999.0
				active_quali_drivers[i]["quali_state"] = "Box"
				active_quali_drivers[i]["timer_state"] = randf_range(20.0, 60.0)
				active_quali_drivers[i]["quali_retry_allowed"] = true
				active_quali_drivers[i]["progress"] = 0.0
				active_quali_drivers[i]["is_in_pit"] = true
				active_quali_drivers[i]["force_in_lap"] = true
				active_quali_drivers[i]["quali_lap_duration"] = _get_base_track_lap_time() * 1.08
				next_drivers.append(active_quali_drivers[i])
				
		q1_elim_this_phase.sort_custom(func(a, b):
			return _compare_lap_times(a["BestQualiTime"], b["BestQualiTime"], a["Nome"], b["Nome"])
		)
		for e in q1_elim_this_phase:
			eliminated_drivers.append(e)

		active_quali_drivers = next_drivers
		active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])
		quali_phase = "Q2"
		race_logs.append("🏁 FIM DO Q1: 6 pilotos eliminados.")
		
	elif quali_phase == "Q2":
		active_quali_drivers.sort_custom(func(a, b):
			return _compare_lap_times(
				float(a.get("BestQualiTime", 999.0)),
				float(b.get("BestQualiTime", 999.0)),
				str(a.get("Nome", "")),
				str(b.get("Nome", ""))
			)
		)
		var cutoff = min(10, max(0, active_quali_drivers.size() - 6))
		var next_drivers: Array = []
		var q2_elim_this_phase: Array = []
		
		for i in range(active_quali_drivers.size()):
			if i >= cutoff:
				var elim = active_quali_drivers[i]
				elim["QualiStatus"] = "ELIMINADO Q2"
				elim["quali_state"] = "Box"
				q2_elim_this_phase.append(elim)
			else:
				active_quali_drivers[i]["BestQualiTime"] = 999.0
				active_quali_drivers[i]["LastLapTime"] = 999.0
				active_quali_drivers[i]["quali_state"] = "Box"
				active_quali_drivers[i]["timer_state"] = randf_range(20.0, 60.0)
				active_quali_drivers[i]["quali_retry_allowed"] = true
				active_quali_drivers[i]["progress"] = 0.0
				active_quali_drivers[i]["is_in_pit"] = true
				active_quali_drivers[i]["force_in_lap"] = true
				active_quali_drivers[i]["quali_lap_duration"] = _get_base_track_lap_time() * 1.08
				next_drivers.append(active_quali_drivers[i])
				
		q2_elim_this_phase.sort_custom(func(a, b):
			return _compare_lap_times(a["BestQualiTime"], b["BestQualiTime"], a["Nome"], b["Nome"])
		)
		
		var updated_elim: Array = []
		for e in q2_elim_this_phase:
			updated_elim.append(e)
		for e in eliminated_drivers:
			updated_elim.append(e)
		eliminated_drivers = updated_elim

		active_quali_drivers = next_drivers
		active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])
		quali_phase = "Q3"
		race_logs.append("🏁 FIM DO Q2: 6 pilotos eliminados.")
		
	elif quali_phase == "Q3":
		full_grid.clear()
		active_quali_drivers.sort_custom(func(a, b):
			return _compare_lap_times(a["BestQualiTime"], b["BestQualiTime"], a["Nome"], b["Nome"])
		)
		
		for d in active_quali_drivers:
			d["QualiStatus"] = "CLASSIFICADO"
			full_grid.append(d)
			
		for d in eliminated_drivers:
			full_grid.append(d)
		
		var pos_idx = 1
		for d in full_grid:
			d["grid_start_pos"] = pos_idx
			_initialize_driver_race_strategy(d, pos_idx)
			pos_idx += 1
			
		quali_phase = "FINISHED"
		race_drivers = full_grid.duplicate()
		race_elapsed_time = 0.0
		_reset_session_sectors_for_race()
		# --- ZERA A ADERÊNCIA PARA O INÍCIO DA CORRIDA ---
		track_grip = 0.0
		race_logs.append("🏁 QUALIFICAÇÃO CONCLUÍDA! Grid de largada pronto.")

func _compare_lap_times(time_a: float, time_b: float, name_a: String, name_b: String) -> bool:
	if time_a >= 900.0 and time_b >= 900.0: return name_a < name_b
	if time_a < 900.0 and time_b >= 900.0: return true
	if time_a >= 900.0 and time_b < 900.0: return false
	if time_a == time_b: return name_a < name_b
	return time_a < time_b

func _initialize_driver_race_strategy(driver: Dictionary, start_pos: int) -> void:
	var first_compound = _get_ideal_compound_for_water(water_level)
	if first_compound not in ["Wet", "Inter"]:
		var strategy_roll = randf()
		if total_laps >= 60:
			first_compound = "Medium" if strategy_roll < 0.55 else ("Soft" if strategy_roll < 0.80 else "Hard")
		else:
			first_compound = "Medium" if start_pos <= 10 else ("Hard" if strategy_roll < 0.70 else "Soft")
			
	driver["tire_compound"] = first_compound
	driver["used_compounds"] = [first_compound]
	driver["stint_lap"] = 0
	driver["pit_window_offset"] = randi_range(-2, 2)
	driver["tire_degradation_per_5pct"] = randf_range(0.01, 0.07)

func process_lap() -> Dictionary:
	if current_lap >= total_laps:
		is_race_finished = true
		return {"finished": true}
		
	if pending_red_flag_modal:
		return {"finished": false, "red_flag": true}

	if current_lap == total_laps - 2:
		var missing_manager_compound := false
		for driver in race_drivers:
			if str(driver.get("Status", "")) == "Na Pista" \
			and bool(driver.get("manager_controlled", false)) \
			and driver.get("used_compounds", []).size() < 2 \
			and not bool(driver.get("pit_requested", false)):
				missing_manager_compound = true
				break
		if missing_manager_compound:
			if not manager_tire_rule_warning_logged:
				race_logs.append("⚠️ Regra de pneus: chame seus pilotos ao box antes da última volta para usar um segundo composto.")
				manager_tire_rule_warning_logged = true
			return {"finished": false, "awaiting_manager_pit": true}
		manager_tire_rule_warning_logged = false

	current_lap += 1
	var lap_events: Array = []
	var lap_pit_events: Array = []
	var flag_at_lap_start := safety_car_status
	var was_raining := rain_intensity > 0.0
	
	_process_weather_and_water_accumulation(lap_events)
	var weather_changed_this_lap := was_raining != (rain_intensity > 0.0)

	var accident_this_lap = false
	var accident_sector = 0
	var base_track_lap = _get_base_track_lap_time()

	for d in race_drivers:
		if d["Status"] != "Na Pista":
			continue
			
		d["is_in_pit"] = false
		var stint_lap = int(d.get("stint_lap", 0)) + 1
		d["stint_lap"] = stint_lap
		
		# --- CHECAGEM DE DNF MECÂNICO BALANCEADO ---
		var rel_val = float(d.get("Confiabilidade", 80.0))
		if calculate_mechanical_dnf_chance(rel_val):
			d["Status"] = "Abandonou (Quebra)"
			d["retired_lap"] = current_lap
			d["is_in_pit"] = false
			d["dnf"] = true
			d["abandonou"] = true
			lap_events.append("⚙️ ABANDONO MECÂNICO: " + d["Nome"] + " (" + d["Equipe"] + ") teve uma falha de motor/câmbio na volta " + str(current_lap) + ".")
			continue

		var compound = str(d.get("tire_compound", "Medium"))
		var tire_durability_before_lap := clampf(float(d.get("tire_wear", 100.0)), 0.0, 100.0)
		var wear_rate = 3.3 if compound in ["Soft", "Macio"] else (2.0 if compound in ["Medium", "Médio"] else (1.8 if compound in ["Inter", "Wet"] else 1.2))
		if safety_car_status in ["SC", "VSC"]:
			wear_rate *= 0.35
		elif safety_car_status == "YELLOW":
			wear_rate *= 0.7
		var pace_time_modifier := 0.0
		match str(d.get("estilo", "Normal")):
			"Conservador":
				pace_time_modifier = 0.35
				wear_rate *= 0.75
			"Agressivo", "Ataque Máximo":
				pace_time_modifier = -0.25
				wear_rate *= 1.25
		d["tire_wear"] = max(0.0, float(d.get("tire_wear", 100.0)) - wear_rate)
		
		var ideal_compound = _get_ideal_compound_for_water(water_level)
		var needs_pit = false
		var target_compound = compound
		var remaining_laps = total_laps - current_lap
		var pit_count = int(d.get("pit_stops", 0))
		var offset = int(d.get("pit_window_offset", 0))
		
		var wear_pit_chance := 0.0
		if tire_durability_before_lap <= 70.0:
			wear_pit_chance = clampf(0.01 + ((70.0 - tire_durability_before_lap) / 60.0) * 0.99, 0.01, 1.0)
		var pit_for_wear := randf() < wear_pit_chance
		
		if bool(d.get("manager_controlled", false)):
			var manager_requested_pit := bool(d.get("pit_requested", false))
			needs_pit = remaining_laps > 0 and manager_requested_pit
			if needs_pit:
				target_compound = str(d.get("pit_requested_tire", compound))
				d["pit_requested"] = false
				d["pit_requested_tire"] = ""
		elif remaining_laps > 0 and weather_changed_this_lap:
			needs_pit = true
			if rain_intensity > 0.0:
				target_compound = "Wet" if water_level >= 50.0 or rain_intensity >= 2.0 else "Inter"
			else:
				target_compound = _get_ideal_compound_for_water(water_level)
				if target_compound in ["Wet", "Inter"] and water_level < 16.0:
					target_compound = _select_next_dry_compound(d, remaining_laps)
		elif remaining_laps > 0:
			if ideal_compound in ["Wet", "Inter"] and compound != ideal_compound:
				needs_pit = true
				target_compound = ideal_compound
			elif ideal_compound not in ["Wet", "Inter"] and compound in ["Wet", "Inter"]:
				needs_pit = true
				target_compound = _select_next_dry_compound(d, remaining_laps)
			elif pit_count == 0 and remaining_laps <= max(2, 6 + offset):
				needs_pit = true
				target_compound = _select_next_dry_compound(d, remaining_laps)
			elif pit_for_wear:
				needs_pit = true
				target_compound = ideal_compound if ideal_compound in ["Wet", "Inter"] else _select_next_dry_compound(d, remaining_laps)

			if needs_pit and not weather_changed_this_lap and target_compound == compound:
				target_compound = _select_next_dry_compound(d, remaining_laps)
			if needs_pit and not weather_changed_this_lap and pit_count == 0 and d.get("used_compounds", []).size() < 2 and target_compound == compound:
				target_compound = _select_next_dry_compound(d, remaining_laps)
			
		if needs_pit:
			d["is_in_pit"] = true
			d["pit_stops"] += 1
			d["tire_wear"] = 100.0
			d["stint_lap"] = 1
			d["tire_compound"] = target_compound
			if not d["used_compounds"].has(target_compound):
				d["used_compounds"].append(target_compound)
				
			var track_pit_lane_loss = float(track.get("pit_loss_time", randf_range(20.0, 25.0)))
			var team_name = str(d.get("Equipe", ""))
			var team = Database._get_team_by_name(team_name)
			
			var car_power = float(team.get("Motor", 80)) * 0.35 + float(team.get("Aero", 80)) * 0.40 + float(team.get("Chassi", 80)) * 0.25
			var normalized_power = clamp((car_power - 60.0) / 40.0, 0.0, 1.0)
			var base_stop_duration = lerp(3.0, 1.8, normalized_power) + randf_range(-0.1, 0.1)
			base_stop_duration = clamp(base_stop_duration, 1.8, 3.0)
			
			var team_morale = float(d.get("Moral", 75.0))
			var error_chance = clamp(0.12 - (team_morale * 0.001), 0.01, 0.18)
			var pit_error_msg = ""
			
			if randf() < error_chance:
				var extra_time = randf_range(2.5, 5.0)
				base_stop_duration += extra_time
				pit_error_msg = " ⚠️ ERRO NO PIT STOP (+%ss)" % str(snapped(extra_time, 0.1))
				
			var total_pit_time_loss = track_pit_lane_loss + base_stop_duration
			
			# Penalidades de aderência e chuva aplicadas no pit lap base
			var pit_lap_base = (base_track_lap + _calculate_tire_lap_delta(target_compound, 1)) * get_track_condition_lap_time_multiplier()
			var lap_time = pit_lap_base + total_pit_time_loss + randf_range(-0.2, 0.2)
			
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			_process_driver_sectors(d, pit_lap_base)
			
			var reenter_pos = 1
			for other in race_drivers:
				if other["Status"] == "Na Pista" and other["TempoTotal"] < d["TempoTotal"]:
					reenter_pos += 1
					
			pit_logs.append("🛠️ Volta %d: %s (%s) — Parada: %ss | Perda no Pit: %ss | Voltou em P%d%s" % [
				current_lap,
				d["Nome"],
				d["Equipe"],
				str(snapped(base_stop_duration, 0.1)),
				str(snapped(total_pit_time_loss, 0.1)),
				reenter_pos,
				pit_error_msg
			])
		else:
			var team_name = str(d.get("Equipe", ""))
			var team = Database._get_team_by_name(team_name)
			
			var car_power = float(team.get("Motor", 80)) * 0.35 + float(team.get("Aero", 80)) * 0.40 + float(team.get("Chassi", 80)) * 0.25
			var car_time_bonus = (car_power - 50.0) * 0.060
			
			var driver_skill = _get_effective_driver_skill(d, "Corrida")
			var driver_time_bonus = (driver_skill - 50.0) * 0.013
			
			var tire_delta = _calculate_tire_lap_delta(compound, stint_lap)
			var tire_wear_percent := 100.0 - float(d.get("tire_wear", 100.0))
			var degradation_step := float(d.get("tire_degradation_per_5pct", 0.07))
			var tire_degradation: float = floorf(tire_wear_percent / 5.0) * degradation_step
			
			var compound_weather_penalty = 0.0
			if water_level >= 50.0 and compound != "Wet":
				compound_weather_penalty += 12.0
			elif water_level >= 16.0 and water_level < 50.0 and compound != "Inter":
				compound_weather_penalty += 6.0
			elif water_level < 16.0 and compound in ["Wet", "Inter"]:
				compound_weather_penalty += 8.0
				
			var morale_time_modifier = (50.0 - float(d.get("Moral", 75))) * 0.003
			
			var lap_time = base_track_lap - car_time_bonus - driver_time_bonus + tire_delta + tire_degradation + compound_weather_penalty + morale_time_modifier + pace_time_modifier + randf_range(-0.10, 0.10)
			
			if current_lap == 1:
				lap_time = base_track_lap + randf_range(-0.20, 0.20)
			lap_time *= get_track_condition_lap_time_multiplier()
			
			if safety_car_status == "SC":
				lap_time *= 1.45
			elif safety_car_status == "VSC":
				lap_time *= 1.25
			elif safety_car_status == "YELLOW":
				lap_time *= 1.15
				
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			_process_driver_sectors(d, lap_time)
			
			if lap_time < float(session_fastest_lap.get("time", 999.0)):
				session_fastest_lap = {"driver": d["Nome"], "time": lap_time}
			
		var morale_val = float(d.get("Moral", 75))
		var crash_chance = 0.005 if morale_val < 40 else 0.002
		if water_level > 15.0 and _check_wet_race_dnf_risk(d):
			crash_chance += 0.004
			
		if randf() < crash_chance:
			var is_crash = randf() >= 0.6
			accident_sector = randi_range(1, 3)
			d["Status"] = "Abandonou (Acidente)" if is_crash else "Abandonou (Quebra)"
			d["retired_lap"] = current_lap
			d["is_in_pit"] = false
			d["dnf"] = true
			d["abandonou"] = true
			accident_this_lap = is_crash or accident_this_lap
			lap_events.append("💥 ABANDONO: " + d["Nome"] + " (" + d["Equipe"] + ") fora no SETOR " + str(accident_sector) + " na volta " + str(current_lap) + ".")

	# Executa os duelos roda a roda em carros com gap < 0.3s
	_process_wheel_to_wheel_battles()

	if accident_this_lap and safety_car_status == "NONE":
		incident_sector = accident_sector
		var roll = randf()
		if roll < 0.35:
			safety_car_status = "SC"
			safety_car_laps_left = randi_range(2, 3)
			lap_events.append("🚨 SAFETY CAR ENTROU NA PISTA! (Incidente no Setor " + str(incident_sector) + ")")
		elif roll < 0.60:
			safety_car_status = "VSC"
			safety_car_laps_left = randi_range(1, 2)
			lap_events.append("🟡 VIRTUAL SAFETY CAR (VSC) ACIONADO! (Setor " + str(incident_sector) + ")")
		elif roll < 0.85:
			safety_car_status = "YELLOW"
			safety_car_laps_left = randi_range(1, 2)
			lap_events.append("⚠️ BANDEIRA AMARELA NO SETOR " + str(incident_sector) + "!")
		else:
			safety_car_status = "RED_FLAG"
			red_flag_active = true
			pending_red_flag_modal = true
			lap_events.append("🔴 BANDEIRA VERMELHA! Corrida paralisada devido ao acidente no Setor " + str(incident_sector) + ".")

	race_drivers.sort_custom(func(a, b):
		var a_active = a["Status"] == "Na Pista"
		var b_active = b["Status"] == "Na Pista"
		if a_active and not b_active: return true
		if not a_active and b_active: return false
		if a_active and b_active: return a["TempoTotal"] < b["TempoTotal"]
		return int(a.get("retired_lap", 0)) > int(b.get("retired_lap", 0))
	)

	if safety_car_status == "SC":
		var current_accumulated_gap = 0.0
		for i in range(race_drivers.size()):
			if race_drivers[i]["Status"] == "Na Pista":
				if i == 0:
					race_drivers[i]["TempoTotal"] = race_drivers[0]["TempoTotal"]
				else:
					var delta = randf_range(0.150, 0.380)
					current_accumulated_gap += delta
					race_drivers[i]["TempoTotal"] = race_drivers[0]["TempoTotal"] + current_accumulated_gap

	if flag_at_lap_start in ["SC", "VSC", "YELLOW"] and safety_car_status == flag_at_lap_start:
		safety_car_laps_left -= 1
		if safety_car_laps_left <= 0:
			safety_car_status = "NONE"
			incident_sector = 0
			lap_events.append("🟢 BANDEIRA VERDE: Pista liberada / SC recolhido.")

	race_logs.append_array(lap_events)
	pit_logs.append_array(lap_pit_events)
	
	if current_lap >= total_laps:
		is_race_finished = true
		
	return {
		"finished": is_race_finished,
		"lap": current_lap,
		"events": lap_events,
		"standings": race_drivers,
		"red_flag": pending_red_flag_modal
	}

var quali_weather_timer: float = 0.0

func _calculate_driver_lap_pace(driver_data: Dictionary, base_track_time: float, is_wet_flag: bool) -> float:
	var overall = _get_effective_driver_skill(driver_data, "Corrida")
	var rain_skill = _get_effective_driver_skill(driver_data, "HabilidadeChuva")
	
	var effective_skill = rain_skill if is_wet_flag else overall
	var skill_time_bonus = (effective_skill - 50.0) * 0.015
	
	return base_track_time - skill_time_bonus

func _check_wet_race_dnf_risk(driver_data: Dictionary) -> bool:
	var rain_skill = _get_effective_driver_skill(driver_data, "HabilidadeChuva")
	var wet_mistake_risk = (100.0 - rain_skill) * 0.0001
	return randf() < wet_mistake_risk

func _process_wheel_to_wheel_battles() -> void:
	if safety_car_status != "NONE":
		return

	var active_drivers: Array = []
	for d in race_drivers:
		if d.get("Status", "Na Pista") == "Na Pista":
			active_drivers.append(d)
			
	if active_drivers.size() < 2:
		return
		
	for i in range(1, active_drivers.size()):
		var attacker = active_drivers[i]
		var defender = active_drivers[i - 1]
		
		var gap = float(attacker.get("TempoTotal", 0.0)) - float(defender.get("TempoTotal", 0.0))
		
		if gap > 0.0 and gap <= 0.3:
			var ovt_skill = _get_effective_driver_skill(attacker, "Ultrapassagem")
			var def_skill = _get_effective_driver_skill(defender, "Defesa")
			
			var success_rate = 0.50 + ((ovt_skill - def_skill) / 200.0)
			success_rate = clampf(success_rate, 0.15, 0.85)
			
			if randf() < success_rate:
				var swap_time = float(defender["TempoTotal"]) - 0.05
				attacker["TempoTotal"] = swap_time
				

# Processa o ciclo de voltas e avanço de cada piloto na qualificação
func process_quali_tick(delta: float) -> void:
	if is_quali_done(): return
	
	quali_time_elapsed += delta
	quali_total_elapsed_time += delta
	track_condition_time_accumulator += delta
	while track_condition_time_accumulator >= 90.0:
		var condition_events: Array = []
		_process_weather_and_water_accumulation(condition_events)
		race_logs.append_array(condition_events)
		track_condition_time_accumulator -= 90.0
	var current_limit = quali_durations.get(quali_phase, 1080.0)
	
	if quali_time_elapsed >= current_limit and not quali_checker_flag:
		quali_checker_flag = true
		for d in active_quali_drivers:
			var state := str(d.get("quali_state", "Box"))
			if state == "Hot Lap":
				d["force_in_lap"] = true
			elif state != "Box":
				d["quali_state"] = "Box"
				d["is_in_pit"] = true
				d["progress"] = 0.0
				d["quali_retry_allowed"] = false

	for d in active_quali_drivers:
		var st = str(d.get("quali_state", "Box"))
		if st == "Box":
			if bool(d.get("manager_controlled", false)):
				d["timer_state"] = maxf(0.0, float(d.get("timer_state", 0.0)) - delta)
				continue
			if quali_checker_flag or not bool(d.get("quali_retry_allowed", true)):
				continue
			d["timer_state"] = float(d.get("timer_state", 0.0)) - delta
			if float(d["timer_state"]) <= 0.0:
				d["quali_state"] = "Em pista"
				d["tire_compound"] = _get_ideal_compound_for_water(water_level)
				d["is_in_pit"] = false
				d["progress"] = 0.0
				d["quali_retry_allowed"] = false
				d["force_in_lap"] = true
				d["quali_lap_duration"] = _get_base_track_lap_time() * 1.08
				race_logs.append("🏎️ %s deixou os boxes para iniciar uma volta de classificação." % str(d.get("Nome", "Piloto")))
			continue
			
		d["progress"] = float(d.get("progress", 0.0)) + delta
		
		# Concluiu uma volta na pista
		while str(d.get("quali_state", "Box")) != "Box":
			var lap_duration := maxf(1.0, float(d.get("quali_lap_duration", _get_base_track_lap_time())))
			if float(d["progress"]) < lap_duration:
				break
			d["progress"] = float(d["progress"]) - lap_duration
			st = str(d.get("quali_state", "Box"))
			if st == "Em pista":
				# Transiciona da volta de saída para a volta rápida oficial (Hot Lap)
				d["quali_state"] = "Hot Lap"
				d["pending_lap_time"] = _calculate_simulated_lap_time(d)
				d["quali_lap_duration"] = d["pending_lap_time"]
			elif st == "Hot Lap":
				# Simula o tempo de volta com base no OVR e no Power Index
				var lap_time = float(d.get("pending_lap_time", 0.0))
				if lap_time <= 0.0:
					lap_time = _calculate_simulated_lap_time(d)
				record_driver_quali_lap(d, lap_time)
				_process_driver_sectors(d, lap_time)
				
				# Se o jogador marcou para recolher ou se é IA, entra no box após o Hot Lap
				if d.get("force_in_lap", true):
					d["quali_state"] = "Em Entrada"
					d["quali_lap_duration"] = _get_base_track_lap_time() * 1.08
				else:
					d["quali_state"] = "Hot Lap" # Permite continuar para outra volta rápida
					d["pending_lap_time"] = _calculate_simulated_lap_time(d)
					d["quali_lap_duration"] = d["pending_lap_time"]
			elif st == "Em Entrada":
				d["quali_state"] = "Box"
				d["is_in_pit"] = true
				d["progress"] = 0.0
				d["timer_state"] = randf_range(30.0, 120.0)
				d["quali_retry_allowed"] = quali_time_elapsed + float(d["timer_state"]) < float(current_limit)
				d["force_in_lap"] = true
				race_logs.append("🏁 %s retornou aos boxes após a volta de classificação." % str(d.get("Nome", "Piloto")))

	if quali_checker_flag:
		var drivers_finished_lap := true
		for d in active_quali_drivers:
			if str(d.get("quali_state", "Box")) != "Box":
				drivers_finished_lap = false
				break
		if drivers_finished_lap:
			_advance_quali_session()

# Calcula o tempo de volta em segundos de forma coerente com o desempenho do carro
func _calculate_simulated_lap_time(driver_dict: Dictionary) -> float:
	var base_track_time = _get_base_track_lap_time()
	var driver_ovr = float(driver_dict.get("ovr", driver_dict.get("OVR", 75.0)))
	var team_power = float(Database.get_team_power_index(driver_dict.get("Equipe", ""))["overall"])
	
	var time_modifier = (100.0 - driver_ovr) * 0.05 + (100.0 - team_power) * 0.08
	match str(driver_dict.get("estilo", "Normal")):
		"Conservador":
			time_modifier += 0.2
		"Agressivo", "Ataque Máximo":
			time_modifier -= 0.2
	var random_variance = randf_range(-0.25, 0.25)
	
	return (base_track_time + time_modifier + random_variance) * get_track_condition_lap_time_multiplier()

# Atualiza os tempos de volta do piloto na classificação
func record_driver_quali_lap(driver_dict: Dictionary, lap_time: float) -> void:
	# 1. Atualiza sempre a última volta realizada
	driver_dict["LastLapTime"] = lap_time
	driver_dict["last_lap"] = lap_time
	
	# 2. Pega o tempo atual registrado como melhor volta
	var current_best = float(driver_dict.get("BestQualiTime", driver_dict.get("best_lap", 999.0)))
	
	# Se current_best for 0.0, menor que 10.0 ou 999.0, significa que não tinha tempo válido ainda
	if current_best <= 10.0 or current_best >= 900.0:
		current_best = 999.0
		
	# Se a nova volta for mais rápida que a anterior (ou for a primeira volta válida)
	if lap_time < current_best and lap_time > 30.0:
		driver_dict["BestQualiTime"] = lap_time
		driver_dict["best_lap"] = lap_time

func _process_weather_and_water_accumulation(lap_events: Array, elapsed_time_factor: float = 1.0) -> void:
	if forecast_laps_left > 0:
		forecast_laps_left = max(0, forecast_laps_left - int(ceil(elapsed_time_factor)))
		if forecast_laps_left == 0 and pending_weather_change != "NONE":
			match pending_weather_change:
				"RAIN_START":
					rain_intensity = randf_range(1.0, 1.5)
					weather_state = "🌧️ Chuva Leve"
					weather_forecast = "🌧️ Chuva em Andamento"
					lap_events.append("🌧️ COMEÇOU A CHOVER! A umidade começou a subir e a pista perde aderência.")
				"RAIN_HEAVY":
					rain_intensity = randf_range(2.0, 3.0)
					weather_state = "⛈️ Chuva Forte"
					weather_forecast = "⛈️ Temporal Instável"
					lap_events.append("⛈️ A CHUVA APERTOU! Intensidade máxima na pista.")
				"RAIN_STOP":
					rain_intensity = 0.0
					weather_state = "☁️ Nublado"
					weather_forecast = "☀️ Pista Secando"
					lap_events.append("☁️ A CHUVA PAROU! A pista começou a secar.")
			pending_weather_change = "NONE"
	else:
		var chance = track.get("ChanceChuva", 0.20)
		if rain_intensity == 0.0 and randf() < (chance * 0.005 * elapsed_time_factor):
			forecast_laps_left = randi_range(3, 6)
			pending_weather_change = "RAIN_START"
			weather_forecast = "🌧️ Chuva Prevista"
			lap_events.append("📡 RADAR METEOROLÓGICO: Nuvens de chuva se aproximando do circuito!")
		elif rain_intensity > 0.0 and randf() < (0.01 * elapsed_time_factor):
			forecast_laps_left = randi_range(3, 5)
			if rain_intensity < 2.0 and randf() < 0.4:
				pending_weather_change = "RAIN_HEAVY"
				weather_forecast = "⛈️ Tempestade Prevista"
				lap_events.append("📡 RADAR METEOROLÓGICO: Tempestade se aproximando!")
			else:
				pending_weather_change = "RAIN_STOP"
				weather_forecast = "☀️ Estiagem Prevista"
				lap_events.append("📡 RADAR METEOROLÓGICO: A chuva deve parar em breve.")

	# One completed lap represents 90 seconds of track evolution.
	if rain_intensity > 0.0:
		water_level = minf(100.0, water_level + WATER_GAIN_PER_LAP * elapsed_time_factor)
		track_grip = maxf(0.0, track_grip - GRIP_LOSS_PER_WET_LAP * elapsed_time_factor)
	else:
		track_grip = minf(100.0, track_grip + GRIP_GAIN_PER_DRY_LAP * elapsed_time_factor)
		if water_level > 0.0:
			water_level = maxf(0.0, water_level - WATER_DRYING_PER_LAP * elapsed_time_factor)
			if water_level == 0.0 and weather_state != "☀️ Ensolarado":
				weather_state = "☀️ Ensolarado"
				weather_forecast = "☀️ Tempo Limpo"
				lap_events.append("☀️ A PISTA SECOU COMPLETAMENTE!")

func resolve_red_flag_restart(_ignored_user_choice: String = "") -> void:
	pending_red_flag_modal = false
	red_flag_active = false
	safety_car_status = "NONE"
	incident_sector = 0
	
	for d in race_drivers:
		if d["Status"] == "Na Pista":
			var choice = _get_ideal_compound_for_water(water_level)
			if choice not in ["Wet", "Inter"]:
				choice = _select_next_dry_compound(d, total_laps - current_lap)
			d["tire_compound"] = choice
			d["tire_wear"] = 100.0
			d["stint_lap"] = 1
			if not d["used_compounds"].has(choice):
				d["used_compounds"].append(choice)

	var accumulated_start_gap = 0.0
	for i in range(race_drivers.size()):
		if race_drivers[i]["Status"] == "Na Pista":
			race_drivers[i]["TempoTotal"] = accumulated_start_gap
			accumulated_start_gap += 0.200

	race_logs.append("🟢 RELARGADA EM GRID DE LARGADA REALIZADA NA VOLTA " + str(current_lap) + ".")

func _select_next_dry_compound(driver: Dictionary, remaining_laps: int) -> String:
	var used = driver.get("used_compounds", [])
	var candidates: Array = []
	
	if remaining_laps <= 14: candidates = ["Soft", "Medium", "Hard"]
	elif remaining_laps <= 28: candidates = ["Medium", "Soft", "Hard"]
	else: candidates = ["Hard", "Medium", "Soft"]
		
	for c in candidates:
		if not used.has(c):
			return c
			
	return candidates[0]

func calculate_mechanical_dnf_chance(team_reliability: float) -> bool:
	var total_team_failure_chance = maxf(100.0 - team_reliability, 0.4) 
	var driver_failure_chance_gp = (total_team_failure_chance / 100.0) / 4.0 
	var lap_failure_chance = driver_failure_chance_gp / float(max(total_laps, 1))
	return randf() < lap_failure_chance

func _get_effective_driver_skill(driver_data: Dictionary, skill_name: String) -> float:
	var base_val = float(driver_data.get(skill_name, driver_data.get("Overall", 75)))
	var has_temp_bonus = int(driver_data.get("bonus_temporario_laps", 0)) > 0
	
	if has_temp_bonus:
		return base_val + 2.0
	return base_val

func request_manager_pit_stop(driver_name: String, tire_compound: String = "", driving_style: String = "") -> bool:
	for driver in race_drivers:
		if str(driver.get("Nome", "")).strip_edges().to_lower() != driver_name.strip_edges().to_lower():
			continue
		if not bool(driver.get("manager_controlled", false)) or str(driver.get("Status", "")) != "Na Pista":
			return false
		if current_lap >= total_laps - 1:
			pit_logs.append("⚠️ %s não pode parar na última volta." % driver_name)
			return false
		var used_compounds: Array = driver.get("used_compounds", [])
		if used_compounds.size() < 2 and not tire_compound.is_empty() and used_compounds.has(tire_compound):
			pit_logs.append("⚠️ Selecione um composto diferente para cumprir a regra dos dois tipos de pneus.")
			return false
		driver["pit_requested"] = true
		driver["pit_requested_tire"] = tire_compound
		if not driving_style.is_empty():
			driver["estilo"] = driving_style
		return true
	return false

# Exemplo de verificação dentro da simulação da corrida por volta
func _check_manager_planned_pit_stop(car: Dictionary, current_lap: int) -> void:
	if not car.get("is_player", false): return
	
	var p_idx = int(car.get("driver_idx", -1))
	var strategies = Database.user_team.get("race_strategies", {})
	
	if strategies.has(p_idx):
		var strat = strategies[p_idx]
		var pit_stops = strat.get("pit_stops", [])
		
		for stop in pit_stops:
			# Se a volta atual for a volta planejada para a parada
			if int(stop["lap"]) == current_lap:
				car["status"] = "Volta de Entrada"
				car["next_pneu"] = stop["tire"] # Agenda o pneu escolhido pelo jogador!

func _setup_quali_driver_entry(driver_dict: Dictionary) -> Dictionary:
	var entry = driver_dict.duplicate(true)
	
	# Garante que o tempo inicial de classificação seja 999.0 para não travar na P1 com 0:00.000
	entry["BestQualiTime"] = 999.0
	entry["LastLapTime"] = 999.0
	entry["quali_state"] = "Box"
	entry["is_in_pit"] = true
	entry["progress"] = 0.0
	
	return entry
