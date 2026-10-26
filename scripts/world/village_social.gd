extends Node
## Makes villagers notice each other. Now and then a walker heads over to a neighbour, both stop,
## face each other and trade a few lines (shown as speech bubbles while the camera is close).
const SEARCH_INTERVAL: float=1.5
const MEET_CHANCE: float=.35
const MEET_RANGE: float=16.
const MEET_TIMEOUT: float=10.
const CHAT_TIME: float=5.5
const LINES_A: Array[String]=["Pescou alguma coisa hoje?","O mar tá calmo.","Vai chover à tarde, viu?","Preciso remendar essa rede.","Viu o barco novo chegando?","A maré tá subindo.","Bom dia, vizinho!","Nada hoje, mas amanhã vai!"]
const LINES_B: Array[String]=["Ainda não, tá com cara de peixe.","Tá bonito, mas esfriou.","Hum... acho que sim.","Depois eu vejo isso.","Vi sim, é grandão!","Vou esperar a maré.","Bom dia! Tudo certo?","Vamos ver, vamos ver."]
## Filled by harbor_village with its residents (same parent, so local positions are comparable).
var residents: Array=[]
var clock: float=0.
var rng:=RandomNumberGenerator.new()
func _ready() -> void:
	rng.seed=7
func _process(delta: float) -> void:
	# A walker that reached its partner starts the chat, and both speak their line.
	for r in residents:
		var partner=r.meet_with
		if partner==null or r.talk_timer>0. or partner.talk_timer>0.:continue
		if r.position.distance_to(partner.position)<=r.TALK_RANGE+.4:
			var i: int=rng.randi()%LINES_A.size()
			r.start_talk(partner,LINES_A[i],CHAT_TIME);partner.start_talk(r,LINES_B[i],CHAT_TIME)
	clock+=delta
	if clock<SEARCH_INTERVAL:return
	clock=0.
	for a in residents:
		# Someone resting at a destination stays put; only walkers start a meeting.
		if a.talk_timer>0. or a.meet_with!=null or a.route.size()<2 or a.wait>0.:continue
		for b in residents:
			if b==a or b.talk_timer>0. or b.route.size()<2:continue
			if a.position.distance_to(b.position)>MEET_RANGE:continue
			if rng.randf()<MEET_CHANCE:
				a.request_meet(b,MEET_TIMEOUT);b.start_hold(MEET_TIMEOUT)
				return
