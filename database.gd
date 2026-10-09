extends Node

var current_year: int = 2026
var current_gp: int = 1
var current_view: String = "dashboard"
var race_finished: bool = false
var active_engine: RaceEngine = null

# Variáveis Globais de Configuração
var ui_scale: float = 1.0
var aspect_index: int = 0
var window_mode_index: int = 0

var tracks: Array = [
	{"Nome": "Albert Park", "Pais": "Austrália", "Voltas": 58, "ChanceChuva": 0.20},
	{"Nome": "Shanghai", "Pais": "China", "Voltas": 56, "ChanceChuva": 0.15},
	{"Nome": "Suzuka", "Pais": "Japão", "Voltas": 53, "ChanceChuva": 0.30},
	{"Nome": "Sakhir", "Pais": "Bahrein", "Voltas": 57, "ChanceChuva": 0.05},
	{"Nome": "Jeddah", "Pais": "Arábia Saudita", "Voltas": 50, "ChanceChuva": 0.05},
	{"Nome": "Miami", "Pais": "EUA", "Voltas": 57, "ChanceChuva": 0.25},
	{"Nome": "Imola", "Pais": "Itália", "Voltas": 63, "ChanceChuva": 0.35},
	{"Nome": "Monaco", "Pais": "Mônaco", "Voltas": 78, "ChanceChuva": 0.30},
	{"Nome": "Catalunya", "Pais": "Espanha", "Voltas": 66, "ChanceChuva": 0.20},
	{"Nome": "Gilles Villeneuve", "Pais": "Canadá", "Voltas": 70, "ChanceChuva": 0.40},
	{"Nome": "Red Bull Ring", "Pais": "Áustria", "Voltas": 71, "ChanceChuva": 0.30},
	{"Nome": "Silverstone", "Pais": "Reino Unido", "Voltas": 52, "ChanceChuva": 0.45},
	{"Nome": "Hungaroring", "Pais": "Hungria", "Voltas": 70, "ChanceChuva": 0.20},
	{"Nome": "Spa-Francorchamps", "Pais": "Bélgica", "Voltas": 44, "ChanceChuva": 0.50},
	{"Nome": "Zandvoort", "Pais": "Holanda", "Voltas": 72, "ChanceChuva": 0.35},
	{"Nome": "Monza", "Pais": "Itália", "Voltas": 53, "ChanceChuva": 0.15},
	{"Nome": "Baku", "Pais": "Azerbaijão", "Voltas": 51, "ChanceChuva": 0.10},
	{"Nome": "Marina Bay", "Pais": "Cingapura", "Voltas": 62, "ChanceChuva": 0.35},
	{"Nome": "COTA", "Pais": "EUA", "Voltas": 56, "ChanceChuva": 0.20},
	{"Nome": "Hermanos Rodríguez", "Pais": "México", "Voltas": 71, "ChanceChuva": 0.25},
	{"Nome": "Interlagos", "Pais": "Brasil", "Voltas": 71, "ChanceChuva": 0.45},
	{"Nome": "Las Vegas", "Pais": "EUA", "Voltas": 50, "ChanceChuva": 0.05},
	{"Nome": "Lusail", "Pais": "Catar", "Voltas": 57, "ChanceChuva": 0.05},
	{"Nome": "Yas Marina", "Pais": "Abu Dhabi", "Voltas": 58, "ChanceChuva": 0.05}
]

var teams: Array = [
	{"Nome": "McLaren", "Orcamento": 145, "Motor": 92, "Aero": 91, "Chassi": 90, "Confiabilidade": 92, "Respeito": 88, "Pontos": 0},
	{"Nome": "Ferrari", "Orcamento": 150, "Motor": 94, "Aero": 90, "Chassi": 89, "Confiabilidade": 88, "Respeito": 85, "Pontos": 0},
	{"Nome": "Red Bull Racing", "Orcamento": 145, "Motor": 90, "Aero": 94, "Chassi": 91, "Confiabilidade": 90, "Respeito": 90, "Pontos": 0},
	{"Nome": "Mercedes", "Orcamento": 135, "Motor": 91, "Aero": 87, "Chassi": 88, "Confiabilidade": 93, "Respeito": 82, "Pontos": 0},
	{"Nome": "Aston Martin", "Orcamento": 120, "Motor": 88, "Aero": 85, "Chassi": 85, "Confiabilidade": 86, "Respeito": 75, "Pontos": 0},
	{"Nome": "Alpine", "Orcamento": 100, "Motor": 84, "Aero": 82, "Chassi": 83, "Confiabilidade": 80, "Respeito": 68, "Pontos": 0},
	{"Nome": "Haas", "Orcamento": 95, "Motor": 86, "Aero": 80, "Chassi": 80, "Confiabilidade": 85, "Respeito": 62, "Pontos": 0},
	{"Nome": "Racing Bulls", "Orcamento": 95, "Motor": 83, "Aero": 81, "Chassi": 81, "Confiabilidade": 83, "Respeito": 65, "Pontos": 0},
	{"Nome": "Williams", "Orcamento": 90, "Motor": 85, "Aero": 78, "Chassi": 79, "Confiabilidade": 82, "Respeito": 60, "Pontos": 0},
	{"Nome": "Audi", "Orcamento": 110, "Motor": 81, "Aero": 79, "Chassi": 80, "Confiabilidade": 78, "Respeito": 64, "Pontos": 0},
	{"Nome": "Cadillac", "Orcamento": 105, "Motor": 80, "Aero": 78, "Chassi": 78, "Confiabilidade": 81, "Respeito": 58, "Pontos": 0}
]

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

func _ready() -> void:
	load_drivers_from_json()

func load_drivers_from_json() -> void:
	var path = "res://drivers_data.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK:
				drivers = json.get_data()
				return
	print_debug("Aviso: drivers_data.json não encontrado ou inválido!")

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

# --- SISTEMA ROBUSTO DE DETECÇÃO DE DNF ---
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

# --- PROCESSAMENTO PÓS-CORRIDA CORRIGIDO ---
func process_post_race_morale_and_respect(race_results: Array) -> void:
	var team_points_this_race: Dictionary = {}
	var team_has_breakdown: Dictionary = {}
	
	for t in teams:
		team_points_this_race[t["Nome"]] = 0
		team_has_breakdown[t["Nome"]] = false

	var team_drivers_finish: Dictionary = {}
	var points_table = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

	for res in race_results:
		var p_name = str(res.get("Nome", res.get("nome", res.get("name", ""))))
		var t_name = str(res.get("Equipe", res.get("equipe", res.get("team", ""))))
		var finish_pos = int(res.get("pos", res.get("position", 20)))
		var grid_start = int(res.get("grid_pos", res.get("grid", finish_pos)))
		
		# Detecção abrangente de DNF
		var is_dnf = _check_is_dnf(res)
		
		var driver = _get_driver_by_name(p_name)
		if driver.is_empty():
			continue
			
		if not team_drivers_finish.has(t_name):
			team_drivers_finish[t_name] = []
		team_drivers_finish[t_name].append({"driver": driver, "pos": finish_pos, "abandonou": is_dnf})

		# Atualiza estatísticas acumuladas de DNF, posições ganhas/perdidas e sequência
		_update_driver_stats_after_race(driver, grid_start, finish_pos, is_dnf)

		if not is_dnf:
			if finish_pos <= 10:
				var pts = points_table[finish_pos - 1]
				driver["Pontos"] = int(driver.get("Pontos", 0)) + pts
				
				var team = _get_team_by_name(t_name)
				if not team.is_empty():
					team["Pontos"] = int(team.get("Pontos", 0)) + pts
					team_points_this_race[t_name] = team_points_this_race.get(t_name, 0) + pts

			if finish_pos == 1:
				driver["VitoriasAno"] = int(driver.get("VitoriasAno", 0)) + 1
				driver["PodiosAno"] = int(driver.get("PodiosAno", 0)) + 1
				driver["VitoriasCarreira"] = int(driver.get("VitoriasCarreira", 0)) + 1
				driver["Moral"] = clamp(int(driver.get("Moral", 70)) + 12, 0, 100)
				var track_idx = clamp(current_gp - 1, 0, tracks.size() - 1)
				add_news("🏁 " + driver["Nome"] + " vence o GP de " + tracks[track_idx]["Nome"] + "!")
			elif finish_pos <= 3:
				driver["PodiosAno"] = int(driver.get("PodiosAno", 0)) + 1
				driver["Moral"] = clamp(int(driver.get("Moral", 70)) + 8, 0, 100)
			elif finish_pos <= 10:
				driver["Moral"] = clamp(int(driver.get("Moral", 70)) + 4, 0, 100)
			else:
				driver["Moral"] = clamp(int(driver.get("Moral", 70)) - 4, 0, 100)

			driver["corridas_sem_abandonar"] = int(driver.get("corridas_sem_abandonar", 0)) + 1
			if int(driver["corridas_sem_abandonar"]) >= 5:
				driver["Moral"] = clamp(int(driver.get("Moral", 70)) + 5, 0, 100)
		else:
			driver["Moral"] = clamp(int(driver.get("Moral", 70)) - 10, 0, 100)
			driver["corridas_sem_abandonar"] = 0
			team_has_breakdown[t_name] = true

	for t_name in team_drivers_finish.keys():
		var d_list = team_drivers_finish[t_name]
		if d_list.size() >= 2:
			var d1 = d_list[0]
			var d2 = d_list[1]
			
			if not d1["abandonou"] and (d2["abandonou"] or d1["pos"] < d2["pos"]):
				_apply_teammate_rivalry(d1["driver"], d2["driver"])
			elif not d2["abandonou"] and (d1["abandonou"] or d2["pos"] < d1["pos"]):
				_apply_teammate_rivalry(d2["driver"], d1["driver"])

	for t in teams:
		var t_name = t["Nome"]
		var pts_gained = team_points_this_race.get(t_name, 0)
		var broke_down = team_has_breakdown.get(t_name, false)
		
		var respect_change = 0
		if pts_gained > 0:
			respect_change += min(15, pts_gained)
		else:
			respect_change -= 3
			
		if broke_down:
			respect_change -= 5
			
		t["Respeito"] = clamp(t.get("Respeito", 70) + respect_change, 0, 100)

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

func _apply_teammate_rivalry(winner_driver: Dictionary, loser_driver: Dictionary) -> void:
	winner_driver["Moral"] = clamp(int(winner_driver.get("Moral", 70)) + 3, 0, 100)
	winner_driver["atras_companheiro_seguidamente"] = 0
	
	var streak = int(loser_driver.get("atras_companheiro_seguidamente", 0)) + 1
	loser_driver["atras_companheiro_seguidamente"] = streak
	
	if streak >= 2:
		loser_driver["Moral"] = clamp(int(loser_driver.get("Moral", 70)) - (4 * (streak - 1)), 0, 100)

func simulate_current_gp_fast() -> void:
	if current_gp > tracks.size():
		return
		
	var engine = RaceEngine.new()
	var current_track = tracks[current_gp - 1]
	engine.setup_race(current_track)
	
	engine.skip_to_end_of_quali_session()
	
	# Salva a posição de largada da qualificação
	var grid_positions: Dictionary = {}
	for idx in range(engine.race_drivers.size()):
		var d_name = engine.race_drivers[idx].get("Nome", engine.race_drivers[idx].get("nome", ""))
		grid_positions[d_name] = idx + 1
	
	while not engine.is_finished():
		engine.process_lap()
		
	var results = engine.race_drivers
	for i in range(results.size()):
		results[i]["pos"] = i + 1
		var d_name = results[i].get("Nome", results[i].get("nome", ""))
		results[i]["grid_pos"] = grid_positions.get(d_name, i + 1)
		
	process_post_race_morale_and_respect(results)
	process_ai_team_upgrades()
	
	var winner_name = results[0].get("Nome", results[0].get("nome", "-")) if results.size() > 0 else "-"
	var second_name = results[1].get("Nome", results[1].get("nome", "-")) if results.size() > 1 else "-"
	var third_name = results[2].get("Nome", results[2].get("nome", "-")) if results.size() > 2 else "-"
	
	race_history.append({
		"gp_num": current_gp,
		"gp_index": current_gp,
		"track": current_track["Nome"],
		"winner": winner_name,
		"second": second_name,
		"third": third_name
	})
	
	current_gp += 1

func process_ai_team_upgrades() -> void:
	for t in teams:
		var focus = randi() % 4
		var gain = randi_range(1, 2)
		if focus == 0:
			t["Motor"] = min(99, t["Motor"] + gain)
			add_news(t["Nome"] + " instalou nova atualização de Unidade de Potência.")
		elif focus == 1:
			t["Aero"] = min(99, t["Aero"] + gain)
			add_news(t["Nome"] + " trouxe pacote de melhorias aerodinâmicas.")
		elif focus == 2:
			t["Chassi"] = min(99, t["Chassi"] + gain)
			add_news(t["Nome"] + " implementou modificações no Chassi.")
		else:
			t["Confiabilidade"] = min(99, t["Confiabilidade"] + gain)
			add_news(t["Nome"] + " reforçou a confiabilidade dos componentes.")

func _reset_team_development_cycle() -> void:
	for t in teams:
		t["Motor"] = randi_range(65, 90)
		t["Aero"] = randi_range(65, 90)
		t["Chassi"] = randi_range(65, 90)
		t["Confiabilidade"] = randi_range(65, 90)
		
	add_news_event("⚙️ NOVO REGULAMENTO TÉCNICO! O desenvolvimento de todas as equipes foi resetado para o novo ciclo!")

func can_team_sign_driver(team_name: String, driver_power_index: float) -> bool:
	var team = _get_team_by_name(team_name)
	var respect = team.get("Respeito", 50)
	
	if driver_power_index >= 90.0 and respect < 75:
		return false
	if driver_power_index >= 80.0 and respect < 50:
		return false
		
	return true

func is_driver_interested_in_team(driver_name: String, target_team_name: String) -> bool:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 50)
	var target_power = get_team_power_index(target_team_name)["overall"]
	
	if morale > 80 and target_power < 75.0:
		return false
		
	return true

func calculate_contract_offer_years(driver_name: String, team_name: String) -> int:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 75)
	var team = _get_team_by_name(team_name)
	var respect = team.get("Respeito", 50)
	
	if morale >= 85 and respect >= 70:
		return randi_range(4, 6)
	elif morale >= 70:
		return randi_range(2, 3)
	elif morale >= 50:
		return 1
	else:
		return 0

func should_fire_driver_critical_morale(driver_name: String) -> bool:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 75)
	var years_left = driver.get("AnosContrato", 1)
	
	if morale < 25 and years_left > 1:
		return true
	return false

func fire_driver(team_name: String, driver_name: String) -> void:
	var driver = _get_driver_by_name(driver_name)
	if not driver.is_empty():
		driver["Equipe"] = "Free Agent"
		driver["AnosContrato"] = 0
		log_transfer_event(str(current_year), driver_name + " foi demitido pela " + team_name + " por insatisfação.", "Demissão")
		
	_auto_fill_team_seat(team_name)

func _auto_fill_team_seat(team_name: String) -> void:
	var current_drivers = get_team_drivers(team_name)
	if current_drivers.size() >= 2:
		return
		
	var free_agents: Array = []
	for d in drivers:
		if d.get("Equipe", "") == "Free Agent":
			free_agents.append(d)
			
	free_agents.sort_custom(func(a, b): return a.get("Overall", 0) > b.get("Overall", 0))
	
	if free_agents.size() > 0:
		var fa_driver = free_agents[0]
		fa_driver["Equipe"] = team_name
		fa_driver["AnosContrato"] = max(1, calculate_contract_offer_years(fa_driver["Nome"], team_name))
		log_transfer_event(str(current_year), team_name + " assina com " + fa_driver["Nome"] + " por " + str(fa_driver["AnosContrato"]) + " ano(s).", "Contratação")

func get_team_drivers(team_name: String) -> Array:
	var list: Array = []
	for d in drivers:
		if d.get("Equipe", "") == team_name:
			list.append(d)
	return list

func log_transfer_event(season: String, detail: String, type_str: String = "Transferência") -> void:
	transfer_history.push_front({
		"temporada": season,
		"detalhe": detail,
		"tipo": type_str
	})

func end_season_and_advance_year() -> void:
	full_season_archive[current_year] = race_history.duplicate(true)
	
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
	
	if (current_year - 2026) % 4 == 0:
		_reset_team_development_cycle()
	
	_process_driver_evolution()
	_process_ai_transfer_market()
	
	for d in drivers:
		d["Pontos"] = 0
		d["VitoriasAno"] = 0
		d["PodiosAno"] = 0
		d["DNFsAno"] = 0
		d["SequenciaPontos"] = 0
		d["PosicoesGanhaAno"] = 0
		d["PosicoesPerdidasAno"] = 0
		
	for t in teams:
		t["Pontos"] = 0
		
	var last_champ_name = champions_history.back()["piloto"] if champions_history.size() > 0 else "Campeão"
	add_news_event("🏆 TEMPORADA %d INICIADA! As equipes chegam para o novo ano após o título de %s!" % [current_year, last_champ_name])

func _process_driver_evolution() -> void:
	for d in drivers:
		d["Idade"] = int(d.get("Idade", 20)) + 1
		if int(d.get("AnosContrato", 0)) > 0:
			d["AnosContrato"] = int(d["AnosContrato"]) - 1
			
		var age = int(d["Idade"])
		var delta = 0
		if age <= 23: delta = randi_range(1, 3)
		elif age <= 28: delta = randi_range(0, 1)
		elif age <= 34: delta = randi_range(-1, 0)
		else: delta = randi_range(-3, -1)
			
		d["Grau"] = clamp(int(d.get("Grau", 75)) + delta, 60, 99)
		d["Corrida"] = clamp(int(d.get("Corrida", 75)) + delta, 60, 99)
		d["Pneus"] = clamp(int(d.get("Pneus", 75)) + delta, 60, 99)
		d["Overall"] = int((d["Grau"] + d["Corrida"] + d["Pneus"]) / 3.0)
		
		if age >= 37 and randf() < 0.40:
			d["Equipe"] = "Aposentado"
			d["AnosContrato"] = 0
			add_news("🛑 " + str(d.get("Nome", "Piloto")) + " anunciou sua aposentadoria oficial da F1!")

func _process_ai_transfer_market() -> void:
	for t in teams:
		var team_name = str(t.get("Nome", ""))
		var active_team_drivers = []
		
		for d in drivers:
			if str(d.get("Equipe", "")) == team_name:
				if int(d.get("AnosContrato", 0)) == 0:
					add_news("💼 Contrato de " + str(d.get("Nome", "")) + " com a " + team_name + " expirou.")
					d["Equipe"] = "Free Agent"
				else:
					active_team_drivers.append(d)
					
		while active_team_drivers.size() < 2:
			var best_candidate = null
			var highest_overall = -1
			for d in drivers:
				if str(d.get("Equipe", "")) == "Free Agent" and int(d.get("Overall", 0)) > highest_overall:
					highest_overall = int(d.get("Overall", 0))
					best_candidate = d
					
			if best_candidate != null:
				best_candidate["Equipe"] = team_name
				best_candidate["AnosContrato"] = randi_range(1, 3)
				active_team_drivers.append(best_candidate)
				add_news("✍️ " + team_name + " contratou " + str(best_candidate.get("Nome", "")) + " por " + str(best_candidate["AnosContrato"]) + " ano(s)!")
			else:
				break

func _get_driver_by_name(p_name: String) -> Dictionary:
	var clean_input = p_name.strip_edges().to_lower()
	if clean_input.is_empty():
		return {}

	# 1. Busca Exata
	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", d.get("name", "")))).strip_edges().to_lower()
		if d_name == clean_input:
			return d

	# 2. Busca por Sobrenome / Parcial (Fallback)
	for d in drivers:
		var d_name = str(d.get("Nome", d.get("nome", d.get("name", "")))).strip_edges().to_lower()
		if clean_input.contains(d_name) or d_name.contains(clean_input):
			return d
			
		# Checa se o último nome coincide
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
	if moral_val >= 85:
		return "Excelente (" + str(moral_val) + "%)"
	elif moral_val >= 70:
		return "Alta (" + str(moral_val) + "%)"
	elif moral_val >= 50:
		return "Média (" + str(moral_val) + "%)"
	elif moral_val >= 30:
		return "Baixa (" + str(moral_val) + "%)"
	else:
		return "Crítica (" + str(moral_val) + "%)"

const SAVE_PATH = "user://savegame.json"

func save_game() -> bool:
	var save_data = {
		"current_year": current_year,
		"current_gp": current_gp,
		"drivers": drivers,
		"teams": teams,
		"tracks": tracks,
		"champions_history": champions_history,
		"transfer_history": transfer_history,
		"dashboard_layout": dashboard_layout
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		return true
	return false

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			current_year = data.get("current_year", 2026)
			current_gp = data.get("current_gp", 1)
			drivers = data.get("drivers", drivers)
			teams = data.get("teams", teams)
			tracks = data.get("tracks", tracks)
			champions_history = data.get("champions_history", champions_history)
			transfer_history = data.get("transfer_history", transfer_history)
			dashboard_layout = data.get("dashboard_layout", dashboard_layout)
			return true
	return false

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func reset_database() -> void:
	current_year = 2026
	current_gp = 1
	race_finished = false
	active_engine = null
	
	if news_feed != null:
		news_feed.clear()
		
	if transfer_history != null:
		transfer_history.clear()

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
