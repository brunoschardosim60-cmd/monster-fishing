extends RefCounted
const CATALOG: Dictionary={
	"bait":{"title":"6 iscas frescas · mordidas 25% mais rápidas","price":12,"service":"gear"},
	"rod":{"title":"Vara reforçada · recolhimento +15%","price":65,"service":"gear"},
	"line":{"title":"Linha trançada · tensão -15%","price":55,"service":"gear"},
	"hook":{"title":"Anzol de aço · recolhimento +8%","price":35,"service":"gear"},
	"engine":{"title":"Melhoria do motor · velocidade +15%","price":110,"service":"workshop"},
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
