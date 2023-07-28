@tool
extends MeshInstance3D

@export var voronoi_generator: VoronoiGenerator
@export var cloud_parameters: CloudParameters

@export var resync_material_to_resource: bool:
	set(x): sync_to_resource()
	
@export var resync_resource_to_material: bool:
	set(x): sync_to_material()

func _ready():
	sync_to_resource()
	
func sync_to_resource():
	assert(is_instance_valid(material_override), "Postprocessing must have override material")
	if not is_instance_valid(voronoi_generator.voronoi):
		voronoi_generator.load_images_at(voronoi_generator.save_path)
	else:
		material_override.set_shader_parameter("noise", voronoi_generator.voronoi)
		
	cloud_parameters.sync_material_to_self(material_override)

func sync_to_material():
	assert(is_instance_valid(material_override), "Postprocessing must have override material")
	cloud_parameters.sync_self_to_material(material_override)
