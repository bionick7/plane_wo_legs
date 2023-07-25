extends Area3D

@export_range(0, 10, 0.01, "suffix:s") var vulnerability_cooldown = 0.5

@onready var hit_explosion = $HitExplosion

var accept_hits = true

signal bullet_hit(pos: Vector3, vel: Vector3)

func on_bullet_hit(pos: Vector3, vel: Vector3) -> void:
	if not accept_hits:
		return
	hit_explosion.global_position = pos
	hit_explosion.emitting = true
	emit_signal("bullet_hit", pos, vel)
	accept_hits = false
	get_tree().create_timer(vulnerability_cooldown).timeout.connect(func(): accept_hits = true)
