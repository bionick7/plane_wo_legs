class_name FlightModel
extends Resource

@export_category("Symetric Coefficients")
@export_group("Drag")
@export var C_D_0 : float
@export var oswald : float = 1
@export var C_D_br : float
@export var C_X_q : float
@export var C_X_δe : float

@export_group("Lift")
@export var C_L_0 : float
@export var C_L_α : float
@export var C_Z_q : float
@export var C_Z_δe : float

@export_group("Pitch")
@export var C_m_ac : float
@export var C_m_q : float
@export var C_m_α_dot : float
@export var C_m_δe : float
@export var C_m_br : float

@export_category("Asymetric Coefficients")
@export_group("Y")
@export var C_Y_0 : float
@export var C_Y_β : float
@export var C_Y_p : float
@export var C_Y_r : float
@export var C_Y_δa : float
@export var C_Y_δr : float

@export_group("Roll")
@export var C_l_0 : float
@export var C_l_β : float
@export var C_l_p : float
@export var C_l_r : float
@export var C_l_δa : float
@export var C_l_δr : float

@export_group("Yaw")
@export var C_n_0 : float
@export var C_n_β : float
@export var C_n_p : float
@export var C_n_r : float
@export var C_n_δa : float
@export var C_n_δr : float

@export_group("Geometry")
@export var c : float
@export var b : float
@export var canard_surface_ratio : float
@export var x_cg : float
@export var x_ac : float
@export var x_c_ac : float

@export_group("Stall")
@export var stall_enabled: bool
@export var stall_affects_roll: bool
@export var stall_start : float
@export var stall_full : float

var S
var A
var α0

var stall_progress = 0

func init() -> void:
	S = b*c
	A = b/c
	var C_L_α_c = C_L_α
	var np = x_ac + C_L_α_c / C_L_α * canard_surface_ratio * (x_c_ac - x_ac)
	print("neutral point: %5.3f m" % np)
	
func update_stall_progress(α: float, dt: float):
	if stall_enabled:
		var stall_region = smoothstep(deg_to_rad(stall_start), deg_to_rad(stall_full), abs(α)) ** 2
		var recovery = .5 * (1. - stall_region)
		stall_progress = clamp(stall_progress - dt * recovery, stall_region, 1.0)
	else:
		stall_progress = 0

func lift_slope(α: float) -> float:
	var α_true = α + C_L_0 / C_L_α
	return lerp(C_L_α * α_true, sin(2 * α_true), stall_progress)
	
func lift_slope_canard(α: float, δe: float) -> float:
	var α_true = α - δe
	return lerp(C_L_α * α_true, sin(2 * α_true), stall_progress)

func drag_slope(α: float) -> float:
	return lerp(C_D_0, sin(abs(α)), stall_progress)
	
func get_trim(α: float) -> float:
	#var wing_contr = (C_L_0 + C_L_α * α) * (x_cg - x_ac) / c + C_m_ac
	#var canard_contr = (C_L_α * α) * (x_cg - x_c_ac) / c * canard_surface_ratio
	#var Cm = wing_contr + canard_contr
	#return -Cm / C_m_δe
	var wing_contr = lift_slope(α) * (x_cg - x_ac) / c + C_m_ac
	var canard_contr = lift_slope_canard(α, 0) * (x_cg - x_c_ac) / c * canard_surface_ratio
	var Cm = wing_contr + canard_contr
	return -Cm / C_m_δe

func Cl(β: float, p: float, r: float, δr: float, δa: float) -> float:
	δa *= (1. - stall_progress)
	δr *= (1. - stall_progress)
	var res = C_l_0 + C_l_β * β + C_l_p * p + C_l_r * r + C_l_δr * δr + C_l_δa * δa
	if stall_affects_roll:
		res *= smoothstep(0, .5, stall_progress) * smoothstep(1, .5, stall_progress) * .03
	return res

func Cm(α: float, α_dot: float, q: float, δe: float, br: float) -> float:
	var wing_contr = lift_slope(α) * (x_cg - x_ac) / c + C_m_ac
	var canard_contr = lift_slope_canard(α, δe) * (x_cg - x_c_ac) / c * canard_surface_ratio
	return wing_contr + canard_contr + C_m_q * q + C_m_br * br + C_m_α_dot * α_dot
	
func Cn(β: float, p: float, r: float, δr: float, δa: float) -> float:
	δa *= (1. - stall_progress)
	δr *= (1. - stall_progress)
	return C_n_0 + C_n_β * β + C_n_p * p + C_n_r * r + C_n_δr * δr + C_n_δa * δa

func Cx(α: float, q: float, δe: float, br: float) -> float:
	var cL = lift_slope(α)
	var cD = drag_slope(α) + cL*cL / (PI * A * oswald) + C_D_br * br
	return -cos(α) * cD + sin(α) * cD + C_X_q * q + C_X_δe * δe

func Cy(α: float, β: float, p: float, r: float, δr: float, δa: float, br: float) -> float:
	δa *= (1. - stall_progress)
	δr *= (1. - stall_progress)
	var cL = lift_slope(α)
	var cD = drag_slope(α) + cL*cL / (PI * A * oswald) + C_D_br * br
	return sin(β) * cD + C_Y_0 + C_Y_β * β + C_Y_p * p + C_Y_r * r + C_Y_δr * δr + C_Y_δa * δa
	
func Cz(α: float, q: float, δe: float, br: float) -> float:
	var cL = lift_slope(α)
	var cD = drag_slope(α) + cL*cL / (PI * A * oswald) + C_D_br * br
	return -cos(α) * cL + sin(α) * cD + C_X_q * q + C_X_δe * δe
