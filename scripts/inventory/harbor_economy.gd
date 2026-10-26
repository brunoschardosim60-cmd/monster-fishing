extends RefCounted
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
	"rod":{"title":"Vara reforçada · recolhimento +15% por nível","price":65,"service":"gear","tiered":true},
	"line":{"title":"Linha trançada · tensão -15% por nível","price":55,"service":"gear","tiered":true},
	"hook":{"title":"Anzol de aço · recolhimento +8% por nível","price":35,"service":"gear","tiered":true},
	"reel":{"title":"Molinete de longo alcance · lançamento +12 m por nível","price":45,"service":"gear","tiered":true},
	"engine":{"title":"Melhoria do motor · velocidade +15%","price":110,"service":"workshop"},
	"searchlight":{"title":"Farol de proa · ilumina até 65 m · tecla L","price":60,"service":"workshop"},
	"hull":{"title":"Proteção do casco · reduz dano por impacto 40%","price":80,"service":"workshop"},
	"repair":{"title":"Reparar o casco · integridade 100%","price":18,"service":"workshop"},
	"craft_tackle":{"title":"Montar caixa de anzóis · 2 materiais","price":0,"service":"workshop","craft":{"materials":2,"goods":{},"result":{"goods":{"tackle":1}}}},
	"craft_canvas":{"title":"Costurar lona naval · 3 materiais","price":0,"service":"workshop","craft":{"materials":3,"goods":{},"result":{"goods":{"canvas":1}}}},
	"craft_bait":{"title":"Preparar 6 iscas · 1 material","price":0,"service":"workshop","craft":{"materials":1,"goods":{},"result":{"bait":6}}}}
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
		if level>=MAX_LEVEL: return "Nível máximo já alcançado."
		var cost:=next_cost(id,inventory)
		if inventory.money<cost: return "Moedas insuficientes para o nível %d (%d moedas)."%[level+1,cost]
		inventory.money-=cost;inventory.equipment[id]=level+1
		apply(inventory,boat,fishing);inventory.changed.emit()
		return "Melhoria concluída: %s, nível %d/%d."%[str(item.title),level+1,MAX_LEVEL]
	if id in inventory.equipment and inventory.equipment[id]>=1: return "Você já possui esta melhoria."
	if id=="repair" and boat.integrity>=.999: return "O casco já está em boas condições."
	if inventory.money<int(item.price): return "Moedas insuficientes. Venda capturas ou explore os baús da ilha."
	inventory.money-=int(item.price)
	if id=="bait": inventory.bait+=6
	elif id=="repair": boat.integrity=1.
	else: inventory.equipment[id]=1
	apply(inventory,boat,fishing);inventory.changed.emit()
	return "Compra concluída: "+str(item.title)
static func apply(inventory: RefCounted,boat: CharacterBody3D,fishing: Node) -> void:
	boat.max_speed=11.*(1.+float(inventory.equipment.engine)*.15)
	fishing.rod_bonus=float(inventory.equipment.rod)*.15
	fishing.line_bonus=float(inventory.equipment.line)*.15
	fishing.hook_bonus=float(inventory.equipment.hook)*.08
	fishing.cast_range_bonus=float(inventory.equipment.get("reel",0))*12.
	boat.searchlight_upgraded=inventory.equipment.get("searchlight",0)>0
	boat.hull_protection=.6 if inventory.equipment.get("hull",0)>0 else 1.
	boat.update_lights()
