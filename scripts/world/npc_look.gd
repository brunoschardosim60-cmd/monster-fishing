extends RefCounted
## Appearance table for villagers, fishers, vendors, walkers and keepers. A look is a plain Dictionary understood by
## imported_angler.gd#apply_look. `for_id` is deterministic: the same id always yields the same person.
const PALETTES: Array[Dictionary]=[
	{"name":"azul-marinho","cloth_hue":0.,"cloth_sat_mul":1.,"cloth_sat_add":0.,"cloth_val_mul":1.},
	{"name":"vermelho","cloth_hue":.40,"cloth_sat_mul":1.,"cloth_sat_add":.17,"cloth_val_mul":1.27},
	{"name":"mostarda","cloth_hue":.10,"cloth_sat_mul":1.,"cloth_sat_add":.21,"cloth_val_mul":1.36},
	{"name":"verde","cloth_hue":.30,"cloth_sat_mul":1.,"cloth_sat_add":.15,"cloth_val_mul":1.23},
	{"name":"roxo","cloth_hue":.70,"cloth_sat_mul":1.,"cloth_sat_add":.15,"cloth_val_mul":1.27},
	{"name":"turquesa","cloth_hue":.92,"cloth_sat_mul":1.,"cloth_sat_add":.16,"cloth_val_mul":1.27},
	{"name":"areia","cloth_hue":.05,"cloth_sat_mul":.5,"cloth_sat_add":.08,"cloth_val_mul":1.58},
	{"name":"carvao","cloth_hue":0.,"cloth_sat_mul":.3,"cloth_sat_add":0.,"cloth_val_mul":.93}]
const SKINS: Array[Vector3]=[Vector3(1.55,1.32,1.2),Vector3(1.8,1.5,1.32),Vector3(1.2,.95,.8),Vector3(.9,.68,.55),Vector3(1.5,1.15,.95)]
const HAIRS: Array[Vector3]=[Vector3(1.,1.,1.),Vector3(1.9,1.35,.9),Vector3(4.2,3.2,1.7),Vector3(3.4,3.4,3.5),Vector3(3.6,1.5,.7),Vector3(.6,.55,.55)]
const HEADWEAR: Array[String]=["fisher","beanie","straw","none","bandana","beanie","fisher","straw"]
const TINTS: Array[Color]=[Color("40566b"),Color("b5483a"),Color("d0a23f"),Color("3f7d5b"),Color("6a4f8c"),Color("e6dfcb")]

static func for_id(id: int) -> Dictionary:
	var look: Dictionary=PALETTES[id%PALETTES.size()].duplicate()
	look["skin"]=SKINS[(id*2+id/PALETTES.size())%SKINS.size()]
	look["hair"]=HAIRS[(id*7+3)%HAIRS.size()]
	look["headwear"]=HEADWEAR[(id*3+1)%HEADWEAR.size()]
	look["headwear_tint"]=TINTS[(id*5+2)%TINTS.size()]
	look["backpack"]=(id%3)!=1
	look["height"]=.93+float((id*7)%9)*.0175
	look["build"]=.96+float((id*5)%7)*.012
	# Stylised body (fisher in oilskins, sailor, innkeeper, old captain, market women, cabin boy, docker).
	look["body"]=preload("res://scripts/visuals/folk_body.gd").path_for(id)
	return look
