extends RefCounted
const Fishing=preload("res://scripts/fishing/fishing_system.gd")
const GOODS: Dictionary={
	"repair_kit":{"title":"Kit de reparo","buy":24,"sell":12},
	"tackle":{"title":"Caixa de anzóis","buy":16,"sell":8},
	"canvas":{"title":"Lona naval","buy":20,"sell":10}}

static func trade(action: String,inventory: RefCounted,boat: CharacterBody3D) -> String:
	var parts:=action.split(":");var kind:=parts[0];var id:=parts[1] if parts.size()>1 else ""
	if kind in ["buy_goods","sell_goods"]:
		if not GOODS.has(id):return "Item indisponível."
		var item: Dictionary=GOODS[id];var count: int=inventory.goods.get(id,0)
		if kind=="buy_goods":
			if inventory.money<int(item.buy):return "Moedas insuficientes."
			inventory.money-=int(item.buy);inventory.goods[id]=count+1
		else:
			if count<=0:return "Você não possui este item."
			inventory.goods[id]=count-1;inventory.money+=int(item.sell)
	elif kind=="use_tackle":
		if inventory.goods.get("tackle",0)<=0:return "Sem caixa de anzóis."
		inventory.goods.tackle-=1;inventory.bait+=6
	elif kind=="craft_kit":
		if inventory.goods.get("canvas",0)<=0 or inventory.materials<2:return "Faltam materiais."
		inventory.goods.canvas-=1;inventory.materials-=2;inventory.goods.repair_kit=inventory.goods.get("repair_kit",0)+1
	elif kind=="use_kit":
		if inventory.goods.get("repair_kit",0)<=0:return "Sem kit de reparo."
		if boat.integrity>=.999:return "Casco intacto."
		inventory.goods.repair_kit-=1;boat.integrity=minf(1.,boat.integrity+.35)
	elif kind=="sell_bait":
		if inventory.bait<=0:return "Sem iscas."
		inventory.bait-=1;inventory.money+=1
	elif kind=="sell_material":
		if inventory.materials<=0:return "Sem materiais."
		inventory.materials-=1;inventory.money+=3
	elif kind=="sell_fish":
		if not id.is_valid_int():return "Captura indisponível."
		var index:=int(id)
		if index<0 or index>=inventory.catches.size():return "Captura indisponível."
		inventory.money+=int(inventory.catches[index].value);inventory.catches.remove_at(index)
	else:return "Ação indisponível."
	inventory.changed.emit();return "Concluído."
const CATALOG: Dictionary={
	"bait":{"title":"6 iscas frescas · mordidas 25% mais rápidas","price":12,"service":"gear"},
	"rod":{"title":"Vara melhor · bambu → fibra → carbono → alto-mar · cada uma abre peixes maiores e outras espécies","price":65,"service":"gear","tiered":true},
	"lights":{"title":"Luzes do barco · 1º lamparina a óleo (qualquer barco) · 2º lâmpadas de convés · tecla L","price":30,"service":"workshop","tiered":true,"max":2},
	"line":{"title":"Linha trançada · tensão -15% por nível","price":55,"service":"gear","tiered":true},
	"hook":{"title":"Anzol de aço · recolhimento +8% por nível","price":35,"service":"gear","tiered":true},
	"reel":{"title":"Molinete de longo alcance · lançamento +12 m por nível","price":45,"service":"gear","tiered":true},
	"engine":{"title":"Melhoria do motor · velocidade +15%","price":110,"service":"workshop"},
	"searchlight":{"title":"Farol de proa · ilumina até 65 m · tecla L","price":60,"service":"workshop"},
	"hull":{"title":"Proteção do casco · reduz dano por impacto 40%","price":80,"service":"workshop"},
	"paint":{"title":"Pintura nova · troca as cores, o pano e a bandeira do barco","price":25,"service":"shipyard"},
	"repair":{"title":"Reparar o casco · integridade 100%","price":18,"service":"workshop"},
	"craft_tackle":{"title":"Montar caixa de anzóis · 2 materiais","price":0,"service":"workshop","craft":{"materials":2,"goods":{},"result":{"goods":{"tackle":1}}}},
	"craft_canvas":{"title":"Costurar lona naval · 3 materiais","price":0,"service":"workshop","craft":{"materials":3,"goods":{},"result":{"goods":{"canvas":1}}}},
	"craft_bait":{"title":"Preparar 6 iscas · 1 material","price":0,"service":"workshop","craft":{"materials":1,"goods":{},"result":{"bait":6}}},
	"feed":{"title":"Saco de ração · 5 punhados para atrair cardumes (tecla C)","price":15,"service":"gear"},
	"net":{"title":"Rede de arremesso · tecla N no barco","price":90,"service":"gear"},
	"gillnet":{"title":"Rede de espera · Shift+N lança da lateral, pesca sozinha, recolha na boia","price":120,"service":"gear"},
	"pots":{"title":"Gaiola de peixe · B sobre um recife pega peixes de recife","price":45,"service":"gear"},
	"winch":{"title":"Guincho de convés · covos até 60 m, recolhe mais rápido (traineira, expedição, escuna)","price":220,"service":"shipyard"},
	"bell":{"title":"Sino de vara · toca quando um peixe pega na vara do suporte","price":20,"service":"gear"},
	"trap":{"title":"Covo para caranguejo e lagosta · tecla B em água rasa","price":40,"service":"gear"},
	"flares":{"title":"3 sinalizadores · tecla Y espanta monstros por um tempo","price":25,"service":"gear"},
	"harpoon_gun":{"title":"Arpão de proa · tecla H enfrenta monstros · com 4 arpões","price":140,"service":"workshop"},
	"harpoons":{"title":"4 arpões para o arpão de proa","price":20,"service":"workshop"},
	"sonar":{"title":"Sonar · tecla O no barco: fundo, cardumes, naufrágios e formas grandes","price":120,"service":"workshop"},
	"sonar2":{"title":"Sonar de longo alcance · alcance dobrado, leitura mais nítida","price":260,"service":"workshop"},
	"diving":{"title":"Máscara e cilindro · 75 s de ar, até 35 m","price":90,"service":"gear"},
	"diving2":{"title":"Equipamento de mergulho profundo · 150 s de ar, até 80 m","price":240,"service":"gear"}}
## Crafting: spends materials (and any goods listed) to produce goods or bait. Recipes live in CATALOG under "craft".
static func _craft(item: Dictionary,inventory: RefCounted) -> String:
	var recipe: Dictionary=item.craft
	var needed_materials: int=int(recipe.get("materials",0))
	if inventory.materials<needed_materials: return "Faltam materiais: precisa de %d."%needed_materials
	var needed_goods: Dictionary=recipe.get("goods",{})
	for good: String in needed_goods:
		if inventory.goods.get(good,0)<int(needed_goods[good]): return "Falta %s para esta montagem."%str(GOODS[good].title).to_lower()
	inventory.materials-=needed_materials
	for good: String in needed_goods: inventory.goods[good]-=int(needed_goods[good])
	var result: Dictionary=recipe.get("result",{})
	for good: String in result.get("goods",{}): inventory.goods[good]=inventory.goods.get(good,0)+int(result.goods[good])
	inventory.bait+=int(result.get("bait",0))
	inventory.changed.emit()
	return "Montagem concluída: "+str(item.title).split(" · ")[0]+"."

## Gear upgrades come in three levels. Each level costs more than the last (base price x current level + 1).
const MAX_LEVEL: int=3
## Boats sold at the boatyard. speed: base top speed (m/s); protection: impact damage factor;
## capacity: net and hold size factor; scale: hull size; hull/top: paint.
## Paint schemes sold at the shipyard: hull, superstructure.
const PAINTS: Array=[[Color("2b4c7e"),Color("f2efe6")],[Color("b8433a"),Color("f4f1e8")],[Color("e9c46a"),Color("264653")],[Color("2a9d8f"),Color("f1faee")],[Color("1d1d1d"),Color("c9a227")],[Color("f4f4f0"),Color("7a1f2b")]]
const BOATS: Dictionary={
	"aurora":{"title":"Lancha Aurora · equilibrada","price":240,"berths":2,"speed":11.,"protection":1.,"capacity":1.,"scale":1.,"handling":{"rudder_rate":2.2,"turn":1.,"accel":2.7,"inertia":.2,"reverse":3.2},"hull":Color("e2d2ad"),"top":Color("364c50")},
	"veloz":{"title":"Lancha Veloz · +35% velocidade, casco leve","price":300,"berths":1,"speed":14.8,"protection":1.25,"capacity":.8,"scale":.94,"handling":{"rudder_rate":2.2,"turn":1.15,"accel":3.6,"inertia":.4,"reverse":3.6},"hull":Color("c0392b"),"top":Color("f2f2ee")},
	"expedicao":{"title":"Barco de Expedição · farol de proa incluso, mais alcance","price":380,"berths":2,"speed":12.6,"protection":.8,"capacity":1.2,"scale":1.08,"handling":{"rudder_rate":1.5,"turn":.95,"accel":2.5,"inertia":.65,"reverse":3.},"hull":Color("2e6b4f"),"top":Color("efe6d2"),"searchlight":true},
	"traineira":{"title":"Traineira Robusta · casco reforçado, rede 60% maior","price":450,"berths":3,"speed":9.6,"protection":.55,"capacity":1.6,"scale":1.18,"handling":{"rudder_rate":1.1,"turn":.8,"accel":1.8,"inertia":1.,"reverse":2.4},"hull":Color("1f4e79"),"top":Color("e8e2d4")},
	"canoa":{"title":"Canoa com Rabeta · leve e barata, leva pouco, sofre no mar aberto","price":120,"berths":1,"speed":8.5,"protection":1.6,"capacity":.45,"scale":1.,"model":"canoa","handling":{"rudder_rate":2.6,"turn":1.35,"accel":3.4,"inertia":.25,"reverse":2.2},"hull":Color("8a5a2b"),"top":Color("c9a46a")},
	"veleiro":{"title":"Chalupa · 16 m, velas redondas (P), convés do leme e cabine do capitão, 3 tripulantes","price":650,"berths":3,"speed":7.,"protection":.9,"capacity":1.15,"scale":1.,"model":"veleiro","handling":{"rudder_rate":1.4,"turn":.9,"accel":1.7,"inertia":.8,"reverse":2.},"hull":Color("f4f4f0"),"top":Color("23395d")},
	"escuna":{"title":"Escuna de Expedição · dois mastros, porão enorme, lenta para manobrar","price":1400,"berths":6,"speed":6.,"protection":.45,"capacity":2.4,"scale":1.,"model":"escuna","handling":{"rudder_rate":.9,"turn":.62,"accel":1.,"inertia":1.6,"reverse":1.4},"hull":Color("1d1d1d"),"top":Color("c9a227")}}

## A new career starts poor: an old canoe with an outboard (rabeta), a bamboo pole, no light, a few coins.
## The lancha, the lamparina and every better rod are bought with the catch.
const START_MONEY: int=35
static func start_career(inventory: RefCounted) -> void:
	inventory.owned_boats.assign(["canoa"]);inventory.boat_id="canoa"
	inventory.equipment["lights"]=0;inventory.equipment["rod"]=0
	inventory.money=START_MONEY

## What a sinking costs. Proper hulls are towed in and patched; a canoe breaks up and is gone. With no other
## boat left the boatyard lends an old canoe, paid for out of what you have.
const LOAN_FEE: int=50
static func wreck(inventory: RefCounted) -> String:
	if str(inventory.boat_id)!="canoa":return ""
	inventory.owned_boats.erase("canoa")
	if inventory.owned_boats.is_empty():
		var fee:=mini(int(inventory.money),LOAN_FEE);inventory.money-=fee
		inventory.owned_boats.append("canoa");inventory.boat_id="canoa"
		return "A canoa se desfez nas ondas. O estaleiro te arranja uma canoa velha por %d moedas."%fee
	inventory.boat_id=str(inventory.owned_boats[0])
	return "A canoa se desfez nas ondas e se perdeu. Você volta a usar %s."%str(BOATS[inventory.boat_id].title).get_slice(" ·",0)

static func buy_boat(id: String,inventory: RefCounted,boat: CharacterBody3D,fishing: Node) -> String:
	if not BOATS.has(id):return "Barco indisponível."
	var data: Dictionary=BOATS[id]
	if id in inventory.owned_boats:
		if inventory.boat_id==id:return "Você já está usando %s."%str(data.title).get_slice(" ·",0)
		inventory.boat_id=id;apply(inventory,boat,fishing);inventory.changed.emit()
		return "Agora você navega com %s."%str(data.title).get_slice(" ·",0)
	if inventory.money<int(data.price):return "Moedas insuficientes: %s custa %d."%[str(data.title).get_slice(" ·",0),int(data.price)]
	inventory.money-=int(data.price);inventory.owned_boats.append(id);inventory.boat_id=id
	boat.integrity=1.;apply(inventory,boat,fishing);inventory.changed.emit()
	return "Barco novo: %s. Ele já está na vaga."%str(data.title).get_slice(" ·",0)

static func level_of(id: String,inventory: RefCounted) -> int:
	return int(inventory.equipment.get(id,0))

static func next_cost(id: String,inventory: RefCounted) -> int:
	return int(CATALOG[id].price)*(level_of(id,inventory)+1)

static func buy(id: String, inventory: RefCounted,boat: CharacterBody3D,fishing: Node) -> String:
	if not CATALOG.has(id): return "Produto indisponível."
	var item: Dictionary=CATALOG[id]
	if item.has("craft"):return _craft(item,inventory)
	if item.get("tiered",false):
		var level:=level_of(id,inventory)
		var top: int=int(item.get("max",MAX_LEVEL))
		if level>=top: return "Nível máximo já alcançado."
		if id=="lights" and level==1 and str(inventory.boat_id)=="canoa":return "A canoa não tem bateria para lâmpadas: a lamparina é o que ela comporta."
		var cost:=next_cost(id,inventory)
		if inventory.money<cost: return "Moedas insuficientes para o nível %d (%d moedas)."%[level+1,cost]
		inventory.money-=cost;inventory.equipment[id]=level+1
		apply(inventory,boat,fishing);inventory.changed.emit()
		if id=="rod":return "Nova vara: %s. Peixes maiores e outras espécies agora mordem."%Fishing.ROD_NAMES[level+1]
		if id=="lights":return ["","Lamparina a óleo pendurada no barco: luz quente para a noite (L acende).","Lâmpadas de convés instaladas (L acende)."][level+1]
		return "Melhoria concluída: %s, nível %d/%d."%[str(item.title).get_slice(" ·",0),level+1,top]
	if id=="harpoon_gun" and inventory.equipment.get("harpoon",0)>=1: return "Você já tem o arpão de proa."
	if id in ["sonar","sonar2","diving","diving2"]:
		var key: String=id.trim_suffix("2");var want:=2 if id.ends_with("2") else 1
		if int(inventory.equipment.get(key,0))>=want:return "Você já tem este equipamento."
		if want==2 and int(inventory.equipment.get(key,0))<1:return "Compre primeiro o modelo básico."
		if inventory.money<int(item.price):return "Moedas insuficientes. Venda capturas ou explore os baús da ilha."
		inventory.money-=int(item.price);inventory.equipment[key]=want;inventory.changed.emit()
		return "Instalado: %s."%str(item.title).get_slice(" ·",0)
	if id=="harpoons" and inventory.equipment.get("harpoon",0)<1: return "Instale primeiro o arpão de proa."
	if id=="winch" and not str(inventory.boat_id) in ["traineira","escuna","expedicao"]:return "Este barco não comporta um guincho (traineira, expedição ou escuna)."
	if id in inventory.equipment and inventory.equipment[id]>=1 and not id in ["trap","pots"]: return "Você já possui esta melhoria."
	if id=="repair" and boat.integrity>=.999: return "O casco já está em boas condições."
	if inventory.money<int(item.price): return "Moedas insuficientes. Venda capturas ou explore os baús da ilha."
	inventory.money-=int(item.price)
	if id=="bait": inventory.bait+=6
	elif id=="feed": inventory.feed+=5
	elif id=="trap": inventory.traps+=1
	elif id=="flares": inventory.flares+=3
	elif id=="harpoon_gun": inventory.equipment["harpoon"]=1;inventory.harpoons+=4
	elif id=="harpoons": inventory.harpoons+=4
	elif id=="repair": boat.integrity=1.
	elif id=="paint": inventory.boat_paint+=1
	elif id=="pots": inventory.equipment["pots"]=int(inventory.equipment.get("pots",0))+1
	else: inventory.equipment[id]=1
	apply(inventory,boat,fishing);inventory.changed.emit()
	return "Compra concluída: "+str(item.title)
static func apply(inventory: RefCounted,boat: CharacterBody3D,fishing: Node) -> void:
	var hull_data: Dictionary=BOATS.get(inventory.boat_id,BOATS.aurora)
	boat.max_speed=float(hull_data.speed)*(1.+float(inventory.equipment.engine)*.15)
	# The hold: how many catches the boat carries before you must sell (bigger hulls carry more).
	inventory.hold_limit=int(round(14.*float(hull_data.capacity)))
	# Hired crew keep the catch in order: two more places per sailor aboard.
	var crew_size: int=(inventory.get("crew") as Array).size() if inventory.get("crew")!=null else 0
	inventory.hold_limit+=2*mini(crew_size,int(hull_data.get("berths",0)))
	fishing.rod_bonus=float(inventory.equipment.rod)*.15
	fishing.line_bonus=float(inventory.equipment.line)*.15
	fishing.hook_bonus=float(inventory.equipment.hook)*.08
	fishing.cast_range_bonus=float(inventory.equipment.get("reel",0))*12.
	boat.searchlight_upgraded=inventory.equipment.get("searchlight",0)>0 or hull_data.get("searchlight",false)
	boat.hull_protection=float(hull_data.protection)*(.6 if inventory.equipment.get("hull",0)>0 else 1.)
	boat.capacity=float(hull_data.capacity)
	if "handling" in boat:boat.handling=(hull_data.get("handling",BOATS.aurora.handling) as Dictionary).duplicate()
	var paint: int=int(inventory.get("boat_paint")) if inventory.get("boat_paint")!=null else 0
	if boat.has_method("set_hull_model"):boat.set_hull_model(str(hull_data.get("model","tripo")),11+paint)
	var colors: Array=[hull_data.hull,hull_data.top] if paint==0 else PAINTS[(paint-1)%PAINTS.size()]
	if boat.has_method("set_livery"):boat.set_livery(colors[0],colors[1],float(hull_data.scale))
	if boat.has_method("set_winch"):boat.set_winch(int(inventory.equipment.get("winch",0))>0 and str(inventory.boat_id) in ["traineira","escuna","expedicao"])
	if "light_level" in boat:boat.light_level=mini(int(inventory.equipment.get("lights",2)),1 if str(inventory.boat_id)=="canoa" else 2)
	boat.update_lights()
