extends GPUParticles3D

const MAX_BULLET_PATH = 1024

@export var muzzle_velocity = 100
@export var self_area: Area3D
@export var draw: bool

var bullet_path_pos = PackedVector3Array()
var bullet_path_vel = PackedVector3Array()
var bullet_path_active = PackedInt64Array()

var bullet_path_newest_index = 0

var bullets_include_centrifugal_force = false
var bullets_include_coreolis_force = false

@onready var prev_pos = global_position
@onready var common_physics = $"/root/CommonPhysics"
@onready var draw_mesh

func _init():
	bullet_path_pos.resize(MAX_BULLET_PATH)
	bullet_path_vel.resize(MAX_BULLET_PATH)
	bullet_path_active.resize(MAX_BULLET_PATH / 64)

func _ready():
	if $GunDraw != null and draw:
		draw_mesh = $GunDraw.mesh
		$GunDraw.global_transform = Transform3D.IDENTITY
	emitting = false
	process_material.set_shader_parameter("include_centrifugal_force", bullets_include_centrifugal_force)
	process_material.set_shader_parameter("include_coreolis_force", bullets_include_centrifugal_force)

func _process(dt: float):
	var global_start_velocity = (global_position - prev_pos) / dt + global_transform.basis.y * muzzle_velocity
	process_material.set_shader_parameter("global_start_velocity", global_start_velocity)
	prev_pos = global_position
	var ss = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 1 << 2)
	query.collide_with_areas = true
	if is_instance_valid(self_area):
		query.exclude = [self_area.get_rid()]
	var count = 0
	for i in range(MAX_BULLET_PATH):
		if (bullet_path_active[i / 64]) & (1 << (i % 64)) != 0:
			var acc = Vector3.ZERO
			if bullets_include_centrifugal_force: acc += common_physics.get_centrifugal_acc(bullet_path_pos[i])
			if bullets_include_coreolis_force: acc += common_physics.get_coreolis_acc(bullet_path_vel[i])
			bullet_path_vel[i] += acc * dt
			var new_pos = bullet_path_pos[i] + bullet_path_vel[i] * dt
			query.from = bullet_path_pos[i]
			query.to = new_pos
			var raycast_result = ss.intersect_ray(query)
			if raycast_result:
				var collider: Area3D = raycast_result.collider
				if collider.is_in_group("Hitbox"):
					collider.on_bullet_hit(raycast_result.position, bullet_path_vel[i])
				
			else:
				bullet_path_pos[i] = new_pos
				
			if raycast_result or common_physics.is_oob(bullet_path_pos[i]):
				bullet_path_active[i / 64] &= ~(1 << (i % 64))  # Resets the active flag
			else:
				count += 1
	
	if emitting:
		bullet_path_pos[bullet_path_newest_index] = global_position
		bullet_path_vel[bullet_path_newest_index] = global_start_velocity
		bullet_path_active[bullet_path_newest_index / 64] |= 1 << (bullet_path_newest_index % 64)
		bullet_path_newest_index = (bullet_path_newest_index + 1) % MAX_BULLET_PATH
	
	if draw_mesh != null:
		draw_mesh.clear_surfaces()
		#var any_active_test = 0
		#for i in range(MAX_BULLET_PATH/64): any_active_test |= bullet_path_active[i]
		if count > 1:
			draw_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for i in range(MAX_BULLET_PATH):
				if (bullet_path_active[i / 64]) & (1 << (i % 64)) != 0:
					draw_mesh.surface_add_vertex(bullet_path_pos[i])
			draw_mesh.surface_end()

func start_fire():
	emitting = true

func cease_fire():
	emitting = false
