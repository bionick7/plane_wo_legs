extends Area3D

@onready var hit_explosion = $HitExplosion

signal bullet_hit(pos: Vector3, vel: Vector3)

func on_bullet_hit(pos: Vector3, vel: Vector3):
	hit_explosion.global_position = pos
	hit_explosion.emitting = true
	emit_signal("bullet_hit", pos, vel)
