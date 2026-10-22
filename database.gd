extends Node

var current_year: int = 2026
var current_gp: int = 1
var current_view: String = "dashboard"
var race_finished: bool = false
var active_engine: RaceEngine = null
var constructors_points_history: Array = [] # Estrutura: [{"gp": 1, "points": {"McLaren": 25, "Ferrari": 18, ...}}]

# Variáveis Globais de Configuração
var ui_scale: float = 1.0
var aspect_index: int = 0
var window_mode_index: int = 1

# --- TETO ORÇAMENTÁRIO (COST CAP) ---
const COST_CAP_LIMIT: float = 135_000_000.0 # $135 Milhões base por temporada
const UPGRADE_COST: float = 8_500_000.0       # Custo por pacote de evolução (+1 Power Index)

var user_team: String = "McLaren" # Equipe selecionada pelo jogador
var team_season_expenses: Dictionary = {}
var team_budget_caps: Dictionary = {}

# --- SISTEMA DE MÚLTIPLOS SLOTS DE SAVE (1, 2 e 3) ---
const MAX_SAVE_SLOTS: int = 3
var current_slot: int = 1

@warning_ignore("shadowed_global_identifier")
const TracksData = preload("res://data/tracks_data.gd")
@warning_ignore("shadowed_global_identifier")
const TeamsData = preload("res://data/teams_data.gd")

var tracks: Array = []
var teams: Array = []
var drivers: Array = []
var news_feed: Array = []
var race_history: Array = [] 
var champions_history: Array = [] 
var full_season_archive: Dictionary = {}

var player_finances: Dictionary = {
	"budget": 45000000.0,
	"budget_cap_used": 82500000.0,
	"budget_cap_limit": 135000000.0,
	"projected_prize": 32000000.0
}

var dashboard_layout: Dictionary = {
	"drivers_panel": {"pos": Vector2(20, 80), "size": Vector2(430, 480)},
	"news_panel": {"pos": Vector2(20, 570), "size": Vector2(710, 140)},
	"teams_panel": {"pos": Vector2(460, 80), "size": Vector2(280, 270)},
	"market_panel": {"pos": Vector2(460, 360), "size": Vector2(280, 200)},
	"cal_panel": {"pos": Vector2(750, 80), "size": Vector2(300, 150)},
	"track_info_panel": {"pos": Vector2(750, 240), "size": Vector2(300, 150)},
	"tech_power_panel": {"pos": Vector2(750, 400), "size": Vector2(300, 310)}
}

var transfer_history: Array = [
	{"temporada": "2026", "detalhe": "Lewis Hamilton assina com a Ferrari por 3 anos.", "tipo": "Transferência"},
	{"temporada": "2026", "detalhe": "Carlos Sainz fecha acordo com a Williams.", "tipo": "Transferência"},
	{"temporada": "2026", "detalhe": "Gabriel Bortoleto promovido a titular na Audi.", "tipo": "Estreia"}
]

const F1_POINTS = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

func _ready() -> void:
	load_drivers_from_json()
	init_season_budget_cap()
	if tracks.is_empty():
		tracks = TracksData.get_initial_tracks()
	if teams.is_empty():
		teams = TeamsData.get_initial_teams()
	ensure_full_grid()

func init_season_budget_cap() -> void:
	team_season_expenses.clear()
	for team in teams:
		var team_name = str(team.get("Nome", ""))
		team_season_expenses[team_name] = 0.0
		if not team_budget_caps.has(team_name):
			var last_rank = int(team.get("LastSeasonRank", 5))
			var bonus_ratio = float(last_rank - 1) / float(max(1, teams.size() - 1))
			var bonus_amount = 20_000_000.0 * bonus_ratio
			team_budget_caps[team_name] = COST_CAP_LIMIT + bonus_amount

func get_team_budget_cap(team_name: String) -> float:
	return team_budget_caps.get(team_name, COST_CAP_LIMIT)

func purchase_team_upgrade(team_name: String) -> bool:
	var current_expense = team_season_expenses.get(team_name, 0.0)
	var max_cap = get_team_budget_cap(team_name)
	
	if current_expense + UPGRADE_COST > max_cap:
		return false
		
	team_season_expenses[team_name] = current_expense + UPGRADE_COST
	
	var team = _get_team_by_name(team_name)
	var last_rank = int(team.get("LastSeasonRank", 5))
	var gain = randi_range(1, 2) if last_rank <= 3 else randi_range(3, 4)
	
	team["PowerIndex"] = team.get("PowerIndex", 75.0) + float(gain)
	return true

func process_ai_team_upgrades() -> void:
	for t in teams:
		if not bool(t.get("Ativa", true)):
			continue
			
		var team_name = str(t.get("Nome", ""))
		var current_expense = team_season_expenses.get(team_name, 0.0)
		var max_cap = get_team_budget_cap(team_name)
		var remaining = max_cap - current_expense
		
		if remaining < UPGRADE_COST:
			continue
			
		var gp_progress = float(current_gp) / float(max(1, tracks.size()))
		var budget_ratio = remaining / max_cap
		
		var buy_chance = 0.60 if budget_ratio > (1.0 - gp_progress) else 0.35
		
		if randf() > buy_chance:
			continue
			
		var last_rank = int(t.get("LastSeasonRank", 5))
		var gain = randi_range(1, 2) if last_rank <= 3 else randi_range(3, 4)
		
		var available_focuses = []
		if t["Motor"] < 99: available_focuses.append(0)
		if t["Aero"] < 99: available_focuses.append(1)
		if t["Chassi"] < 99: available_focuses.append(2)
		if t["Confiabilidade"] < 99: available_focuses.append(3)
		
		if available_focuses.size() > 0:
			var focus = available_focuses[randi() % available_focuses.size()]
			var upgrade_type_str = ""
			
			if focus == 0:
				t["Motor"] = min(99, t["Motor"] + gain)
				upgrade_type_str = "Unidade de Potência (+%d%%)" % gain
			elif focus == 1:
				t["Aero"] = min(99, t["Aero"] + gain)
				upgrade_type_str = "Aerodinâmica (+%d%%)" % gain
			elif focus == 2:
				t["Chassi"] = min(99, t["Chassi"] + gain)
				upgrade_type_str = "Chassi (+%d%%)" % gain
			elif focus == 3:
				t["Confiabilidade"] = min(99, t["Confiabilidade"] + gain)
				upgrade_type_str = "Confiabilidade (+%d%%)" % gain

			if not upgrade_type_str.is_empty():
				team_season_expenses[team_name] = current_expense + UPGRADE_COST
				add_news("🛠️ UPGRADE (%s): %s | Gastos: $%sM / $%sM" % [
					team_name, 
					upgrade_type_str, 
					str(snapped((current_expense + UPGRADE_COST) / 1000000.0, 0.1)),
					str(snapped(max_cap / 1000000.0, 0.1))
				])

func _recalculate_team_handicaps_and_reset_caps() -> void:
	var sorted_teams = teams.duplicate()
	sorted_teams.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
	
	var total_teams = sorted_teams.size()
	
	for i in range(total_teams):
		var team_name = str(sorted_teams[i].get("Nome", ""))
		var rank = i + 1
		
		var real_team = _get_team_by_name(team_name)
		if not real_team.is_empty():
			real_team["LastSeasonRank"] = rank
		
		var bonus_ratio = float(i) / float(max(1, total_teams - 1))
		var bonus_amount = 20_000_000.0 * bonus_ratio
		
		team_budget_caps[team_name] = COST_CAP_LIMIT + bonus_amount
		
	team_season_expenses.clear()
	for t in teams:
		team_season_expenses[t["Nome"]] = 0.0

# --- REGRA DE OSCILAÇÃO ANUAL DE DESEMPENHO (-5% a +2%) ---
func _apply_annual_team_performance_shift() -> void:
	for t in teams:
		for param in ["Motor", "Aero", "Chassi", "Confiabilidade"]:
			var current_val = int(t.get(param, 75))
			var shift = randi_range(-5, 2)
			var new_val = clamp(current_val + shift, 50, 99)
			t[param] = new_val
			
	add_news_event("🏎️ DESENVOLVIMENTO DE INVERNO: As equipes reajustaram seus carros para o novo ano (-5% a +2%).")

func apply_race_points(standings: Array) -> void:
	for i in range(min(10, standings.size())):
		var driver_data = standings[i]
		if driver_data.get("dnf", false) or driver_data.get("abandonou", false):
			continue
			
		var pts = F1_POINTS[i]
		var driver_name = str(driver_data.get("Nome", ""))
		var team_name = str(driver_data.get("Equipe", ""))
		
		for d in drivers:
			if str(d.get("Nome", "")).strip_edges().to_lower() == driver_name.strip_edges().to_lower():
				d["Pontos"] = int(d.get("Pontos", 0)) + pts
				break
				
		for t in teams:
			if str(t.get("Nome", "")).strip_edges().to_lower() == team_name.strip_edges().to_lower():
				t["Pontos"] = int(t.get("Pontos", 0)) + pts
				break

func load_drivers_from_json() -> void:
	var path = "res://drivers_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK:
				drivers.clear()
				var loaded_data = json.get_data()
				if loaded_data is Array:
					drivers = loaded_data
				sanitize_unique_drivers()
				return
	print_debug("Aviso: drivers_data.json não encontrado ou inválido!")

func sanitize_unique_drivers() -> void:
	if drivers == null or drivers.size() == 0:
		return
		
	var unique_list: Array = []
	var seen_names: Dictionary = {}
	
	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", ""))).strip_edges()
		if d_name.is_empty():
			continue
			
		var key = d_name.to_lower()
		if not seen_names.has(key):
			seen_names[key] = true
			unique_list.append(d)
			
	drivers = unique_list

func ensure_full_grid() -> void:
	for t in teams:
		var t_name = str(t.get("Nome", ""))
		var t_drivers = get_team_drivers(t_name)
		while t_drivers.size() < 2:
			_auto_fill_team_seat(t_name)
			t_drivers = get_team_drivers(t_name)

func get_team_power_index(team_name: String) -> Dictionary:
	var team = _get_team_by_name(team_name)
	if team.is_empty():
		return {"aero": 80.0, "engine": 80.0, "chassis": 80.0, "overall": 80.0}
		
	var motor = float(team.get("Motor", 80))
	var aero = float(team.get("Aero", 80))
	var chassi = float(team.get("Chassi", 80))
	var overall = (motor + aero + chassi) / 3.0
	
	return {
		"aero": aero,
		"engine": motor,
		"chassis": chassi,
		"overall": overall
	}

func add_news(msg: String) -> void:
	news_feed.push_front("[" + str(current_year) + " - GP " + str(current_gp) + "] " + msg)
	if news_feed.size() > 15:
		news_feed.pop_back()

func add_news_event(text: String) -> void:
	add_news(text)

func _check_is_dnf(res: Dictionary) -> bool:
	if bool(res.get("dnf", false)) or bool(res.get("is_dnf", false)) or bool(res.get("abandonou", false)) or bool(res.get("retired", false)):
		return true
	if res.has("is_active") and not bool(res.get("is_active", true)):
		return true
	if res.has("active") and not bool(res.get("active", true)):
		return true

	var status_str = str(res.get("Status", res.get("status", ""))).to_lower().strip_edges()
	if status_str.is_empty():
		return false

	var dnf_keywords = [
		"abandonou", "dnf", "retired", "out", "quebra", "batida", 
		"colisao", "colisão", "acidente", "motor", "cambio", "câmbio", 
		"freio", "suspensao", "suspensão", "rodou", "dano"
	]

	for kw in dnf_keywords:
		if status_str.contains(kw):
			return true

	return false

func process_post_race_morale_and_respect(standings: Array) -> void:
	for d in standings:
		var driver_name = str(d.get("Nome", d.get("nome", "")))
		var pos = int(d.get("pos", 22))
		var is_dnf = bool(d.get("dnf", false)) or bool(d.get("abandonou", false))
		
		var real_driver = _get_driver_by_name(driver_name)
		if real_driver.is_empty():
			continue
			
		var current_morale = float(real_driver.get("Moral", 75.0))
		var morale_change = 0.0
		var team_name = str(real_driver.get("Equipe", ""))
		
		if is_dnf:
			morale_change -= 3.0
			real_driver["corridas_sem_dnf_ajuda"] = 0
			real_driver["corridas_sem_abandonar"] = 0
			_apply_dnf_financial_penalty(team_name)
		else:
			var streak_ajuda = int(real_driver.get("corridas_sem_dnf_ajuda", 0)) + 1
			real_driver["corridas_sem_dnf_ajuda"] = streak_ajuda
			
			if current_morale <= 30.0 or bool(real_driver.get("ajuda_ativa", false)):
				real_driver["ajuda_ativa"] = true
				
				if streak_ajuda >= 2:
					morale_change += 8.0
					real_driver["bonus_temporario_laps"] = 2
					real_driver["ajuda_ativa"] = false
					real_driver["corridas_sem_dnf_ajuda"] = 0
					add_news_event("💪 SUPERAÇÃO: %s superou a fase ruim com 2 corridas limpas e ganhou um impulso de confiança!" % driver_name)

		var temp_bonus = int(real_driver.get("bonus_temporario_laps", 0))
		if temp_bonus > 0:
			real_driver["bonus_temporario_laps"] = temp_bonus - 1
		
		var final_morale = clampf(current_morale + morale_change, 0.0, 100.0)
		real_driver["Moral"] = final_morale
		
		if final_morale <= 0.0 and team_name != "Free Agent" and team_name != "Aposentado":
			fire_driver(team_name, driver_name)
			continue
			
		if not is_dnf:
			var target_max_pos = _get_team_target_position(team_name)
			if pos <= target_max_pos - 2:
				morale_change += 3.0
			elif pos <= target_max_pos:
				morale_change += 1.0
			elif pos > target_max_pos + 3:
				morale_change -= 2.0
				
		var teammate_pos = _get_teammate_finish_position(standings, team_name, driver_name)
		if teammate_pos < 99:
			if pos < teammate_pos:
				morale_change += 1.0
			elif pos > teammate_pos:
				morale_change -= 1.0
				
		var new_morale = clampf(current_morale + morale_change, 0.0, 100.0)
		real_driver["Moral"] = new_morale

func _get_team_target_position(team_name: String) -> int:
	var team = _get_team_by_name(team_name)
	var overall = float(team.get("Motor", 80) + team.get("Aero", 80) + team.get("Chassi", 80)) / 3.0
	
	if overall >= 88.0: return 6
	elif overall >= 80.0: return 12
	return 18

func _get_teammate_finish_position(standings: Array, team_name: String, driver_name: String) -> int:
	for d in standings:
		var t = str(d.get("Equipe", d.get("equipe", "")))
		var n = str(d.get("Nome", d.get("nome", "")))
		if t.strip_edges().to_lower() == team_name.strip_edges().to_lower() and n.strip_edges().to_lower() != driver_name.strip_edges().to_lower():
			return int(d.get("pos", 99))
	return 99

func _update_driver_stats_after_race(driver: Dictionary, grid_start_pos: int, race_finish_pos: int, is_dnf: bool) -> void:
	if is_dnf:
		driver["DNFsAno"] = int(driver.get("DNFsAno", 0)) + 1
		driver["SequenciaPontos"] = 0
	else:
		var pos_diff = grid_start_pos - race_finish_pos
		if pos_diff > 0:
			driver["PosicoesGanhaAno"] = int(driver.get("PosicoesGanhaAno", 0)) + pos_diff
		elif pos_diff < 0:
			driver["PosicoesPerdidasAno"] = int(driver.get("PosicoesPerdidasAno", 0)) + abs(pos_diff)

		if race_finish_pos <= 10:
			driver["SequenciaPontos"] = int(driver.get("SequenciaPontos", 0)) + 1
		else:
			driver["SequenciaPontos"] = 0

func simulate_current_gp_fast() -> void:
	ensure_full_grid()
	if current_gp > tracks.size():
		return
		
	var engine = RaceEngine.new()
	var current_track = tracks[current_gp - 1]
	
	if engine.has_method("setup_race"):
		engine.setup_race(current_track)
	
	if engine.has_method("skip_to_end_of_quali_session"):
		engine.skip_to_end_of_quali_session()
	
	var grid_positions: Dictionary = {}
	if engine.get("race_drivers") != null and engine.race_drivers is Array:
		for idx in range(engine.race_drivers.size()):
			var d_name = engine.race_drivers[idx].get("Nome", engine.race_drivers[idx].get("nome", ""))
			grid_positions[d_name] = idx + 1
	
	var total_laps = int(current_track.get("Voltas", 70))
	var safety_counter = 0
	var max_iterations = total_laps + 10
	
	while not _is_engine_done(engine) and safety_counter < max_iterations:
		if engine.has_method("process_lap"):
			engine.process_lap()
		safety_counter += 1
		
	var results = engine.race_drivers if engine.get("race_drivers") != null else []
	for i in range(results.size()):
		results[i]["pos"] = i + 1
		var d_name = results[i].get("Nome", results[i].get("nome", ""))
		results[i]["grid_pos"] = grid_positions.get(d_name, i + 1)
		
		var is_dnf = _check_is_dnf(results[i])
		results[i]["dnf"] = is_dnf
		results[i]["abandonou"] = is_dnf
		
		var db_driver = _get_driver_by_name(d_name)
		if not db_driver.is_empty():
			if is_dnf:
				db_driver["DNFsAno"] = int(db_driver.get("DNFsAno", 0)) + 1
			else:
				if i == 0:
					db_driver["VitoriasAno"] = int(db_driver.get("VitoriasAno", 0)) + 1
				if i < 3:
					db_driver["PodiosAno"] = int(db_driver.get("PodiosAno", 0)) + 1
				
				_update_driver_stats_after_race(db_driver, int(results[i]["grid_pos"]), i + 1, false)

	if results.size() > 0:
		apply_race_points(results)
		record_gp_constructors_snapshot()
		process_post_race_morale_and_respect(results)
		process_ai_team_upgrades()
		
		var winner_name = results[0].get("Nome", results[0].get("nome", "-"))
		var winner_team = results[0].get("Equipe", results[0].get("equipe", "-"))
		var second_name = results[1].get("Nome", results[1].get("nome", "-")) if results.size() > 1 else "-"
		var third_name = results[2].get("Nome", results[2].get("nome", "-")) if results.size() > 2 else "-"
		
		record_gp_winner(current_gp - 1, winner_name, winner_team)
		
		race_history.append({
			"gp_num": current_gp,
			"gp_index": current_gp,
			"track": current_track["Nome"],
			"winner": winner_name,
			"second": second_name,
			"third": third_name
		})
	
	if current_gp == 12:
		_process_mid_season_renewals()
		
	current_gp += 1
	
	if engine is Node:
		engine.free()

func record_gp_constructors_snapshot() -> void:
	var snapshot: Dictionary = {}
	for t in teams:
		snapshot[str(t.get("Nome", ""))] = int(t.get("Pontos", 0))
		
	constructors_points_history.append({
		"gp": current_gp,
		"points": snapshot
	})

func _is_engine_done(engine) -> bool:
	if engine == null: return true
	if engine.has_method("is_finished"): return engine.is_finished()
	return str(engine.get("race_state")).to_upper() == "FINISHED" or str(engine.get("race_state")).to_upper() == "RED_FLAG"

func _reset_team_development_cycle() -> void:
	for t in teams:
		t["Motor"] = randi_range(70, 88)
		t["Aero"] = randi_range(70, 88)
		t["Chassi"] = randi_range(70, 88)
		t["Confiabilidade"] = randi_range(70, 88)
		
	add_news_event("⚙️ NOVO REGULAMENTO TÉCNICO! O desenvolvimento das equipes foi resetado para o novo ciclo!")

func can_team_sign_driver(team_name: String, driver_power_index: float) -> bool:
	var team = _get_team_by_name(team_name)
	var respect = team.get("Respeito", 50)
	if driver_power_index >= 90.0 and respect < 75: return false
	if driver_power_index >= 80.0 and respect < 50: return false
	return true

func is_driver_interested_in_team(driver_name: String, target_team_name: String) -> bool:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 50)
	var target_power = get_team_power_index(target_team_name)["overall"]
	if morale > 80 and target_power < 75.0: return false
	return true

func calculate_contract_offer_years(driver_name: String, team_name: String) -> int:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 75)
	var team = _get_team_by_name(team_name)
	var respect = team.get("Respeito", 50)
	
	if morale >= 85 and respect >= 70: return randi_range(4, 6)
	elif morale >= 70: return randi_range(2, 3)
	elif morale >= 50: return 1
	else: return 0

func fire_driver(team_name: String, driver_name: String) -> void:
	var driver = _get_driver_by_name(driver_name)
	if not driver.is_empty():
		driver["Equipe"] = "Free Agent"
		driver["AnosContrato"] = 0
		driver["Moral"] = 50.0
		
		var fired_by: Array = driver.get("demitido_por_equipes", [])
		if not fired_by.has(team_name):
			fired_by.append(team_name)
		driver["demitido_por_equipes"] = fired_by
		
		log_transfer_event("🚨 DEMISSÃO: " + driver_name + " foi demitido da " + team_name + " por baixo desempenho!", "Demissão")

	_auto_fill_team_seat(team_name)

func driver_resigns(driver_name: String) -> void:
	var driver = _get_driver_by_name(driver_name)
	if not driver.is_empty():
		var team_name = str(driver.get("Equipe", ""))
		if team_name != "Free Agent" and team_name != "Aposentado":
			driver["Equipe"] = "Free Agent"
			driver["AnosContrato"] = 0
			driver["Moral"] = 40.0
			
			log_transfer_event("🚨 RESCISÃO: " + driver_name + " pediu demissão da " + team_name + " por insatisfação com a equipe!", "Rescisão")
			
			_auto_fill_team_seat(team_name)

func _auto_fill_team_seat(team_name: String) -> void:
	var current_drivers = get_team_drivers(team_name)
	if current_drivers.size() >= 2:
		return

	var free_agents: Array = []
	for d in drivers:
		if str(d.get("Equipe", "")).strip_edges().to_lower() == "free agent":
			var fired_by: Array = d.get("demitido_por_equipes", [])
			if not fired_by.has(team_name):
				free_agents.append(d)
				
	free_agents.sort_custom(func(a, b): return int(a.get("Overall", 0)) > int(b.get("Overall", 0)))
	
	if free_agents.size() > 0:
		var candidate = free_agents[0]
		candidate["Equipe"] = team_name
		candidate["AnosContrato"] = randi_range(2, 3)
		candidate["Moral"] = 75.0
		candidate["seasons_without_contract"] = 0
		log_transfer_event("✍️ REPOSIÇÃO: " + team_name + " contratou " + str(candidate["Nome"]) + " por " + str(candidate["AnosContrato"]) + " ano(s)!", "Contratação")
		
		_auto_fill_team_seat(team_name)
		return

	var rookie_name = "Novato " + team_name.substr(0, 3).to_upper() + " " + str(randi_range(10, 99))
	var ovr = randi_range(70, 76)
	add_new_driver(rookie_name, randi_range(18, 21), ovr, ovr, ovr, ovr, ovr, ovr, team_name)
	log_transfer_event("🌟 PROMOÇÃO: " + team_name + " promoveu o jovem " + rookie_name + " da academia de pilotos!", "Contratação")

func get_team_drivers(team_name: String) -> Array:
	var list: Array = []
	var target = team_name.strip_edges().to_lower()
	for d in drivers:
		var eq = str(d.get("Equipe", "")).strip_edges().to_lower()
		if eq == target:
			list.append(d)
	return list

func log_transfer_event(detail: String, type_str: String = "Transferência") -> void:
	var entry = {
		"ano": current_year,
		"gp_num": current_gp,
		"temporada": str(current_year),
		"detalhe": detail,
		"tipo": type_str
	}
	
	if "transfer_history" in self:
		transfer_history.push_front(entry)
		
	add_news("[%d - GP %d] %s" % [current_year, current_gp, detail])

func _process_mid_season_renewals() -> void:
	for d in drivers:
		var eq = str(d.get("Equipe", ""))
		if eq == "Free Agent" or eq == "Aposentado" or eq.is_empty():
			continue
			
		var yrs = int(d.get("AnosContrato", 1))
		var morale = float(d.get("Moral", 75.0))
		
		if yrs <= 1:
			var team_info = get_team_power_index(eq)
			var team_power = team_info.get("overall", 75.0)
			var driver_ovr = float(d.get("Overall", 75))
			
			if driver_ovr >= 85 and team_power < 78.0 and morale < 60:
				add_news("📝 " + str(d["Nome"]) + " recusou a proposta de renovação com a " + eq + " e buscará nova equipe ao fim da temporada!")
				continue
				
			if morale >= 50.0:
				var new_years = randi_range(2, 4)
				d["AnosContrato"] = new_years
				log_transfer_event("✍️ RENOVAÇÃO: " + str(d["Nome"]) + " renovou seu contrato com a " + eq + " por mais " + str(new_years) + " ano(s)!", "Renovação")

func end_season_and_advance_year() -> void:
	full_season_archive[current_year] = race_history.duplicate(true)
	sanitize_unique_drivers()
	
	var sorted_d = drivers.duplicate()
	sorted_d.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
	
	if sorted_d.size() > 0:
		var champ = sorted_d[0]
		champ["Titulos"] = champ.get("Titulos", 0) + 1
		
		champions_history.append({
			"ano": current_year,
			"piloto": champ.get("Nome", "Piloto"),
			"equipe": champ.get("Equipe", "Equipe"),
			"pontos": champ.get("Pontos", 0)
		})
	
	current_year += 1
	current_gp = 1
	race_history.clear()
	
	if "transfer_history" in self:
		transfer_history.clear()
	
	_recalculate_team_handicaps_and_reset_caps()
	
	# Aplica a oscilação anual (-5% a +2%) ou reset por regulamento
	if (current_year - 2026) % 4 == 0:
		_reset_team_development_cycle()
	else:
		_apply_annual_team_performance_shift()
	
	_process_driver_evolution()
	
	for d in drivers:
		var eq = str(d.get("Equipe", ""))
		if eq != "Free Agent" and eq != "Aposentado":
			var yrs = int(d.get("AnosContrato", 1))
			d["AnosContrato"] = max(0, yrs - 1)

		d["Pontos"] = 0
		d["VitoriasAno"] = 0
		d["PodiosAno"] = 0
		d["DNFsAno"] = 0
		d["SequenciaPontos"] = 0
		d["PosicoesGanhaAno"] = 0
		d["PosicoesPerdidasAno"] = 0
		if d.has("demitido_por_equipes"):
			d["demitido_por_equipes"].clear()
		
	for t in teams:
		t["Pontos"] = 0
		
	_process_ai_transfer_market()
	ensure_full_grid()
	
	var last_champ_name = champions_history.back()["piloto"] if champions_history.size() > 0 else "Campeão"
	add_news_event("🏆 TEMPORADA %d INICIADA! As equipes chegam para o novo ano após o título de %s!" % [current_year, last_champ_name])

func _process_driver_evolution() -> void:
	for d in drivers:
		var current_team = str(d.get("Equipe", ""))
		
		if current_team == "Aposentado" or bool(d.get("Aposentado", false)):
			continue
			
		var age = int(d.get("Idade", 20)) + 1
		d["Idade"] = age
		var team_name = str(d.get("Equipe", "Free Agent"))
		var ovr = int(d.get("Overall", 75))
		
		var retirement_chance: float = 0.02
		if age > 30:
			retirement_chance += (age - 30) * 0.05
			
		if team_name == "Free Agent" and age >= 34:
			retirement_chance += 0.20
			
		if (randf() < retirement_chance and age >= 30) or age >= 45:
			d["Equipe"] = "Aposentado"
			d["Aposentado"] = true
			d["AnosContrato"] = 0
			log_transfer_event("🏁 APOSENTADORIA: %s anunciou sua aposentadoria aos %d anos!" % [d["Nome"], age], "Aposentadoria")
			
			if team_name != "Free Agent" and team_name != "Aposentado" and not team_name.is_empty():
				_auto_fill_team_seat(team_name)
			continue
			
		if age <= 24:
			d["Overall"] = min(99, ovr + randi_range(1, 3))
		elif age >= 36:
			var drop = randi_range(2, 4)
			d["Overall"] = max(50, ovr - drop)

func _process_ai_transfer_market() -> void:
	for t in teams:
		t["Ativa"] = true

	for t in teams:
		var team_name = str(t.get("Nome", ""))
		var active_team_drivers = []
		
		for d in drivers:
			if str(d.get("Equipe", "")).strip_edges().to_lower() == team_name.strip_edges().to_lower():
				if int(d.get("AnosContrato", 0)) <= 0:
					add_news("💼 Contrato de " + str(d.get("Nome", "")) + " com a " + team_name + " expirou.")
					d["Equipe"] = "Free Agent"
				else:
					active_team_drivers.append(d)
					
		while active_team_drivers.size() < 2:
			var best_candidate = null
			var highest_overall = -1
			for d in drivers:
				if str(d.get("Equipe", "")).strip_edges().to_lower() == "free agent" and int(d.get("Overall", 0)) > highest_overall:
					highest_overall = int(d.get("Overall", 0))
					best_candidate = d
					
			if best_candidate != null:
				best_candidate["Equipe"] = team_name
				best_candidate["AnosContrato"] = randi_range(2, 3)
				best_candidate["Moral"] = 75.0
				active_team_drivers.append(best_candidate)
				log_transfer_event("✍️ " + team_name + " contratou " + str(best_candidate.get("Nome", "")) + " por " + str(best_candidate["AnosContrato"]) + " ano(s)!", "Contratação")
			else:
				var new_promoted_name = "Novato " + team_name.substr(0, 3).to_upper() + " " + str(randi_range(10, 99))
				var ovr_tmp = randi_range(68, 75)
				add_new_driver(new_promoted_name, randi_range(18, 22), ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, team_name)
				log_transfer_event("🌟 PROMOÇÃO: %s promoveu o jovem %s da base para preencher a vaga!" % [team_name, new_promoted_name], "Contratação")
				
				active_team_drivers.clear()
				for d in drivers:
					if str(d.get("Equipe", "")).strip_edges().to_lower() == team_name.strip_edges().to_lower():
						active_team_drivers.append(d)

	ensure_full_grid()

func _get_driver_by_name(p_name: String) -> Dictionary:
	var clean_input = p_name.strip_edges().to_lower()
	if clean_input.is_empty(): return {}

	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", d.get("name", "")))).strip_edges().to_lower()
		if d_name == clean_input:
			return d

	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", d.get("name", "")))).strip_edges().to_lower()
		if clean_input.contains(d_name) or d_name.contains(clean_input):
			return d
			
		var parts_input = clean_input.split(" ")
		var parts_driver = d_name.split(" ")
		if parts_input.size() > 0 and parts_driver.size() > 0:
			if parts_input[-1] == parts_driver[-1] and parts_input[-1].length() > 2:
				return d

	return {}

func _get_team_by_name(t_name: String) -> Dictionary:
	var clean_t_name = t_name.strip_edges().to_lower()
	for t in teams:
		var name_str = str(t.get("Nome", t.get("nome", ""))).strip_edges().to_lower()
		if name_str == clean_t_name:
			return t
	return {}

func get_driver_moral_label(driver: Dictionary) -> String:
	var moral_val = int(driver.get("Moral", 75))
	if moral_val >= 85: return "Excelente (" + str(moral_val) + "%)"
	elif moral_val >= 70: return "Alta (" + str(moral_val) + "%)"
	elif moral_val >= 50: return "Média (" + str(moral_val) + "%)"
	elif moral_val >= 30: return "Baixa (" + str(moral_val) + "%)"
	else: return "Crítica (" + str(moral_val) + "%)"

func get_save_path(slot_index: int) -> String:
	return "user://savegame_slot_%d.json" % clamp(slot_index, 1, MAX_SAVE_SLOTS)

func get_all_slots_info() -> Array:
	var slots_info: Array = []
	for i in range(1, MAX_SAVE_SLOTS + 1):
		var path = get_save_path(i)
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				var json = JSON.new()
				if json.parse(content) == OK:
					var data = json.get_data()
					slots_info.append({
						"slot": i,
						"exists": true,
						"name": data.get("save_name", "Slot %d" % i),
						"year": int(data.get("current_year", 2026)),
						"gp": int(data.get("current_gp", 1)),
						"team": str(data.get("user_team", "McLaren")),
						"date": str(data.get("save_date", "--/--/----"))
					})
					continue
		slots_info.append({
			"slot": i,
			"exists": false,
			"name": "Slot %d (Vazio)" % i,
			"year": 2026,
			"gp": 1,
			"team": "McLaren",
			"date": "-"
		})
	return slots_info

func delete_save_slot(slot_index: int) -> bool:
	slot_index = clamp(slot_index, 1, MAX_SAVE_SLOTS)
	var path = get_save_path(slot_index)
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			var err = dir.remove("savegame_slot_%d.json" % slot_index)
			if err == OK:
				add_news_event("🗑️ Save do Slot %d foi excluído." % slot_index)
				return true
	return false

func save_game_slot(slot_index: int, custom_name: String = "") -> bool:
	slot_index = clamp(slot_index, 1, MAX_SAVE_SLOTS)
	current_slot = slot_index
	
	var datetime = Time.get_datetime_dict_from_system()
	var formatted_date = "%02d/%02d/%04d %02d:%02d" % [datetime.day, datetime.month, datetime.year, datetime.hour, datetime.minute]
	
	var save_name = custom_name.strip_edges()
	if save_name.is_empty():
		var slots = get_all_slots_info()
		var existing = slots[slot_index - 1]
		save_name = existing["name"] if existing["exists"] else "Carreira %s" % user_team

	var save_data = {
		"save_name": save_name,
		"save_date": formatted_date,
		"current_year": current_year,
		"current_gp": current_gp,
		"user_team": user_team,
		"drivers": drivers,
		"teams": teams,
		"tracks": tracks,
		"champions_history": champions_history,
		"transfer_history": transfer_history,
		"dashboard_layout": dashboard_layout,
		"team_season_expenses": team_season_expenses,
		"full_season_archive": full_season_archive
	}
	
	var safe_save_data = _make_json_safe(save_data)
	var json_string = JSON.stringify(safe_save_data, "\t")
	
	if json_string.is_empty():
		print_debug("Erro de serialização JSON!")
		return false
		
	var file = FileAccess.open(get_save_path(slot_index), FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		add_news_event("💾 Jogo salvo com sucesso no Slot %d!" % slot_index)
		return true
		
	return false

func _make_json_safe(value):
	var t = typeof(value)
	match t:
		TYPE_DICTIONARY:
			var clean_dict: Dictionary = {}
			for key in value.keys():
				clean_dict[str(key)] = _make_json_safe(value[key])
			return clean_dict
		TYPE_ARRAY:
			var clean_array: Array = []
			for item in value:
				clean_array.append(_make_json_safe(item))
			return clean_array
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			if t == TYPE_OBJECT:
				return null
			return str(value)

func load_game_slot(slot_index: int) -> bool:
	slot_index = clamp(slot_index, 1, MAX_SAVE_SLOTS)
	var path = get_save_path(slot_index)
	
	if not FileAccess.file_exists(path):
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			current_slot = slot_index
			current_year = data.get("current_year", 2026)
			current_gp = data.get("current_gp", 1)
			user_team = data.get("user_team", "McLaren")
			drivers = data.get("drivers", drivers)
			teams = data.get("teams", teams)
			tracks = data.get("tracks", tracks)
			champions_history = data.get("champions_history", champions_history)
			transfer_history = data.get("transfer_history", transfer_history)
			dashboard_layout = data.get("dashboard_layout", dashboard_layout)
			team_season_expenses = data.get("team_season_expenses", team_season_expenses)
			sanitize_unique_drivers()
			ensure_full_grid()
			return true
	return false

func has_any_save() -> bool:
	for i in range(1, MAX_SAVE_SLOTS + 1):
		if FileAccess.file_exists(get_save_path(i)):
			return true
	return false

func reset_database() -> void:
	current_year = 2026
	current_gp = 1
	race_finished = false
	active_engine = null
	init_season_budget_cap()
	
	if news_feed != null: news_feed.clear()
	if transfer_history != null: transfer_history.clear()

	if teams != null and teams is Array:
		for t in teams:
			t["Pontos"] = 0

	if drivers != null and drivers is Array:
		for d in drivers:
			d["Pontos"] = 0
			d["VitoriasAno"] = 0
			d["PodiosAno"] = 0
			d["DNFsAno"] = 0
			d["SequenciaPontos"] = 0
			d["PosicoesGanhaAno"] = 0
			d["PosicoesPerdidasAno"] = 0

	if has_method("load_drivers_from_json"):
		call("load_drivers_from_json")
	ensure_full_grid()

func record_gp_winner(track_index: int, winner_driver_name: String, winner_team_name: String) -> void:
	if track_index >= 0 and track_index < tracks.size():
		tracks[track_index]["UltimoVencedorPiloto"] = winner_driver_name
		tracks[track_index]["UltimoVencedorEquipe"] = winner_team_name

func save_game() -> bool:
	return save_game_slot(current_slot)

func add_new_team(team_name: String, respeto: int = 50, aero: int = 75, motor: int = 75, chassi: int = 75) -> void:
	if not _get_team_by_name(team_name).is_empty():
		return
		
	var new_rank = teams.size() + 1
	var new_team = {
		"Nome": team_name,
		"Orcamento": 100,
		"Motor": motor,
		"Aero": aero,
		"Chassi": chassi,
		"Confiabilidade": 80,
		"Respeito": respeto,
		"Pontos": 0,
		"LastSeasonRank": new_rank,
		"Ativa": false
	}
	teams.append(new_team)
	
	team_season_expenses[team_name] = 0.0
	var bonus_ratio = float(new_rank - 1) / float(max(1, teams.size() - 1))
	team_budget_caps[team_name] = COST_CAP_LIMIT + (20_000_000.0 * bonus_ratio)
	
	add_news("📋 REGISTRO DE EQUIPE: %s foi cadastrada e fará sua estreia na próxima temporada!" % team_name)

func add_new_driver(driver_name: String, age: int = 20, overall: int = 75, pace: int = 75, tire: int = 75, rain_skill: int = 75, overtake_skill: int = 75, defense_skill: int = 75, team_name: String = "Free Agent") -> void:
	var new_driver = {
		"Nome": driver_name,
		"Idade": age,
		"Overall": overall,
		"Grau": overall,
		"Corrida": pace,
		"Pace": pace,
		"Pneus": tire,
		"HabilidadeChuva": clamp(rain_skill, 0, 99),
		"Ultrapassagem": clamp(overtake_skill, 0, 99),
		"Defesa": clamp(defense_skill, 0, 99),
		"Equipe": team_name,
		"Moral": 75.0,
		"AnosContrato": 1 if team_name != "Free Agent" else 0,
		"Pontos": 0,
		"VitoriasAno": 0,
		"PodiosAno": 0,
		"DNFsAno": 0,
		"SequenciaPontos": 0,
		"PosicoesGanhaAno": 0,
		"PosicoesPerdidasAno": 0
	}
	drivers.append(new_driver)

func _ensure_driver_attributes(driver: Dictionary) -> void:
	var ovr = int(driver.get("Overall", 75))
	if not driver.has("HabilidadeChuva"):
		driver["HabilidadeChuva"] = driver.get("Pneus", ovr)
	if not driver.has("Ultrapassagem"):
		driver["Ultrapassagem"] = driver.get("Corrida", ovr)
	if not driver.has("Defesa"):
		driver["Defesa"] = driver.get("Grau", ovr)

func run_automated_test_season_and_export_telemetry(file_name: String = "telemetry_report.json") -> void:
	var test_report: Dictionary = {
		"test_date": Time.get_datetime_string_from_system(),
		"total_seasons_simulated": 10,
		"start_year": current_year,
		"seasons": []
	}
	
	print("🚀 Iniciando simulação em lote de 10 temporadas...")
	
	for s in range(10):
		var season_year = current_year
		var season_data: Dictionary = {
			"year": season_year,
			"champions": {},
			"drivers_standings": [],
			"team_expenses": {},
			"transfers": []
		}
		
		var remaining_gps = tracks.size() - current_gp + 1
		for g in range(remaining_gps):
			simulate_current_gp_fast()
			
		var sorted_drivers = drivers.duplicate()
		sorted_drivers.sort_custom(func(a, b): return int(a.get("Pontos", 0)) > int(b.get("Pontos", 0)))
		
		for d in sorted_drivers:
			season_data["drivers_standings"].append({
				"nome": str(d.get("Nome", "")),
				"equipe": str(d.get("Equipe", "")),
				"idade": int(d.get("Idade", 20)),
				"overall": int(d.get("Overall", 0)),
				"pontos": int(d.get("Pontos", 0)),
				"vitorias": int(d.get("VitoriasAno", 0)),
				"podios": int(d.get("PodiosAno", 0)),
				"dnfs": int(d.get("DNFsAno", 0)),
				"moral": float(d.get("Moral", 75.0))
			})
			
		if sorted_drivers.size() > 0:
			season_data["champions"]["driver"] = sorted_drivers[0].get("Nome", "")
			season_data["champions"]["team"] = sorted_drivers[0].get("Equipe", "")
			
		for team_name in team_season_expenses.keys():
			var spent = int(team_season_expenses[team_name])
			var cap = int(get_team_budget_cap(team_name)) if has_method("get_team_budget_cap") else 215000000
			season_data["team_expenses"][team_name] = {
				"spent_usd": spent,
				"cap_usd": cap
			}
			
		if has_node("/root/Database") and "transfer_history" in Database:
			season_data["transfers"] = Database.transfer_history.duplicate()
			
		test_report["seasons"].append(season_data)
		print("✅ Temporada %d (%d/10) concluída!" % [season_year, s + 1])
		
		if has_method("end_season_and_advance_year"):
			end_season_and_advance_year()

	var safe_data = _make_json_safe(test_report)
	var json_str = JSON.stringify(safe_data, "\t")
	var file = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		print("📊 AUDITORIA DE 10 TEMPORADAS EXPORTADA COM SUCESSO EM: user://", file_name)

func _apply_dnf_financial_penalty(team_name: String) -> void:
	if team_season_expenses.has(team_name):
		var repair_cost: int = randi_range(1000000, 3000000)
		team_season_expenses[team_name] += repair_cost
