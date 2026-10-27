extends Node

var current_year: int = 2026
var current_gp: int = 1
var current_view: String = "dashboard"
var race_finished: bool = false
var active_engine: RaceEngine = null
var constructors_points_history: Array = [] # Estrutura: [{"gp": 1, "points": {"McLaren": 25, "Ferrari": 18, ...}}]
# Armazena os interesses/sondagens ativas das equipes sobre pilotos
var driver_market_interests: Array = []
signal language_changed
var current_language: String = "pt"

# Listas de fornecedores disponíveis no mercado
const ENGINE_SUPPLIERS: Array[String] = [
	"Audi",
	"Mercedes - AMG",
	"Ferrari",
	"Honda",
	"Red Bull / Ford",
	"Cadillac",
	"Desenvolver Próprio"
]

const CHASSIS_SUPPLIERS: Array[String] = [
	"Dallara",
	"Aston Martin",
	"Caterham",
	"BMW",
	"Desenvolver Próprio"
]

func get_driver_interests() -> Array:
	return driver_market_interests
	
# Variáveis Globais de Configuração
var ui_scale: float = 1.0
var aspect_index: int = 0
var window_mode_index: int = 1

# --- VARIÁVEIS DO MODO MANAGER ---
var is_custom_team: bool = false
var selected_manager_team: Dictionary = {}
var custom_team_data: Dictionary = {
	"nome": "",
	"cor": Color.WHITE,
	"chefe": "",
	"pais": ""
}

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
	# Dicionário temporário para agrupar as melhorias deste GP por tipo de componente
	# Ex: {"Unidade de Potência": ["Audi (+0.90)", "Williams (+0.82)"], "Chassi": ["Ferrari (+0.64)"]}
	var gp_upgrades_by_type: Dictionary = {
		"Unidade de Potência": [],
		"Aerodinâmica": [],
		"Chassi": [],
		"Confiabilidade": []
	}
	
	var total_upgrades_in_gp = 0

	for t in teams:
		if not bool(t.get("Ativa", true)): 
			continue
		
		var team_name = str(t.get("Nome", ""))
		var current_expense = team_season_expenses.get(team_name, 0.0)
		var max_cap = get_team_budget_cap(team_name)
		var remaining = max_cap - current_expense
		
		# Bloqueia se a equipe já estourou o teto de gastos
		if remaining < UPGRADE_COST:
			continue
			
		# Chance dinâmica de compra por GP
		var gp_progress = float(current_gp) / float(max(1, tracks.size()))
		var budget_ratio = remaining / max_cap
		var buy_chance = 0.50 if budget_ratio > (1.0 - gp_progress) else 0.30
		
		if randf() > buy_chance:
			continue
			
		# Cálculo de rendimento decrescente (P&D)
		var motor_val = float(t.get("Motor", 80))
		var aero_val = float(t.get("Aero", 80))
		var chassi_val = float(t.get("Chassi", 80))
		var current_avg = (motor_val + aero_val + chassi_val) / 3.0
		
		var gain: float = 0.0
		if current_avg < 85.0:
			gain = randf_range(0.8, 1.2)
		elif current_avg < 92.0:
			gain = randf_range(0.4, 0.7)
		else:
			gain = randf_range(0.15, 0.35)
			
		var available_focuses = []
		if t["Motor"] < 99.0: available_focuses.append(0)
		if t["Aero"] < 99.0: available_focuses.append(1)
		if t["Chassi"] < 99.0: available_focuses.append(2)
		if t["Confiabilidade"] < 99.0: available_focuses.append(3)
		
		if available_focuses.size() > 0:
			var focus = available_focuses[randi() % available_focuses.size()]
			var component_name = ""
			
			if focus == 0:
				t["Motor"] = min(99.0, t["Motor"] + gain)
				component_name = "Unidade de Potência"
			elif focus == 1:
				t["Aero"] = min(99.0, t["Aero"] + gain)
				component_name = "Aerodinâmica"
			elif focus == 2:
				t["Chassi"] = min(99.0, t["Chassi"] + gain)
				component_name = "Chassi"
			elif focus == 3:
				t["Confiabilidade"] = min(99.0, t["Confiabilidade"] + gain)
				component_name = "Confiabilidade"

			if not component_name.is_empty():
				team_season_expenses[team_name] = current_expense + UPGRADE_COST
				total_upgrades_in_gp += 1
				
				# Formata o trecho individual (ex: "Audi (+0.90)")
				var entry_str = "%s (+%.2f)" % [team_name, gain]
				gp_upgrades_by_type[component_name].append(entry_str)
		else:
			if remaining >= UPGRADE_COST:
				team_season_expenses[team_name] = current_expense + UPGRADE_COST

	# MONTA E EXIBE A MENSAGEM AGRUPADA APENAS SE HOUVER UPGRADES NO GP
	if total_upgrades_in_gp > 0:
		var summary_parts: Array = []
		
		for comp in ["Unidade de Potência", "Aerodinâmica", "Chassi", "Confiabilidade"]:
			var team_list: Array = gp_upgrades_by_type[comp]
			if team_list.size() > 0:
				var teams_formatted = ""
				if team_list.size() == 1:
					teams_formatted = team_list[0]
				elif team_list.size() == 2:
					teams_formatted = team_list[0] + " e " + team_list[1]
				else:
					var all_except_last = team_list.slice(0, team_list.size() - 1)
					teams_formatted = ", ".join(all_except_last) + " e " + team_list.back()
				
				var action_verb = "Atualizam a" if comp == "Unidade de Potência" else "Atualizam"
				summary_parts.append("%s %s %s" % [teams_formatted, action_verb, comp])

		var final_msg = "🛠️ UPGRADES: " + ". ".join(summary_parts) + "."
		add_news(final_msg)

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
	# Ao carregar ou sanitizar os pilotos no início da carreira
	for d in drivers:
		if not d.has("races_with_team"):
			# Pilotos titulares do grid inicial já têm histórico longo com suas equipes
			d["races_with_team"] = 24

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
	
	for d in drivers:
		var eq = str(d.get("Equipe", ""))
		if eq != "Free Agent" and eq != "Aposentado":
			d["races_with_team"] = int(d.get("races_with_team", 0)) + 1

	if results.size() > 0:
		apply_race_points(results)
		record_standings_history_after_gp() # <--- ESSA LINHA FAZ TUDO SOZINHA COM SEGURANÇA
		process_post_race_morale_and_respect(results)
		process_ai_team_upgrades()
		process_mid_season_renewals()
		
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
		
	current_gp += 1

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

const MAX_CONTRACT_YEARS: int = 10

# Determina a duração do contrato (1 a 10 anos no máximo)
func calculate_contract_offer_years(driver_name: String, team_name: String) -> int:
	var driver = _get_driver_by_name(driver_name)
	var morale = float(driver.get("Moral", 75.0))
	var team = _get_team_by_name(team_name)
	var respect = float(team.get("Respeito", 50))
	
	var offer_years: int = 0
	
	if morale >= 85.0 and respect >= 65.0:
		offer_years = randi_range(6, 10) # Oferta máxima permitida (até 10 anos)
	elif morale >= 75.0:
		offer_years = randi_range(4, 6)
	elif morale >= 55.0:
		offer_years = randi_range(2, 4)
	elif morale >= 25.0:
		offer_years = 1
	else:
		offer_years = 0
		
	return clampi(offer_years, 0, MAX_CONTRACT_YEARS)

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
		candidate["races_with_team"] = 0
		candidate["AnosContrato"] = randi_range(2, 3)
		candidate["Moral"] = 75.0
		candidate["seasons_without_contract"] = 0
		
		# Se o piloto nunca correu na temporada atual, garante estatísticas zeradas
		if not candidate.has("CorridasAno"): candidate["CorridasAno"] = 0
		
		log_transfer_event("✍️ REPOSIÇÃO: " + team_name + " contratou " + str(candidate["Nome"]) + " por " + str(candidate["AnosContrato"]) + " ano(s)!", "Contratação")
		
		_auto_fill_team_seat(team_name)
		candidate["races_with_team"] = 0
		return

	var rookie_name = "Novato " + team_name.substr(0, 3).to_upper() + " " + str(randi_range(10, 99))
	var ovr = randi_range(68, 75)
	add_new_driver(rookie_name, randi_range(18, 21), ovr, ovr, ovr, ovr, ovr, ovr, team_name)
	
	# Reseta o tempo de casa do novo piloto promovido
	var new_rookie = _get_driver_by_name(rookie_name)
	if not new_rookie.is_empty():
		new_rookie["races_with_team"] = 0

func get_team_drivers(team_name: String) -> Array:
	var list: Array = []
	var target = team_name.strip_edges().to_lower()
	for d in drivers:
		var eq = str(d.get("Equipe", "")).strip_edges().to_lower()
		if eq == target:
			list.append(d)
	return list

# Retorna todos os pilotos únicos que estão em uma equipe ou que já participaram da temporada
func get_season_drivers() -> Array:
	var season_drivers: Array = []
	var seen_names: Dictionary = {}
	
	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", ""))).strip_edges().to_lower()
		if d_name.is_empty() or seen_names.has(d_name):
			continue
			
		var eq = str(d.get("Equipe", "Free Agent")).strip_edges()
		var pts = int(d.get("Pontos", 0))
		var vits = int(d.get("VitoriasAno", 0))
		var pods = int(d.get("PodiosAno", 0))
		var dnfs = int(d.get("DNFsAno", 0))
		var gps = int(d.get("CorridasAno", d.get("gps_disputados", 0)))
		var has_hist = d.has("HistoricoPosicoes") and (d["HistoricoPosicoes"] is Array) and d["HistoricoPosicoes"].size() > 0
		
		var is_active_team = (eq != "Free Agent" and eq != "Aposentado" and not eq.is_empty())
		var has_participated = (pts > 0 or vits > 0 or pods > 0 or dnfs > 0 or gps > 0 or has_hist)
		
		if is_active_team or has_participated:
			seen_names[d_name] = true
			season_drivers.append(d)
			
	return season_drivers

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

# Processa tentativas proativas de renovação em qualquer GP para pilotos próximos do fim de contrato (<= 2 anos)
func process_mid_season_renewals() -> void:
	for d in drivers:
		var eq = str(d.get("Equipe", ""))
		if eq == "Free Agent" or eq == "Aposentado" or eq.is_empty():
			continue
			
		var yrs = int(d.get("AnosContrato", 1))
		var morale = float(d.get("Moral", 75.0))
		var races_run = int(d.get("races_with_team", 24))
		
		# REGRA CORRIGIDA:
		# 1. Trava de 12 GPs para recém-contratados
		# 2. Só tenta renovação antecipada se o contrato estiver em seu ÚLTIMO ANO (yrs <= 1)
		if races_run < 12 or yrs > 1:
			continue
			
		# Chance de renovação baseada na moral do piloto
		var renewal_chance = 0.40 if morale >= 75.0 else (0.20 if morale >= 60.0 else 0.05)
		
		if randf() < renewal_chance:
			var driver_name = str(d.get("Nome", ""))
			var new_years = calculate_contract_offer_years(driver_name, eq)
			
			if new_years > 0:
				var final_contract = min(MAX_CONTRACT_YEARS, yrs + new_years)
				var added_years = final_contract - yrs
				
				if added_years > 0:
					d["AnosContrato"] = final_contract
					var msg = tr_text("NEWS_RENEWAL") % [driver_name, eq, added_years]
					log_transfer_event(msg, "Renovação")

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
	constructors_points_history.clear()
	
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
		d["HistoricoPosicoes"] = []
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
	
	driver_market_interests.clear()

	# 1. FASE DE RESCISÃO DE CONTRATOS EXPIRADOS (AnosContrato <= 0)
	for d in drivers:
		var team_name = str(d.get("Equipe", ""))
		if team_name != "Free Agent" and team_name != "Aposentado" and not team_name.is_empty():
			if int(d.get("AnosContrato", 0)) <= 0:
				d["Equipe"] = "Free Agent"
				var fired_by: Array = d.get("demitido_por_equipes", [])
				if not fired_by.has(team_name):
					fired_by.append(team_name)
				d["demitido_por_equipes"] = fired_by
				log_transfer_event("🚨 FIM DE CONTRATO: " + str(d.get("Nome", "")) + " não renovou com a " + team_name + "!", "Demissão")

	# 2. FASE DE ROUBO DE PILOTOS (Poaching / Compra de Contratos por Interesses de Mercado)
	# Equipes do topo (P1 a P11) tentam tirar destaques de equipes menores
	var sorted_teams = teams.duplicate()
	sorted_teams.sort_custom(func(a, b): return int(a.get("LastSeasonRank", 99)) < int(b.get("LastSeasonRank", 99)))

	for buyer in sorted_teams:
		var buyer_name = str(buyer.get("Nome", ""))
		var buyer_drivers = get_team_drivers(buyer_name)
		
		# Se a equipe de topo tem vaga ou quer trocar um piloto fraco
		if buyer_drivers.size() < 2:
			_try_poach_driver_from_rival(buyer_name)

	# 3. DANÇA DAS CADEIRAS (Preenche vagas restantes com Free Agents ou Promovidos)
	for t in sorted_teams:
		var team_name = str(t.get("Nome", ""))
		var active_team_drivers = get_team_drivers(team_name)
		
		while active_team_drivers.size() < 2:
			# Tenta primeiro 'roubar' um piloto elegível de equipe menor
			if _try_poach_driver_from_rival(team_name):
				active_team_drivers = get_team_drivers(team_name)
				continue
				
			# Se não conseguir roubar, contrata o melhor Free Agent
			var best_candidate = null
			var highest_overall = -1
			
			for d in drivers:
				if str(d.get("Equipe", "")).strip_edges().to_lower() == "free agent":
					var fired_by: Array = d.get("demitido_por_equipes", [])
					if not fired_by.has(team_name):
						var ovr = int(d.get("Overall", 0))
						if ovr > highest_overall:
							highest_overall = ovr
							best_candidate = d
							
			if best_candidate != null:
				best_candidate["Equipe"] = team_name
				best_candidate["AnosContrato"] = randi_range(2, 3)
				best_candidate["Moral"] = 75.0
				log_transfer_event("✍️ REPOSIÇÃO: " + team_name + " contratou o agente livre " + str(best_candidate.get("Nome", "")) + " por " + str(best_candidate["AnosContrato"]) + " ano(s)!", "Contratação")
				active_team_drivers.append(best_candidate)
			else:
				var new_promoted_name = "Novato " + team_name.substr(0, 3).to_upper() + " " + str(randi_range(10, 99))
				var ovr_tmp = randi_range(68, 75)
				add_new_driver(new_promoted_name, randi_range(18, 22), ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, ovr_tmp, team_name)
				log_transfer_event("🌟 PROMOÇÃO: " + team_name + " promoveu o jovem " + new_promoted_name + " da base!", "Contratação")
				active_team_drivers = get_team_drivers(team_name)

	ensure_full_grid()

# Função que realiza a compra de contrato ("roubo") de um piloto sob contrato em outra equipe
func _try_poach_driver_from_rival(buyer_team_name: String) -> bool:
	var buyer_team = _get_team_by_name(buyer_team_name)
	var buyer_power = get_team_power_index(buyer_team_name)["overall"]
	
	var best_target = null
	var highest_target_score = -1.0
	
	for d in drivers:
		var current_team_name = str(d.get("Equipe", ""))
		if current_team_name == "Free Agent" or current_team_name == "Aposentado" or current_team_name == buyer_team_name or current_team_name.is_empty():
			continue
			
		var seller_power = get_team_power_index(current_team_name)["overall"]
		var ovr = int(d.get("Overall", 70))
		var morale = float(d.get("Moral", 75.0))
		
		# Critério de Agressividade: A equipe compradora é ligeiramente superior (>1.0 Pt) OU o piloto está insatisfeito (Moral < 60)
		var is_attracked = (buyer_power >= seller_power + 1.0) or (morale < 60.0)
		
		if is_attracked and can_team_sign_driver(buyer_team_name, ovr):
			# Registra o interesse na aba de Interesses
			driver_market_interests.append({
				"piloto": str(d.get("Nome", "")),
				"equipe_atual": current_team_name,
				"equipe_interessada": buyer_team_name,
				"overall": ovr,
				"status": "Proposta de Compra"
			})
			
			if ovr > highest_target_score:
				highest_target_score = float(ovr)
				best_target = d
				
	# 70% de chance de concretizar o roubo caso encontre um candidato viável
	if best_target != null and randf() < 0.70:
		var poached_name = str(best_target.get("Nome", ""))
		var seller_team = str(best_target.get("Equipe", ""))
		
		best_target["Equipe"] = buyer_team_name
		best_target["AnosContrato"] = randi_range(2, 4)
		best_target["Moral"] = 85.0
		best_target["races_with_team"] = 0 # RESETA A TRAVA DAS 12 CORRIDAS
		
		var msg = Database.tr_text("NEWS_TRANSFER") % [buyer_team_name, poached_name, seller_team]
		log_transfer_event(msg, "Transferência")

		# Efeito em cadeia: A equipe rival lesada repõe a vaga
		_auto_fill_team_seat(seller_team)
		return true
		
	return false

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
						"name": "Slot %d (%s)" % [i, tr_text("SAVE_SLOT_EMPTY") if has_method("tr_text") else "Vazio"],
						"year": int(data.get("current_year", 2026)),
						"gp": int(data.get("current_gp", 1)),
						"team": str(data.get("user_team", "McLaren")),
						"date": str(data.get("save_date", "--/--/----"))
					})
					continue
		slots_info.append({
			"slot": i,
			"exists": false,
			"name": "Slot %d (%s)" % [i, tr_text("SAVE_SLOT_EMPTY") if has_method("tr_text") else "Vazio"],
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

func reset_incorrect_history() -> void:
	for d in drivers:
		d["HistoricoPosicoes"] = []

# --- REGISTRO OFICIAL E ISOLADO DO HISTÓRICO NO CAMPEONATO ---
func record_standings_history_after_gp() -> void:
	var standings_to_record: Array = []
	
	# 1. Filtra apenas os pilotos com equipe ativa no campeonato
	for d in drivers:
		var eq = str(d.get("Equipe", ""))
		if eq != "Free Agent" and eq != "Aposentado" and not eq.is_empty():
			standings_to_record.append(d)

	# 2. Ordena estritamente pelos critérios oficiais da F1 (Pontos > Vitórias > Pódios)
	standings_to_record.sort_custom(func(a, b):
		var p_a = int(a.get("Pontos", 0))
		var p_b = int(b.get("Pontos", 0))
		if p_a != p_b: return p_a > p_b
		var v_a = int(a.get("VitoriasAno", 0))
		var v_b = int(b.get("VitoriasAno", 0))
		if v_a != v_b: return v_a > v_b
		var pod_a = int(a.get("PodiosAno", 0))
		var pod_b = int(b.get("PodiosAno", 0))
		if pod_a != pod_b: return pod_a > pod_b
		return str(a.get("Nome", "")) < str(b.get("Nome", ""))
	)

	# 3. Anexa a posição em uma lista 100% EXCLUSIVA para cada piloto
	var pos_rank = 1
	for d in standings_to_record:
		if not d.has("HistoricoPosicoes") or not (d["HistoricoPosicoes"] is Array):
			d["HistoricoPosicoes"] = []
		else:
			# .duplicate() garante que o Array deste piloto seja único e isolado em memória
			var current_arr: Array = d["HistoricoPosicoes"]
			d["HistoricoPosicoes"] = current_arr.duplicate()

		d["HistoricoPosicoes"].append(pos_rank)
		pos_rank += 1

# --- NOVAS OPÇÕES DE JOGO ---
var reduce_speed_on_sc: bool = true   # Ativado por padrão (força 1x no Safety Car se true)

# Função auxiliar para buscar o texto traduzido conforme o idioma selecionado
func tr_text(key: String) -> String:
	var lang = current_language if current_language in Translations.dict else "pt"
	if key in Translations.dict[lang]:
		return Translations.dict[lang][key]
	# Fallback para o português caso a chave não exista no idioma selecionado
	if key in Translations.dict["pt"]:
		return Translations.dict["pt"][key]
	return key

# Altera o idioma e notifica o jogo inteiro
func set_language(new_lang: String) -> void:
	if Translations.dict.has(new_lang) and current_language != new_lang:
		current_language = new_lang
		if has_signal("language_changed"):
			language_changed.emit()
