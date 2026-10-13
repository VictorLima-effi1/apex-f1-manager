extends Node

var current_year: int = 2026
var current_gp: int = 1
var current_view: String = "dashboard"
var race_finished: bool = false
var active_engine: RaceEngine = null

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

var tracks: Array = [
	{
		"Nome": "Albert Park",
		"Pais": "Austrália",
		"Voltas": 58,
		"ComprimentoKM": 5.278,
		"VelocidadeMediaKMH": 235.0,
		"ChanceChuva": 0.20,
		"ZonasDRS": 4,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.5
	},
	{
		"Nome": "Shanghai",
		"Pais": "China",
		"Voltas": 56,
		"ComprimentoKM": 5.451,
		"VelocidadeMediaKMH": 210.0,
		"ChanceChuva": 0.15,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 23.0
	},
	{
		"Nome": "Suzuka",
		"Pais": "Japão",
		"Voltas": 53,
		"ComprimentoKM": 5.807,
		"VelocidadeMediaKMH": 232.0,
		"ChanceChuva": 0.30,
		"ZonasDRS": 1,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Sakhir",
		"Pais": "Bahrein",
		"Voltas": 57,
		"ComprimentoKM": 5.412,
		"VelocidadeMediaKMH": 212.0,
		"ChanceChuva": 0.05,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 23.0
	},
	{
		"Nome": "Jeddah",
		"Pais": "Arábia Saudita",
		"Voltas": 50,
		"ComprimentoKM": 6.174,
		"VelocidadeMediaKMH": 252.0,
		"ChanceChuva": 0.05,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 21.0
	},
	{
		"Nome": "Miami",
		"Pais": "EUA",
		"Voltas": 57,
		"ComprimentoKM": 5.412,
		"VelocidadeMediaKMH": 218.0,
		"ChanceChuva": 0.25,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Imola",
		"Pais": "Itália",
		"Voltas": 63,
		"ComprimentoKM": 4.909,
		"VelocidadeMediaKMH": 228.0,
		"ChanceChuva": 0.35,
		"ZonasDRS": 1,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Monaco",
		"Pais": "Mônaco",
		"Voltas": 78,
		"ComprimentoKM": 3.337,
		"VelocidadeMediaKMH": 162.0,
		"ChanceChuva": 0.30,
		"ZonasDRS": 1,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 19.0
	},
	{
		"Nome": "Catalunya",
		"Pais": "Espanha",
		"Voltas": 66,
		"ComprimentoKM": 4.657,
		"VelocidadeMediaKMH": 218.0,
		"ChanceChuva": 0.20,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Gilles Villeneuve",
		"Pais": "Canadá",
		"Voltas": 70,
		"ComprimentoKM": 4.361,
		"VelocidadeMediaKMH": 215.0,
		"ChanceChuva": 0.40,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "George Russell",
		"UltimoVencedorEquipe": "Mercedes",
		"pit_loss_time": 19.0
	},
	{
		"Nome": "Red Bull Ring",
		"Pais": "Áustria",
		"Voltas": 71,
		"ComprimentoKM": 4.318,
		"VelocidadeMediaKMH": 238.0,
		"ChanceChuva": 0.30,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 20.0
	},
	{
		"Nome": "Silverstone",
		"Pais": "Reino Unido",
		"Voltas": 52,
		"ComprimentoKM": 5.891,
		"VelocidadeMediaKMH": 242.0,
		"ChanceChuva": 0.45,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 20.0
	},
	{
		"Nome": "Hungaroring",
		"Pais": "Hungria",
		"Voltas": 70,
		"ComprimentoKM": 4.381,
		"VelocidadeMediaKMH": 198.0,
		"ChanceChuva": 0.20,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Spa-Francorchamps",
		"Pais": "Bélgica",
		"Voltas": 44,
		"ComprimentoKM": 7.004,
		"VelocidadeMediaKMH": 242.0,
		"ChanceChuva": 0.50,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 20.0
	},
	{
		"Nome": "Zandvoort",
		"Pais": "Holanda",
		"Voltas": 72,
		"ComprimentoKM": 4.259,
		"VelocidadeMediaKMH": 215.0,
		"ChanceChuva": 0.35,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Oscar Piastri",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Monza",
		"Pais": "Itália",
		"Voltas": 53,
		"ComprimentoKM": 5.793,
		"VelocidadeMediaKMH": 258.0,
		"ChanceChuva": 0.15,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 25.0
	},
	{
		"Nome": "Baku",
		"Pais": "Azerbaijão",
		"Voltas": 51,
		"ComprimentoKM": 6.003,
		"VelocidadeMediaKMH": 215.0,
		"ChanceChuva": 0.10,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 19.0
	},
	{
		"Nome": "Marina Bay",
		"Pais": "Cingapura",
		"Voltas": 62,
		"ComprimentoKM": 4.940,
		"VelocidadeMediaKMH": 182.0,
		"ChanceChuva": 0.35,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "George Russell",
		"UltimoVencedorEquipe": "Mercedes",
		"pit_loss_time": 27.0
	},
	{
		"Nome": "COTA",
		"Pais": "EUA",
		"Voltas": 56,
		"ComprimentoKM": 5.513,
		"VelocidadeMediaKMH": 210.0,
		"ChanceChuva": 0.20,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 21.0
	},
	{
		"Nome": "Hermanos Rodríguez",
		"Pais": "México",
		"Voltas": 71,
		"ComprimentoKM": 4.304,
		"VelocidadeMediaKMH": 208.0,
		"ChanceChuva": 0.25,
		"ZonasDRS": 3,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 23.0
	},
	{
		"Nome": "Interlagos",
		"Pais": "Brasil",
		"Voltas": 71,
		"ComprimentoKM": 4.309,
		"VelocidadeMediaKMH": 216.0,
		"ChanceChuva": 0.45,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Lando Norris",
		"UltimoVencedorEquipe": "McLaren",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Las Vegas",
		"Pais": "EUA",
		"Voltas": 50,
		"ComprimentoKM": 6.201,
		"VelocidadeMediaKMH": 240.0,
		"ChanceChuva": 0.05,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 26.0
	},
	{
		"Nome": "Lusail",
		"Pais": "Catar",
		"Voltas": 57,
		"ComprimentoKM": 5.419,
		"VelocidadeMediaKMH": 236.0,
		"ChanceChuva": 0.05,
		"ZonasDRS": 1,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 22.0
	},
	{
		"Nome": "Yas Marina",
		"Pais": "Abu Dhabi",
		"Voltas": 58,
		"ComprimentoKM": 5.281,
		"VelocidadeMediaKMH": 222.0,
		"ChanceChuva": 0.05,
		"ZonasDRS": 2,
		"UltimoVencedorPiloto": "Max Verstappen",
		"UltimoVencedorEquipe": "Red Bull Racing",
		"pit_loss_time": 21.0
	}
]

var teams: Array = [
	{"Nome": "Red Bull Racing", "Orcamento": 145, "Motor": 92, "Aero": 94, "Chassi": 91, "Confiabilidade": 90, "Respeito": 90, "Pontos": 0, "LastSeasonRank": 1},
	{"Nome": "Ferrari", "Orcamento": 150, "Motor": 94, "Aero": 90, "Chassi": 89, "Confiabilidade": 88, "Respeito": 85, "Pontos": 0, "LastSeasonRank": 2},
	{"Nome": "McLaren", "Orcamento": 145, "Motor": 92, "Aero": 91, "Chassi": 90, "Confiabilidade": 92, "Respeito": 88, "Pontos": 0, "LastSeasonRank": 3},
	{"Nome": "Mercedes", "Orcamento": 135, "Motor": 91, "Aero": 87, "Chassi": 88, "Confiabilidade": 93, "Respeito": 82, "Pontos": 0, "LastSeasonRank": 4},
	{"Nome": "Aston Martin", "Orcamento": 120, "Motor": 88, "Aero": 85, "Chassi": 85, "Confiabilidade": 86, "Respeito": 75, "Pontos": 0, "LastSeasonRank": 5},
	{"Nome": "Alpine", "Orcamento": 100, "Motor": 84, "Aero": 82, "Chassi": 83, "Confiabilidade": 80, "Respeito": 68, "Pontos": 0, "LastSeasonRank": 6},
	{"Nome": "Haas", "Orcamento": 95, "Motor": 86, "Aero": 80, "Chassi": 80, "Confiabilidade": 85, "Respeito": 62, "Pontos": 0, "LastSeasonRank": 7},
	{"Nome": "Racing Bulls", "Orcamento": 95, "Motor": 83, "Aero": 81, "Chassi": 81, "Confiabilidade": 83, "Respeito": 65, "Pontos": 0, "LastSeasonRank": 8},
	{"Nome": "Williams", "Orcamento": 90, "Motor": 85, "Aero": 78, "Chassi": 79, "Confiabilidade": 82, "Respeito": 60, "Pontos": 0, "LastSeasonRank": 9},
	{"Nome": "Audi", "Orcamento": 110, "Motor": 81, "Aero": 79, "Chassi": 80, "Confiabilidade": 78, "Respeito": 64, "Pontos": 0, "LastSeasonRank": 10},
	{"Nome": "Cadillac", "Orcamento": 105, "Motor": 80, "Aero": 78, "Chassi": 78, "Confiabilidade": 81, "Respeito": 58, "Pontos": 0, "LastSeasonRank": 11}
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

const F1_POINTS = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]

func _ready() -> void:
	load_drivers_from_json()
	init_season_budget_cap()

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
		var team_name = str(t.get("Nome", ""))
		var current_expense = team_season_expenses.get(team_name, 0.0)
		var max_cap = get_team_budget_cap(team_name)
		var remaining = max_cap - current_expense
		
		# Se já estourou o teto ou não tem verba para nem 1 upgrade, pula
		if remaining < UPGRADE_COST:
			continue
			
		# --- LÓGICA DE AGRESSIVIDADE DINÂMICA ---
		# Conforme os GPs passam, a chance de comprar upgrade aumenta se a equipe tiver verba sobrando
		var gp_progress = float(current_gp) / float(max(1, tracks.size())) # 0.0 a 1.0
		var budget_ratio = remaining / max_cap                       # quanto % de verba ainda tem
		
		# Aumenta a chance base de 25% para 60% se houver muita verba acumulada
		var buy_chance = 0.60 if budget_ratio > (1.0 - gp_progress) else 0.35
		
		if randf() > buy_chance:
			continue
			
		# Top 3 ganha +1..2%, P4-P11 ganha +3..4%
		var last_rank = int(t.get("LastSeasonRank", 5))
		var gain = randi_range(1, 2) if last_rank <= 3 else randi_range(3, 4)
		
		# Procura um componente abaixo do limite máximo (99)
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
		else:
			# Se todos os componentes já estiverem em 99%, investe a verba restante no carro do próximo ano
			if remaining >= UPGRADE_COST:
				team_season_expenses[team_name] = current_expense + UPGRADE_COST
				add_news("🔬 P&D AVANÇADO (%s): Investimento no projeto do ano seguinte ($%sM restantes)" % [
					team_name,
					str(snapped((remaining - UPGRADE_COST) / 1000000.0, 0.1))
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

func apply_race_points(standings: Array) -> void:
	for i in range(min(10, standings.size())):
		var driver_data = standings[i]
		if driver_data.get("dnf", false) or driver_data.get("abandonou", false):
			continue
			
		var pts = F1_POINTS[i]
		var driver_name = str(driver_data.get("Nome", ""))
		var team_name = str(driver_data.get("Equipe", ""))
		
		for d in drivers:
			if str(d.get("Nome", "")) == driver_name:
				d["Pontos"] = int(d.get("Pontos", 0)) + pts
				break
				
		for t in teams:
			if str(t.get("Nome", "")) == team_name:
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
		var driver_name = str(d.get("Nome", ""))
		var pos = int(d.get("pos", 22))
		var grid_pos = int(d.get("grid_pos", pos))
		var is_dnf = d.get("dnf", false) or d.get("abandonou", false)
		
		var real_driver = _get_driver_by_name(driver_name)
		if real_driver.is_empty():
			continue
			
		var current_morale = float(real_driver.get("Moral", 75.0))
		var morale_change = 0.0
		
		if pos == 1: morale_change += 12.0
		elif pos <= 3: morale_change += 8.0
		elif pos <= 10: morale_change += 4.0
		elif pos >= 18: morale_change -= 2.0
			
		var pos_gained = grid_pos - pos
		if pos_gained >= 5: morale_change += 6.0
		elif pos_gained >= 2: morale_change += 3.0
		elif pos_gained <= -6: morale_change -= 3.0

		if is_dnf: morale_change -= 4.0
		if current_morale < 35.0 and not is_dnf: morale_change += 5.0

		var team_name = str(real_driver.get("Equipe", ""))
		var teammate_pos = 99
		for other in standings:
			if str(other.get("Equipe", "")) == team_name and str(other.get("Nome", "")) != driver_name:
				teammate_pos = int(other.get("pos", 99))
				break
				
		if teammate_pos < 99:
			if pos < teammate_pos: morale_change += 3.0
			else: morale_change -= 3.0

		morale_change = clamp(morale_change, -10.0, 12.0)
		real_driver["Moral"] = clamp(current_morale + morale_change, 15.0, 100.0)

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
	
	current_gp += 1
	
	if engine is Node:
		engine.free()

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

func should_fire_driver_critical_morale(driver_name: String) -> bool:
	var driver = _get_driver_by_name(driver_name)
	var morale = driver.get("Moral", 75)
	var years_left = driver.get("AnosContrato", 1)
	return morale < 25 and years_left > 1

func fire_driver(team_name: String, driver_name: String) -> void:
	var driver = _get_driver_by_name(driver_name)
	if not driver.is_empty():
		driver["Equipe"] = "Free Agent"
		driver["AnosContrato"] = 0
		log_transfer_event(str(current_year), driver_name + " foi demitido pela " + team_name + " por insatisfação.", "Demissão")
		
	_auto_fill_team_seat(team_name)

func _auto_fill_team_seat(team_name: String) -> void:
	var current_drivers = get_team_drivers(team_name)
	if current_drivers.size() >= 2: return
		
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
	
	_recalculate_team_handicaps_and_reset_caps()
	
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
			add_news("🛑 " + str(d.get("Nome", "Piloto")) + " anunciou sua aposentadoria oficial!")

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

# --- GERENCIAMENTO DE ARQUIVOS DE SAVE LOCAIS (3 SLOTS) ---
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

func record_gp_winner(track_index: int, winner_driver_name: String, winner_team_name: String) -> void:
	if track_index >= 0 and track_index < tracks.size():
		tracks[track_index]["UltimoVencedorPiloto"] = winner_driver_name
		tracks[track_index]["UltimoVencedorEquipe"] = winner_team_name

func save_game() -> bool:
	return save_game_slot(current_slot)
