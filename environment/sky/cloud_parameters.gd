@tool
class_name CloudParameters
extends Resource

var _layer_mid = 0
var _layer_thickness = 0

@export_range(0, 1) var threshhold = 0.1
@export var cloud_flatten = 0.0
@export var cloud_cover_speed = 0.001
@export var noise_weights = Vector4(0.633, 0.155, 0.072, 0)
@export var noise_weights_detail = Vector4(0.013, 0.023, 0.034, -0.007)
@export_range(0, 4000, 1, "suffix:m") var layer_mid: float: 
	get: return _layer_mid
	set(x): 
		_layer_mid = x
		RenderingServer.global_shader_parameter_set("layer_mid", x)
	
@export_range(0, 4000, 1, "suffix:m") var layer_thickness: float:
	get: return _layer_thickness
	set(x): 
		_layer_thickness = x
		RenderingServer.global_shader_parameter_set("layer_thickness", x)
		
@export var coverage_texture: Texture2D

func sync_material_to_self(material: ShaderMaterial) -> void:
	material.set_shader_parameter("cloud_flatten", cloud_flatten)
	material.set_shader_parameter("cloud_cover_speed", cloud_cover_speed)
	material.set_shader_parameter("noise_weights", noise_weights)
	material.set_shader_parameter("noise_weights_detail", noise_weights_detail)
	material.set_shader_parameter("threshhold", threshhold)

func sync_self_to_material(material: ShaderMaterial) -> void:
	cloud_flatten = material.get_shader_parameter("cloud_flatten")
	cloud_cover_speed = material.get_shader_parameter("cloud_cover_speed")
	noise_weights = material.get_shader_parameter("noise_weights")
	noise_weights_detail = material.get_shader_parameter("noise_weights_detail")
	threshhold = material.get_shader_parameter("threshhold")
