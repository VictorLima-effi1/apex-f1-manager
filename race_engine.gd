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

# Nível de Água na Pista (%) e Estado do Tempo
var is_wet_race: bool = false
var weather_state: String = "Pista Seca"
var water_level: float = 0.0 # Varia de 0.0% a 100.0%

var quali_phase: String = "Q1"
var quali_time_elapsed: float = 0.0
var quali_durations: Dictionary = {"Q1": 1080.0, "Q2": 900.0, "Q3": 720.0}

# Estados da Pista: "NONE", "YELLOW", "VSC", "SC", "RED_FLAG"
var safety_car_status: String = "NONE"
var safety_car_laps_left: int = 0
var red_flag_active: bool = false
var pending_red_flag_modal: bool = false

var race_logs: Array = []

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

func setup_race(selected_track: Dictionary) -> void:
	track = selected_track
	total_laps = track.get("Voltas", 58)
	current_lap = 0
	is_race_running = false
	is_race_finished = false
	quali_phase = "Q1"
	quali_time_elapsed = 0.0
	safety_car_status = "NONE"
	safety_car_laps_left = 0
	red_flag_active = false
	pending_red_flag_modal = false
	race_logs.clear()
	
	is_wet_race = randf() < track.get("ChanceChuva", 0.20)
	if is_wet_race:
		water_level = randf_range(40.0, 85.0)
		weather_state = "Pista Molhada (" + str(snapped(water_level, 1.0)) + "% água)"
		race_logs.append("🌧️ CLIMA: Pista molhada para a qualificação (" + str(snapped(water_level, 1.0)) + "% de água).")
	else:
		water_level = 0.0
		weather_state = "Pista Seca (0% água)"
		race_logs.append("☀️ CLIMA: Pista seca para a qualificação.")

	race_drivers.clear()
	active_quali_drivers.clear()
	eliminated_drivers.clear()
	full_grid.clear()
	
	for d in Database.drivers:
		if d.get("Equipe", "") != "Free Agent" and d.get("Equipe", "") != "Aposentado":
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
			
			entry["tire_compound"] = _get_ideal_compound_for_water(water_level)
			entry["used_compounds"] = [entry["tire_compound"]]
			entry["tire_wear"] = 100.0
			entry["pit_stops"] = 0
			entry["grid_start_pos"] = 0
			
			race_drivers.append(entry)
			active_quali_drivers.append(entry)

	active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])

func _get_ideal_compound_for_water(w_level: float) -> String:
	if w_level > 55.0:
		return "Wet"
	elif w_level > 15.0:
		return "Inter"
	return "Medium"

func process_quali_tick(delta_sec: float = 1.0) -> Dictionary:
	if is_quali_done():
		return {"finished": true}
		
	var duration_limit = quali_durations.get(quali_phase, 1080.0)
	quali_time_elapsed += delta_sec
	
	for d in active_quali_drivers:
		if d.get("QualiStatus", "") != "Na Pista":
			continue
			
		match d["quali_state"]:
			"Box":
				if d["timer_state"] > 0:
					d["timer_state"] -= delta_sec
				else:
					var driver_skill = d.get("Grau", 80) * 0.4 + d.get("Corrida", 80) * 0.4 + d.get("Overall", 80) * 0.2
					var morale = d.get("Moral", 75)
					var morale_factor = (morale - 50.0) / 100.0
					
					var calculated_hot_time = 78.0 - (driver_skill * 0.1) - morale_factor + randf_range(-0.6, 0.6)
					
					d["pending_lap_time"] = calculated_hot_time
					d["quali_state"] = "Em pista"
					d["timer_state"] = calculated_hot_time * 1.25
					
			"Em pista":
				if d["timer_state"] > 0:
					d["timer_state"] -= delta_sec
				else:
					d["quali_state"] = "Hot Lap"
					d["timer_state"] = d["pending_lap_time"]
					
			"Hot Lap":
				if d["timer_state"] > 0:
					d["timer_state"] -= delta_sec
				else:
					var lap_time = d["pending_lap_time"]
					d["LastLapTime"] = lap_time
					
					if lap_time < d["BestQualiTime"]:
						d["BestQualiTime"] = lap_time
						
					d["quali_state"] = "Em Entrada"
					d["timer_state"] = lap_time * 1.25
					
			"Em Entrada":
				if d["timer_state"] > 0:
					d["timer_state"] -= delta_sec
				else:
					d["quali_state"] = "Box"
					d["timer_state"] = randf_range(120.0, 150.0)
	
	active_quali_drivers.sort_custom(func(a, b):
		var time_a = a["BestQualiTime"]
		var time_b = b["BestQualiTime"]
		if time_a >= 900.0 and time_b >= 900.0:
			return a["Nome"] < b["Nome"]
		if time_a < 900.0 and time_b >= 900.0:
			return true
		if time_a >= 900.0 and time_b < 900.0:
			return false
		if time_a == time_b:
			return a["Nome"] < b["Nome"]
		return time_a < time_b
	)
	
	if quali_time_elapsed >= duration_limit:
		_advance_quali_session()
		
	return {"finished": is_quali_done(), "phase": quali_phase}

func skip_to_end_of_quali_session() -> void:
	if is_quali_done():
		return
		
	var duration_limit = quali_durations.get(quali_phase, 1080.0)
	var current_target_phase = quali_phase
	
	while quali_phase == current_target_phase and not is_quali_done():
		var delta = min(15.0, duration_limit - quali_time_elapsed)
		if delta <= 0.0:
			_advance_quali_session()
			break
		process_quali_tick(delta)

func _advance_quali_session() -> void:
	quali_time_elapsed = 0.0
	if quali_phase == "Q1":
		var cutoff = min(17, active_quali_drivers.size())
		var next_drivers: Array = []
		
		for i in range(active_quali_drivers.size()):
			if i >= cutoff:
				var elim = active_quali_drivers[i]
				elim["QualiStatus"] = "ELIMINADO Q1"
				elim["quali_state"] = "Box"
				eliminated_drivers.append(elim)
			else:
				active_quali_drivers[i]["BestQualiTime"] = 999.0
				active_quali_drivers[i]["LastLapTime"] = 999.0
				active_quali_drivers[i]["quali_state"] = "Box"
				active_quali_drivers[i]["timer_state"] = randf_range(20.0, 60.0)
				next_drivers.append(active_quali_drivers[i])
				
		active_quali_drivers = next_drivers
		active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])
		quali_phase = "Q2"
		race_logs.append("🏁 FIM DO Q1 (18m): 5 pilotos eliminados.")
		
	elif quali_phase == "Q2":
		var cutoff = min(10, active_quali_drivers.size())
		var next_drivers: Array = []
		
		for i in range(active_quali_drivers.size()):
			if i >= cutoff:
				var elim = active_quali_drivers[i]
				elim["QualiStatus"] = "ELIMINADO Q2"
				elim["quali_state"] = "Box"
				eliminated_drivers.append(elim)
			else:
				active_quali_drivers[i]["BestQualiTime"] = 999.0
				active_quali_drivers[i]["LastLapTime"] = 999.0
				active_quali_drivers[i]["quali_state"] = "Box"
				active_quali_drivers[i]["timer_state"] = randf_range(20.0, 60.0)
				next_drivers.append(active_quali_drivers[i])
				
		active_quali_drivers = next_drivers
		active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])
		quali_phase = "Q3"
		race_logs.append("🏁 FIM DO Q2 (15m): 5 pilotos eliminados.")
		
	elif quali_phase == "Q3":
		full_grid.clear()
		for d in active_quali_drivers:
			d["QualiStatus"] = "CLASSIFICADO"
			full_grid.append(d)
			
		for d in eliminated_drivers:
			full_grid.append(d)
			
		full_grid.sort_custom(func(a, b):
			var time_a = a["BestQualiTime"]
			var time_b = b["BestQualiTime"]
			if time_a >= 900.0 and time_b >= 900.0:
				return a["Nome"] < b["Nome"]
			if time_a < 900.0 and time_b >= 900.0:
				return true
			if time_a >= 900.0 and time_b < 900.0:
				return false
			return time_a < time_b
		)
		
		var pos_idx = 1
		for d in full_grid:
			d["grid_start_pos"] = pos_idx
			_initialize_driver_race_strategy(d, pos_idx)
			pos_idx += 1
			
		quali_phase = "FINISHED"
		race_drivers = full_grid.duplicate()
		race_logs.append("🏁 QUALIFICAÇÃO CONCLUÍDA! Grid de largada pronto.")

func _initialize_driver_race_strategy(driver: Dictionary, start_pos: int) -> void:
	var first_compound = _get_ideal_compound_for_water(water_level)
	if first_compound not in ["Wet", "Inter"]:
		var strategy_roll = randf()
		if total_laps >= 60:
			first_compound = "Medium" if strategy_roll < 0.6 else "Soft"
		else:
			first_compound = "Medium" if start_pos <= 10 else "Hard"
			
	driver["tire_compound"] = first_compound
	driver["used_compounds"] = [first_compound]

func process_lap() -> Dictionary:
	if current_lap >= total_laps:
		is_race_finished = true
		return {"finished": true}
		
	if pending_red_flag_modal:
		return {"finished": false, "red_flag": true}

	current_lap += 1
	var lap_events: Array = []
	
	# --- DINÂMICA DE CHUVA E TRILHO SECO (%) ---
	if water_level > 0.0:
		var drying_rate = randf_range(1.5, 3.5)
		water_level = max(0.0, water_level - drying_rate)
		
		if water_level <= 0.0:
			weather_state = "Pista Seca (0% água)"
			lap_events.append("☀️ CLIMA: A pista secou completamente! (0% água)")
		else:
			weather_state = "Pista Molhada (" + str(snapped(water_level, 1.0)) + "% água)"
	else:
		if randf() < track.get("ChanceChuva", 0.20) * 0.1:
			water_level = randf_range(20.0, 60.0)
			weather_state = "Pista Molhada (" + str(snapped(water_level, 1.0)) + "% água)"
			lap_events.append("🌧️ COMEÇOU A CHOVER! Pista com " + str(snapped(water_level, 1.0)) + "% de água.")

	if safety_car_laps_left > 0:
		safety_car_laps_left -= 1
		if safety_car_laps_left <= 0:
			safety_car_status = "NONE"
			lap_events.append("🟢 BANDEIRA VERDE: Pista liberada / SC recolhido.")

	var accident_this_lap = false

	for d in race_drivers:
		if d["Status"] != "Na Pista":
			continue
			
		d["is_in_pit"] = false
			
		var base_wear = 2.8 if d["tire_compound"] == "Soft" else (2.0 if d["tire_compound"] == "Medium" else (1.3 if d["tire_compound"] == "Hard" else 2.2))
		var tire_skill_mod = (100.0 - d.get("Pneus", 80)) * 0.015
		
		if safety_car_status in ["SC", "VSC"]:
			base_wear *= 0.4
			
		var wear = base_wear + tire_skill_mod + randf_range(-0.1, 0.2)
		d["tire_wear"] = max(0.0, d["tire_wear"] - wear)
		
		var ideal_compound = _get_ideal_compound_for_water(water_level)
		var needs_pit = false
		var target_compound = d["tire_compound"]
		var remaining_laps = total_laps - current_lap
		
		# Decisão do Pit pela Janela de Pneu Ideal
		if ideal_compound in ["Wet", "Inter"] and d["tire_compound"] != ideal_compound:
			needs_pit = true
			target_compound = ideal_compound
		elif ideal_compound not in ["Wet", "Inter"] and d["tire_compound"] in ["Wet", "Inter"]:
			needs_pit = true
			target_compound = _select_next_dry_compound(d, remaining_laps)
		elif d["tire_wear"] < 15.0 or (safety_car_status != "NONE" and d["tire_wear"] < 40.0 and remaining_laps > 10):
			needs_pit = true
			target_compound = ideal_compound if ideal_compound in ["Wet", "Inter"] else _select_next_dry_compound(d, remaining_laps)
			
		if needs_pit:
			d["is_in_pit"] = true
			d["pit_stops"] += 1
			d["tire_wear"] = 100.0
			d["tire_compound"] = target_compound
			if not d["used_compounds"].has(target_compound):
				d["used_compounds"].append(target_compound)
				
			# --- ERROS DE PIT STOP BASEADOS NA MORAL ---
			var team_morale = d.get("Moral", 75)
			var error_chance = clamp(0.15 - (team_morale * 0.0012), 0.02, 0.20)
			
			var stop_time = randf_range(2.1, 2.8)
			var pit_error_msg = ""
			
			if randf() < error_chance:
				var extra_time = randf_range(3.0, 6.0)
				stop_time += extra_time
				pit_error_msg = " ⚠️ ERRO NO PIT STOP (+%ss)" % str(snapped(extra_time, 0.1))
				
			var pit_lane_loss = randf_range(20.0, 24.0)
			var total_pit_loss = pit_lane_loss + stop_time
			
			var base_lap = 80.0
			var lap_time = base_lap + total_pit_loss + randf_range(-0.3, 0.3)
			
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			
			var reenter_pos = 1
			for other in race_drivers:
				if other["Status"] == "Na Pista" and other["TempoTotal"] < d["TempoTotal"]:
					reenter_pos += 1
					
			lap_events.append("🛠️ PIT STOP: " + d["Nome"] + " (" + d["Equipe"] + ") colocou " + target_compound + " (" + str(snapped(stop_time, 0.1)) + "s)" + pit_error_msg + " - P" + str(reenter_pos) + ".")
		else:
			var base_lap = 80.0
			var compound_delta = 0.0
			
			# Penalidade pesada por pneu errado para o nível de água
			if water_level > 55.0 and d["tire_compound"] != "Wet":
				compound_delta += 12.0
			elif water_level > 15.0 and water_level <= 55.0 and d["tire_compound"] != "Inter":
				compound_delta += 6.0
			elif water_level <= 15.0 and d["tire_compound"] in ["Wet", "Inter"]:
				compound_delta += 8.0
			else:
				match d["tire_compound"]:
					"Soft": compound_delta = 0.0
					"Medium": compound_delta = 0.5
					"Hard": compound_delta = 1.1
				
			var driver_speed = (d.get("Corrida", 80) * 0.4 + d.get("Grau", 80) * 0.3) * 0.1
			var morale = d.get("Moral", 75)
			var morale_time_modifier = (50.0 - morale) * 0.008
			
			var wear_penalty = (15.0 - d["tire_wear"]) * 0.35 if d["tire_wear"] < 15.0 else (100.0 - d["tire_wear"]) * 0.012
			var lap_time = base_lap + compound_delta - driver_speed + wear_penalty + morale_time_modifier + randf_range(-0.3, 0.3)
			
			if safety_car_status == "SC" or safety_car_status == "VSC":
				lap_time *= 1.60
			elif safety_car_status == "YELLOW":
				lap_time *= 1.20
				
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			
		var morale_val = d.get("Moral", 75)
		var crash_chance = 0.006 if morale_val < 40 else 0.002
			
		if randf() < crash_chance:
			var is_crash = randf() >= 0.6
			d["Status"] = "Abandonou (Acidente)" if is_crash else "Abandonou (Quebra)"
			d["retired_lap"] = current_lap
			d["is_in_pit"] = false
			accident_this_lap = is_crash or accident_this_lap
			lap_events.append("💥 ABANDONO: " + d["Nome"] + " (" + d["Equipe"] + ") fora na volta " + str(current_lap) + ".")

	# --- GERAÇÃO DE SAFETY CAR / VSC / BANDEIRAS ---
	if accident_this_lap and safety_car_status == "NONE":
		var roll = randf()
		if roll < 0.35:
			safety_car_status = "SC"
			safety_car_laps_left = randi_range(2, 3)
			lap_events.append("🚨 SAFETY CAR ENTROU NA PISTA! (2-3 Voltas)")
		elif roll < 0.60:
			safety_car_status = "VSC"
			safety_car_laps_left = randi_range(1, 2)
			lap_events.append("🟡 VIRTUAL SAFETY CAR (VSC) ACIONADO!")
		elif roll < 0.85:
			safety_car_status = "YELLOW"
			safety_car_laps_left = randi_range(1, 2)
			lap_events.append("⚠️ BANDEIRA AMARELA NO SETOR!")
		else:
			safety_car_status = "RED_FLAG"
			red_flag_active = true
			pending_red_flag_modal = true
			lap_events.append("🔴 BANDEIRA VERMELHA! Corrida paralisada.")

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
	if current_lap >= total_laps:
		is_race_finished = true
		
	return {
		"finished": is_race_finished,
		"lap": current_lap,
		"events": lap_events,
		"standings": race_drivers,
		"red_flag": pending_red_flag_modal
	}

# Troca automatizada da IA sob Bandeira Vermelha
func resolve_red_flag_restart(_ignored_user_choice: String = "") -> void:
	pending_red_flag_modal = false
	red_flag_active = false
	safety_car_status = "NONE"
	
	for d in race_drivers:
		if d["Status"] == "Na Pista":
			var choice = _get_ideal_compound_for_water(water_level)
			if choice not in ["Wet", "Inter"]:
				choice = _select_next_dry_compound(d, total_laps - current_lap)
			d["tire_compound"] = choice
			d["tire_wear"] = 100.0
			if not d["used_compounds"].has(choice):
				d["used_compounds"].append(choice)

	var accumulated_start_gap = 0.0
	for i in range(race_drivers.size()):
		if race_drivers[i]["Status"] == "Na Pista":
			race_drivers[i]["TempoTotal"] = accumulated_start_gap
			accumulated_start_gap += 0.200

	race_logs.append("🟢 RELARGADA EM GRID DE LARGADA REALIZADA NA VOLTA " + str(current_lap) + ".")

func _select_next_dry_compound(driver: Dictionary, remaining_laps: int) -> String:
	var used: Array = driver.get("used_compounds", [])
	if remaining_laps <= 16:
		return "Soft"
	elif remaining_laps <= 30:
		return "Medium"
	else:
		return "Hard"
