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
	"rod":{"title":"Vara reforçada · recolhimento +15%","price":65,"service":"gear"},
	"line":{"title":"Linha trançada · tensão -15%","price":55,"service":"gear"},
	"hook":{"title":"Anzol de aço · recolhimento +8%","price":35,"service":"gear"},
	"reel":{"title":"Molinete de longo alcance · lançamento +12 m","price":45,"service":"gear"},
	"engine":{"title":"Melhoria do motor · velocidade +15%","price":110,"service":"workshop"},
	"searchlight":{"title":"Farol de proa · ilumina até 65 m · tecla L","price":60,"service":"workshop"},
	"hull":{"title":"Proteção do casco · reduz dano por impacto 40%","price":80,"service":"workshop"},
	"repair":{"title":"Reparar o casco · integridade 100%","price":18,"service":"workshop"}}
static func buy(id: String, inventory: RefCounted,boat: CharacterBody3D,fishing: Node) -> String:
	if not CATALOG.has(id): return "Produto indisponível."
	var item: Dictionary=CATALOG[id]
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
