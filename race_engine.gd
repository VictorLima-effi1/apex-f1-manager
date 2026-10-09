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

var is_wet_race: bool = false
var weather_state: String = "Pista Seca"
var rain_intensity: float = 0.0

var quali_phase: String = "Q1"
var quali_time_elapsed: float = 0.0
var quali_durations: Dictionary = {"Q1": 1080.0, "Q2": 900.0, "Q3": 720.0}

var safety_car_status: String = "NONE"
var safety_car_laps_left: int = 0

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
	race_logs.clear()
	
	is_wet_race = randf() < track.get("ChanceChuva", 0.20)
	if is_wet_race:
		weather_state = "Pista Molhada"
		rain_intensity = randf_range(0.3, 0.7)
		race_logs.append("🌧️ CLIMA: Pista molhada para a sessão de qualificação.")
	else:
		weather_state = "Pista Seca"
		rain_intensity = 0.0
		race_logs.append("☀️ CLIMA: Pista seca para a sessão de qualificação.")

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
			
			entry["tire_compound"] = "Wet" if is_wet_race else "Soft"
			entry["used_compounds"] = [entry["tire_compound"]]
			entry["tire_wear"] = 100.0
			entry["pit_stops"] = 0
			entry["grid_start_pos"] = 0
			
			race_drivers.append(entry)
			active_quali_drivers.append(entry)

	active_quali_drivers.sort_custom(func(a, b): return a["Nome"] < b["Nome"])

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
					
					# Impacto da Moral no Treino Classificatório
					var morale = d.get("Moral", 75)
					var morale_factor = (morale - 50.0) / 100.0 # Varia entre -0.5s e +0.5s
					
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
	if is_wet_race:
		driver["tire_compound"] = "Wet"
		driver["used_compounds"] = ["Wet"]
		driver["planned_strategy"] = ["Wet", "Wet"]
		return

	var strategy_roll = randf()
	if total_laps >= 60:
		if strategy_roll < 0.45:
			driver["planned_strategy"] = ["Soft", "Medium", "Soft"]
		elif strategy_roll < 0.80:
			driver["planned_strategy"] = ["Medium", "Hard"]
		else:
			driver["planned_strategy"] = ["Hard", "Medium", "Soft"]
	else:
		if start_pos <= 10:
			if strategy_roll < 0.60:
				driver["planned_strategy"] = ["Medium", "Hard"]
			elif strategy_roll < 0.85:
				driver["planned_strategy"] = ["Soft", "Hard"]
			else:
				driver["planned_strategy"] = ["Soft", "Medium", "Soft"]
		else:
			if strategy_roll < 0.50:
				driver["planned_strategy"] = ["Hard", "Medium"]
			elif strategy_roll < 0.80:
				driver["planned_strategy"] = ["Medium", "Hard"]
			else:
				driver["planned_strategy"] = ["Hard", "Soft"]

	var first_compound = driver["planned_strategy"][0]
	driver["tire_compound"] = first_compound
	driver["used_compounds"] = [first_compound]

func process_lap() -> Dictionary:
	if current_lap >= total_laps:
		is_race_finished = true
		return {"finished": true}
		
	current_lap += 1
	var lap_events: Array = []
	
	if randf() < 0.04:
		if is_wet_race:
			if randf() < 0.3:
				is_wet_race = false
				weather_state = "Pista Seca"
				lap_events.append("☀️ CLIMA: Pista secou!")
		else:
			if randf() < track.get("ChanceChuva", 0.20):
				is_wet_race = true
				weather_state = "Pista Molhada"
				lap_events.append("🌧️ COMEÇOU A CHOVER! Pista molhada.")

	if safety_car_laps_left > 0:
		safety_car_laps_left -= 1
		if safety_car_laps_left <= 0:
			safety_car_status = "NONE"
			lap_events.append("🟢 BANDEIRA VERDE: Safety Car recolhido.")

	for d in race_drivers:
		if d["Status"] != "Na Pista":
			continue
			
		d["is_in_pit"] = false
			
		var base_wear = 2.8 if d["tire_compound"] == "Soft" else (2.0 if d["tire_compound"] == "Medium" else (1.3 if d["tire_compound"] == "Hard" else 2.2))
		var tire_skill_mod = (100.0 - d.get("Pneus", 80)) * 0.015
		var wear = base_wear + tire_skill_mod + randf_range(-0.1, 0.2)
		d["tire_wear"] = max(0.0, d["tire_wear"] - wear)
		
		var needs_pit = false
		var target_compound = d["tire_compound"]
		var remaining_laps = total_laps - current_lap
		
		if is_wet_race and d["tire_compound"] != "Wet":
			needs_pit = true
			target_compound = "Wet"
		elif not is_wet_race and d["tire_compound"] == "Wet":
			needs_pit = true
			target_compound = _select_next_dry_compound(d, remaining_laps)
		elif d["tire_wear"] < 15.0 or (safety_car_status != "NONE" and d["tire_wear"] < 40.0 and remaining_laps > 10):
			needs_pit = true
			target_compound = _select_next_dry_compound(d, remaining_laps)
			
		if needs_pit:
			d["is_in_pit"] = true
			d["pit_stops"] += 1
			d["tire_wear"] = 100.0
			d["tire_compound"] = target_compound
			if not d["used_compounds"].has(target_compound):
				d["used_compounds"].append(target_compound)
				
			var pit_lane_loss = randf_range(20.0, 26.0)
			var stop_time = randf_range(2.1, 3.8)
			var total_pit_loss = pit_lane_loss + stop_time
			
			var base_lap = 80.0
			var lap_time = base_lap + total_pit_loss + randf_range(-0.3, 0.3)
			
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			
			var reenter_pos = 1
			for other in race_drivers:
				if other["Status"] == "Na Pista" and other["TempoTotal"] < d["TempoTotal"]:
					reenter_pos += 1
					
			lap_events.append("🛠️ PIT STOP: " + d["Nome"] + " (" + d["Equipe"] + ") colocou pneus " + target_compound + " (" + str(snapped(stop_time, 0.1)) + "s) - Voltou em P" + str(reenter_pos) + ".")
		else:
			var base_lap = 80.0
			var compound_delta = 0.0
			match d["tire_compound"]:
				"Soft": compound_delta = 0.0
				"Medium": compound_delta = 0.5
				"Hard": compound_delta = 1.1
				"Wet": compound_delta = 8.0
				
			var driver_speed = (d.get("Corrida", 80) * 0.4 + d.get("Grau", 80) * 0.3) * 0.1
			
			# --- CÁLCULO DO IMPACTO DA MORAL NO RITMO DA CORRIDA ---
			var morale = d.get("Moral", 75)
			var morale_time_modifier = (50.0 - morale) * 0.008 # Moral baixa adiciona tempo (+0.2s por volta se moral for 25)
			
			var wear_penalty = 0.0
			if d["tire_wear"] < 15.0:
				wear_penalty = (15.0 - d["tire_wear"]) * 0.35
			else:
				wear_penalty = (100.0 - d["tire_wear"]) * 0.012
			
			var lap_time = base_lap + compound_delta - driver_speed + wear_penalty + morale_time_modifier + randf_range(-0.3, 0.3)
			if safety_car_status == "SC":
				lap_time += 15.0
			elif safety_car_status == "VSC":
				lap_time += 7.0
				
			d["TempoTotal"] += lap_time
			d["LastLapTime"] = lap_time
			
		# --- CHANCE DE ABANDONO/ERRO POR MORAL BAIXA ---
		var morale_val = d.get("Moral", 75)
		var crash_chance = 0.002
		if morale_val < 40:
			crash_chance = 0.006 # Moral crítica aumenta em 3x a chance de erro/abandono na volta
			
		if randf() < crash_chance:
			d["Status"] = "Abandonou (Quebra)" if randf() < 0.6 else "Abandonou (Acidente)"
			d["retired_lap"] = current_lap
			d["is_in_pit"] = false
			lap_events.append("💥 ABANDONO: " + d["Nome"] + " (" + d["Equipe"] + ") fora da corrida na volta " + str(current_lap) + ".")
			
			if safety_car_status == "NONE" and randf() < 0.4:
				safety_car_status = "SC" if randf() < 0.5 else "VSC"
				safety_car_laps_left = randi_range(2, 4)
				lap_events.append("⚠️ " + safety_car_status + " ENTROU NA PISTA!")

	race_drivers.sort_custom(func(a, b):
		var a_active = a["Status"] == "Na Pista"
		var b_active = b["Status"] == "Na Pista"
		
		if a_active and not b_active:
			return true
		if not a_active and b_active:
			return false
		if a_active and b_active:
			return a["TempoTotal"] < b["TempoTotal"]
		
		var a_ret = int(a.get("retired_lap", 0))
		var b_ret = int(b.get("retired_lap", 0))
		if a_ret != b_ret:
			return a_ret > b_ret
		return a["TempoTotal"] < b["TempoTotal"]
	)
	
	race_logs.append_array(lap_events)
	if current_lap >= total_laps:
		is_race_finished = true
		
	return {
		"finished": is_race_finished,
		"lap": current_lap,
		"events": lap_events,
		"standings": race_drivers
	}

func _select_next_dry_compound(driver: Dictionary, remaining_laps: int) -> String:
	var used: Array = driver.get("used_compounds", [])
	var planned: Array = driver.get("planned_strategy", [])
	var current_stop = driver["pit_stops"]
	
	if current_stop < planned.size():
		var candidate = planned[current_stop]
		if not used.has(candidate) or remaining_laps < 15:
			return candidate

	if used.size() == 1:
		var mandatory_options = []
		for c in ["Soft", "Medium", "Hard"]:
			if not used.has(c):
				mandatory_options.append(c)
				
		if remaining_laps <= 15:
			return "Soft" if mandatory_options.has("Soft") else mandatory_options[0]
		elif remaining_laps <= 28:
			return "Medium" if mandatory_options.has("Medium") else mandatory_options[0]
		else:
			return "Hard" if mandatory_options.has("Hard") else mandatory_options[0]
			
	if remaining_laps <= 16:
		return "Soft"
	elif remaining_laps <= 30:
		return "Medium"
	else:
		return "Hard"
