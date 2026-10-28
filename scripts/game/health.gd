extends Node
## Shared health component used by the player and the bots.
## Guarantees a single `died` emission per life.

signal damaged(amount: float, source: Node, headshot: bool, from_pos: Vector3)
signal died(source: Node)

var max_hp := 100.0
var hp := 100.0
var dead := false


func reset() -> void:
	hp = max_hp
	dead = false


func apply_damage(amount: float, source: Node, headshot := false, from_pos := Vector3.ZERO) -> bool:
	if dead or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	damaged.emit(amount, source, headshot, from_pos)
	if hp <= 0.0:
		dead = true
		died.emit(source)
	return true


func heal(amount: float) -> void:
	if not dead:
		hp = minf(max_hp, hp + amount)
