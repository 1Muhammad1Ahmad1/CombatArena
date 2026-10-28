extends RefCounted
## The three playable maps.

const MAPS := [
	{
		"name": "INDUSTRIAL WAREHOUSE", "range": "CLOSE / MEDIUM RANGE",
		"desc": "Containers, catwalks and tight office corridors inside a dusty steel hall.",
		"script": "res://scripts/maps/map_warehouse.gd",
		"color_a": Color(0.36, 0.38, 0.4), "color_b": Color(0.85, 0.5, 0.12),
	},
	{
		"name": "URBAN WARFARE", "range": "MEDIUM RANGE",
		"desc": "Streets, alleys, barricades and a rooftop overlooking the crossroads.",
		"script": "res://scripts/maps/map_urban.gd",
		"color_a": Color(0.3, 0.36, 0.46), "color_b": Color(0.62, 0.27, 0.2),
	},
	{
		"name": "DESERT OUTPOST", "range": "LONG RANGE",
		"desc": "A fortified compound with watchtowers and wide open sightlines.",
		"script": "res://scripts/maps/map_desert.gd",
		"color_a": Color(0.78, 0.64, 0.42), "color_b": Color(0.36, 0.38, 0.26),
	},
]
