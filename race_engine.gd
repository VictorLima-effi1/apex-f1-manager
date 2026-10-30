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

# --- EVOLUÇÃO DA PISTA (EMBORRACHAMENTO) ---
var track_grip: float = 0.0 
var quali_total_elapsed_time: float = 0.0 

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

func _calculate_lap_sectors(total_lap_time: float) -> Dictionary:
	var s1 = total_lap_time * 0.30 + randf_range(-0.04, 0.04)
	var s2 = total_lap_time * 0.40 + randf_range(-0.04, 0.04)
	var s3 = total_lap_time - (s1 + s2)
	return {"s1": s1, "s2": s2, "s3": s3}

func setup_race(selected_track: Dictionary) -> void:
	track = selected_track
	total_laps = track.get("Voltas", 58)
	current_lap = 0
	is_race_running = false
	is_race_finished = false
	quali_phase = "Q1"
	quali_time_elapsed = 0.0
	quali_total_elapsed_time = 0.0
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
			entry["pending_lap_time"] = 0.0
			
			entry["last_sectors"] = {"s1": 0.0, "s2": 0.0, "s3": 0.0}
			entry["best_personal_sectors"] = {"s1": 999.0, "s2": 999.0, "s3": 999.0}
			entry["sector_colors"] = {"s1": "⚪", "s2": "⚪", "s3": "⚪"}
			
			entry["tire_compound"] = _get_ideal_compound_for_water(water_level)
			entry["used_compounds"] = [entry["tire_compound"]]
			entry["tire_wear"] = 100.0
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
		d["sector_colors"] = {"s1": "⚪", "s2": "⚪", "s3": "⚪"}

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
	
	for sec_key in ["s1", "s2", "s3"]:
		var sec_time = sectors[sec_key]
		var best_personal = float(driver["best_personal_sectors"].get(sec_key, 999.0))
		var best_session = float(session_best_sectors.get(sec_key, 999.0))
		
		if sec_time < best_session:
			session_best_sectors[sec_key] = sec_time
			driver["best_personal_sectors"][sec_key] = sec_time
			driver["sector_colors"][sec_key] = "🟣"
		elif sec_time < best_personal:
			driver["best_personal_sectors"][sec_key] = sec_time
			driver["sector_colors"][sec_key] = "🟢"
		else:
			driver["sector_colors"][sec_key] = "🟡"

func _update_single_sector_color(driver: Dictionary, sec_key: String, sec_time: float) -> void:
	var best_personal = float(driver["best_personal_sectors"].get(sec_key, 999.0))
	var best_session = float(session_best_sectors.get(sec_key, 999.0))
	
	if sec_time < best_session:
		session_best_sectors[sec_key] = sec_time
		driver["best_personal_sectors"][sec_key] = sec_time
		driver["sector_colors"][sec_key] = "🟣"
	elif sec_time < best_personal:
		driver["best_personal_sectors"][sec_key] = sec_time
		driver["sector_colors"][sec_key] = "🟢"
	else:
		driver["sector_colors"][sec_key] = "🟡"

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

func process_lap() -> Dictionary:
	if current_lap >= total_laps:
		is_race_finished = true
		return {"finished": true}
		
	if pending_red_flag_modal:
		return {"finished": false, "red_flag": true}

	current_lap += 1
	var lap_events: Array = []
	var lap_pit_events: Array = []
	
	_process_weather_and_water_accumulation(lap_events)

	if safety_car_laps_left > 0:
		safety_car_laps_left -= 1
		if safety_car_laps_left <= 0:
			safety_car_status = "NONE"
			incident_sector = 0
			lap_events.append("🟢 BANDEIRA VERDE: Pista liberada / SC recolhido.")

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
		var wear_rate = 3.5 if compound in ["Soft", "Macio"] else (2.2 if compound in ["Medium", "Médio", "Inter", "Wet"] else 1.5)
		if safety_car_status in ["SC", "VSC"]: wear_rate *= 0.35
		d["tire_wear"] = max(0.0, float(d.get("tire_wear", 100.0)) - wear_rate)
		
		var ideal_compound = _get_ideal_compound_for_water(water_level)
		var needs_pit = false
		var target_compound = compound
		var remaining_laps = total_laps - current_lap
		var pit_count = int(d.get("pit_stops", 0))
		var offset = int(d.get("pit_window_offset", 0))
		
		var wear_limit = 12.0 + float(offset)
		var soft_stint_limit = 18 + offset
		
		if ideal_compound in ["Wet", "Inter"] and compound != ideal_compound:
			needs_pit = true
			target_compound = ideal_compound
		elif ideal_compound not in ["Wet", "Inter"] and compound in ["Wet", "Inter"]:
			needs_pit = true
			target_compound = _select_next_dry_compound(d, remaining_laps)
		elif pit_count == 0 and remaining_laps <= max(2, 6 + offset):
			needs_pit = true
			target_compound = _select_next_dry_compound(d, remaining_laps)
		elif d["tire_wear"] < wear_limit or (compound in ["Soft", "Macio"] and stint_lap >= soft_stint_limit) or (safety_car_status != "NONE" and d["tire_wear"] < (35.0 + offset * 2) and remaining_laps > 8):
			needs_pit = true
			target_compound = ideal_compound if ideal_compound in ["Wet", "Inter"] else _select_next_dry_compound(d, remaining_laps)
			
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
			var grip_time_penalty_pit = (1.0 - (track_grip / 100.0)) * 2.5 
			var rain_time_penalty_pit = (water_level / 100.0) * 5.0 
			var pit_lap_base = base_track_lap + grip_time_penalty_pit + rain_time_penalty_pit + _calculate_tire_lap_delta(target_compound, 1)
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
			
			# --- PARTE D: IMPACTO NO TEMPO DE VOLTA (ADERÊNCIA E CHUVA) ---
			# Diferença de 2 - 3 segundos entre aderência 0 (barra vazia) e 100 (barra cheia)
			var grip_time_penalty = (1.0 - (track_grip / 100.0)) * 2.5 
			
			# Diferença de 4 - 6 segundos entre 0% de chuva e 100% de chuva
			var rain_time_penalty = (water_level / 100.0) * 5.0 
			
			var compound_weather_penalty = 0.0
			if water_level >= 50.0 and compound != "Wet":
				compound_weather_penalty += 12.0
			elif water_level >= 16.0 and water_level < 50.0 and compound != "Inter":
				compound_weather_penalty += 6.0
			elif water_level < 16.0 and compound in ["Wet", "Inter"]:
				compound_weather_penalty += 8.0
				
			var morale_time_modifier = (50.0 - float(d.get("Moral", 75))) * 0.003
			
			var lap_time = base_track_lap - car_time_bonus - driver_time_bonus + tire_delta + grip_time_penalty + rain_time_penalty + compound_weather_penalty + morale_time_modifier + randf_range(-0.10, 0.10)
			
			if current_lap == 1:
				lap_time = base_track_lap + randf_range(-0.20, 0.20)
			
			if safety_car_status in ["SC", "VSC"]:
				lap_time *= 1.45
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
				
				var log_msg = "⚔️ ULTRAPASSAGEM: " + str(attacker["Nome"]) + " ultrapassou " + str(defender["Nome"]) + " na disputa por posição!"
				race_logs.append(log_msg)

# Processa o ciclo de voltas e avanço de cada piloto na qualificação
func process_quali_tick(delta: float) -> void:
	if is_quali_done(): return
	
	quali_time_elapsed += delta
	var current_limit = quali_durations.get(quali_phase, 1080.0)
	
	if quali_time_elapsed >= current_limit:
		quali_checker_flag = true

	for d in active_quali_drivers:
		var st = str(d.get("quali_state", "Box"))
		if st == "Box":
			continue
			
		d["progress"] = float(d.get("progress", 0.0)) + (delta * 0.05)
		
		# Concluiu uma volta na pista
		if d["progress"] >= 1.0:
			d["progress"] = 0.0
			
			if st == "Em pista":
				# Transiciona da volta de saída para a volta rápida oficial (Hot Lap)
				d["quali_state"] = "Hot Lap"
			elif st == "Hot Lap":
				# Simula o tempo de volta com base no OVR e no Power Index
				var lap_time = _calculate_simulated_lap_time(d)
				d["LastLapTime"] = lap_time
				
				var best_t = float(d.get("BestQualiTime", 999.0))
				if best_t >= 900.0 or lap_time < best_t:
					d["BestQualiTime"] = lap_time
				
				# Se o jogador marcou para recolher ou se é IA, entra no box após o Hot Lap
				if d.get("force_in_lap", true):
					d["quali_state"] = "Em Entrada"
				else:
					d["quali_state"] = "Hot Lap" # Permite continuar para outra volta rápida
			elif st == "Em Entrada":
				d["quali_state"] = "Box"
				d["is_in_pit"] = true

# Calcula o tempo de volta em segundos de forma coerente com o desempenho do carro
func _calculate_simulated_lap_time(driver_dict: Dictionary) -> float:
	var base_track_time = 80.0 # Tempo base de 1:20.000
	var driver_ovr = float(driver_dict.get("ovr", driver_dict.get("OVR", 75.0)))
	var team_power = float(Database.get_team_power_index(driver_dict.get("Equipe", ""))["overall"])
	
	var time_modifier = (100.0 - driver_ovr) * 0.05 + (100.0 - team_power) * 0.08
	var random_variance = randf_range(-0.25, 0.25)
	
	return base_track_time + time_modifier + random_variance

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

	# Atualização gradual da barra de Umidade/Chuva (water_level)
	if rain_intensity > 0.0:
		var accumulation = rain_intensity * randf_range(2.0, 5.0) * elapsed_time_factor
		water_level = min(100.0, water_level + accumulation)
	else:
		if water_level > 0.0:
			var drying = randf_range(1.5, 4.0) * elapsed_time_factor
			water_level = max(0.0, water_level - drying)
			if water_level == 0.0 and weather_state != "☀️ Ensolarado":
				weather_state = "☀️ Ensolarado"
				weather_forecast = "☀️ Tempo Limpo"
				lap_events.append("☀️ A PISTA SECOU COMPLETAMENTE!")

	# Atualização gradual da barra de Aderência (track_grip) conforme as regras exigidas:
	if rain_intensity > 0.0 or water_level > 15.0:
		# Começou a chover: diminui gradualmente até zerar
		var loss = randf_range(4.0, 9.0) * elapsed_time_factor
		track_grip = max(0.0, track_grip - loss)
	else:
		# Sol ou nublado (sem chuva): aumenta gradualmente até 100%
		var gain = randf_range(1.5, 3.5) * elapsed_time_factor
		track_grip = min(100.0, track_grip + gain)

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
