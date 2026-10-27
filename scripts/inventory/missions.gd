extends Node
## Missions. Two kinds:
##  · the story ("A Lenda do Arquipélago"): one objective at a time, shown on screen after the first-trip
##    tutorial, leading from feeding fish and hauling traps to facing the three guardians;
##  · market contracts: three orders on the board at the fish market (deliver a species, a trophy fish or
##    a trap catch). Deliver from the market panel; a new order replaces it.
## Progress is read from the game state (inventory, encyclopedia, discoveries) once a second.
var game: Node3D
var step: int=0
var contracts: Array[Dictionary]=[]
var completed_contracts: int=0
var _clock: float=0.
var _rng:=RandomNumberGenerator.new()

## title, objective text, what is counted, how many, reward (coins)
const STORY: Array=[
	["Isca na água","Do barco, jogue ração (C) e veja o cardume subir.","fed",1,20],
	["Explorador","Descubra 3 lugares do arquipélago (veja o mapa, M).","places",3,40],
	["Covo cheio","Compre um covo na loja de pesca, baixe-o (B) e recolha-o cheio.","traps",1,40],
	["Caderno de pesca","Registre 5 espécies diferentes na enciclopédia (J).","species",5,60],
	["Pedido do mercado","Entregue uma encomenda do quadro de pedidos do mercado.","contracts",1,50],
	["Olhos no abismo","Entre num território de monstro (mapa) e observe o guardião: luzes apagadas, bem devagar.","observed",1,80],
	["Armado para o mar","Instale o arpão de proa no estaleiro.","harpoon",1,30],
	["Caçador de lendas","Afugente um guardião com o arpão (H). Turbo: SHIFT. Sinalizador: Y.","victories",1,120],
	["Lenda dos Mares","Vença o Kraken, a Serpente Marinha e o Leviatã.","victories",3,400],
]

## Contract templates: species id, count, minimum weight (0 = any)
const ORDERS: Array=[["sardine",3,0.],["mackerel",2,0.],["sargo",2,0.],["pargo",1,0.],["seabass",1,0.],["baiacu",1,0.],
	["cirurgiao",2,0.],["caranguejo",3,0.],["lagosta",1,0.],["manjuba",6,0.],["tuna",1,0.],["seabass",1,3.],["pargo",1,2.5],
	["tubarao_recife",1,0.],["atum_rei",1,0.],["peixe_serra",1,0.],["polvo",1,0.]]

func _ready() -> void:
	_rng.seed=771
	for i: int in 3:contracts.append(_new_contract())

func _new_contract() -> Dictionary:
	var order: Array=ORDERS[_rng.randi()%ORDERS.size()]
	for c: Dictionary in contracts:
		if c.species==order[0]:order=ORDERS[(ORDERS.find(order)+3)%ORDERS.size()]
	var id: String=order[0]
	var name_text:=_species_name(id)
	var reward:=int(round(_base_value(id)*float(order[1])*(1.6 if float(order[2])>0. else 1.3)/5.)*5)+15
	var buyers: Array[String]=["Dona Cida, da peixaria","o cozinheiro da pousada","um comprador do continente","o restaurante do cais","a fábrica de conservas"]
	return {"species":id,"name":name_text,"count":int(order[1]),"min_weight":float(order[2]),"reward":reward,"buyer":buyers[_rng.randi()%buyers.size()]}

func _species_name(id: String) -> String:
	for item: Resource in game.fishing.SPECIES if game!=null else []:
		if item.id==id:return item.display_name
	var extra: Dictionary=preload("res://scripts/fishing/sea_gear.gd").EXTRA
	if extra.has(id):return str(extra[id][0])
	return id.replace("_"," ")

func _base_value(id: String) -> float:
	for item: Resource in game.fishing.SPECIES if game!=null else []:
		if item.id==id:return (item.min_weight+item.max_weight)*.5*item.value_per_kg
	var extra: Dictionary=preload("res://scripts/fishing/sea_gear.gd").EXTRA
	if extra.has(id):return (float(extra[id][1])+float(extra[id][2]))*.5*float(extra[id][3])
	return 30.

## Count for one of the story measures.
func measure(kind: String) -> int:
	var inv=game.inventory
	match kind:
		"fed","traps":return int(inv.stats.get(kind,0))
		"places":return game.world.village.discovered.size()
		"species":
			var n:=0
			for key: String in inv.encyclopedia:
				if not bool(inv.encyclopedia[key].get("observation",false)):n+=1
			return n
		"contracts":return completed_contracts
		"observed":
			var n:=0
			for key: String in inv.encyclopedia:
				if key.begins_with("monstro_"):n+=1
			return n
		"harpoon":return int(inv.equipment.get("harpoon",0))
		"victories":
			var n:=0
			for key: String in inv.encyclopedia:
				if key.begins_with("vitoria_"):n+=1
			return n
	return 0

func current() -> Array:
	return STORY[step] if step<STORY.size() else []

## Objective text for the HUD.
func objective_text() -> String:
	var s:=current()
	if s.is_empty():return "LENDA DOS MARES\nVocê venceu os três guardiões. O mar é seu."
	var have:=mini(measure(str(s[2])),int(s[3]))
	var counter:=" (%d/%d)"%[have,int(s[3])] if int(s[3])>1 else ""
	return "MISSÃO %d/%d · %s\n%s%s"%[step+1,STORY.size(),str(s[0]).to_upper(),s[1],counter]

func _process(delta: float) -> void:
	if game==null or not game.started:return
	_clock+=delta
	if _clock<1.:return
	_clock=0.
	var s:=current()
	if s.is_empty() or not game.sold_once:return
	if measure(str(s[2]))>=int(s[3]):
		game.inventory.money+=int(s[4]);game.inventory.changed.emit()
		game.hud.notify("Missão concluída: %s · +%d moedas"%[s[0],int(s[4])])
		if game.has_method("save_progress"):game.call_deferred("save_progress")
		game.audio.cue("mission")
		step+=1

# --- Market contracts ----------------------------------------------------------------------------------

func _matches(c: Dictionary,fish: Dictionary) -> bool:
	return str(fish.get("id",fish.get("species_id","")))==str(c.species) and float(fish.get("weight",0.))>=float(c.min_weight)

## How many fish aboard would count for contract i.
func have(i: int) -> int:
	var c: Dictionary=contracts[i];var n:=0
	for fish: Dictionary in game.inventory.catches:
		if _matches(c,fish):n+=1
	return n

func describe(i: int) -> String:
	var c: Dictionary=contracts[i]
	var what:="%d × %s"%[c.count,c.name] if float(c.min_weight)<=0. else "%s de pelo menos %.1f kg"%[c.name,c.min_weight]
	var buyer: String=c.buyer
	return "%s pede %s · %d moedas  (a bordo: %d)"%[buyer.left(1).to_upper()+buyer.substr(1),what,c.reward,mini(have(i),int(c.count))]

func deliver(i: int) -> String:
	if i<0 or i>=contracts.size():return "Pedido indisponível."
	var c: Dictionary=contracts[i]
	if have(i)<int(c.count):return "Ainda falta: %d × %s."%[int(c.count)-have(i),c.name]
	var left:=int(c.count)
	for k: int in range(game.inventory.catches.size()-1,-1,-1):
		if left>0 and _matches(c,game.inventory.catches[k]):game.inventory.catches.remove_at(k);left-=1
	game.inventory.money+=int(c.reward);completed_contracts+=1;game.audio.cue("coins")
	contracts[i]=_new_contract()
	game.inventory.changed.emit()
	return "Pedido entregue: +%d moedas. Um novo pedido foi pregado no quadro."%int(c.reward)
