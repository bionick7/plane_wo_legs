class_name Hitbox
extends Area3D

signal hit_by_bullet(pos: Vector3, vel: Vector3)
signal hit_by_missile(pos: Vector3, vel: Vector3)
signal dammage_taken(dmg: int)
signal died(cause: String)

@export_range(0, 10, 0.01, "suffix:s") var vulnerability_cooldown = 0.5
@export_range(0, 10, 0.01, "or_greater", "exp", "suffix:1/s") var health_regen_rate = 0.0
@export var reset_regen_after_hit: bool = true
@export var max_health: int
@export var invulnerable: bool

@onready var hit_explosion = $HitExplosion
@onready var health = max_health

var regen_health: float = 0.0
var accept_hits = true
var _healthbar: ShaderMaterial

func _process(dt: float):
	if health_regen_rate > 0 and health != max_health:
		regen_health += health_regen_rate * dt
		if regen_health > 1:
			regen_health -= 1
			health = clamp(health + 1, 0, max_health)
		_update_healthbar()
		
		Logger.write_line("regen_health %f" % regen_health)

func set_healthbar(mat: ShaderMaterial) -> void:
	var uniforms = mat.shader.get_shader_uniform_list()
	assert(["total_hp", "current_hp", "regen_progress"].all(
		func(y): return uniforms.any(func(x): return x.name == y)  # pog
	), "invalid healthbar shader provided")
	_healthbar = mat
	_update_healthbar()

func on_bullet_hit(pos: Vector3, vel: Vector3) -> void:
	if not accept_hits:
		return
	hit_explosion.global_position = pos
	hit_explosion.emitting = true
	emit_signal("hit_by_bullet", pos, vel)
	
	var dmg: int = 1
	health = clamp(health - dmg, 0, max_health)
	if reset_regen_after_hit:
		regen_health = 0
	emit_signal("dammage_taken", dmg)
	_update_healthbar()
	if health <= 0 and not invulnerable:
		emit_signal("died", "0HP (bullet hit)")
		
	accept_hits = false
	get_tree().create_timer(vulnerability_cooldown).timeout.connect(func(): accept_hits = true)

func on_missile_hit(dmg: int, pos: Vector3, vel: Vector3) -> void:
	# Missiles are responsible for their own impact effects
	emit_signal("hit_by_missile", pos, vel)
	
	health = clamp(health - dmg, 0, max_health)
	if reset_regen_after_hit:
		regen_health = 0
	emit_signal("dammage_taken", dmg)
	_update_healthbar()
	if health <= 0 and not invulnerable:
		emit_signal("died", "0HP (missile hit)")

func _update_healthbar() -> void:
	if not is_instance_valid(_healthbar):
		return
	_healthbar.set_shader_parameter("total_hp", max_health)
	_healthbar.set_shader_parameter("current_hp", health)
	_healthbar.set_shader_parameter("regen_progress", regen_health)
