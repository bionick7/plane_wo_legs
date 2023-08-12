extends AcceptDialog

enum { HIDDEN, ASK_GAMEPAD, ASK_FLIGHTSTICK }

@export var quick_select: bool = false

var state = HIDDEN

var current_gamepad: String = ""
var current_flightstick: String = ""

signal input_configured(input_conig: Array[Dictionary])

func _ready():
	add_button("Clear Input", true, "clear")

func _input(event):
	if event.device < 0:
		return
	if not (event is InputEventJoypadMotion or event is InputEventJoypadButton):
		return
	if event is InputEventJoypadMotion and event.axis_value < 0.2:
		return
	if state == ASK_GAMEPAD:
		current_gamepad = Input.get_joy_name(event.device)
		dialog_text = "Actuate primary gamepad.\nCurrent: \"%s\"" % current_gamepad
		if quick_select:
			_on_confirmed()
	elif state == ASK_FLIGHTSTICK:
		if quick_select and Input.get_joy_name(event.device) == current_gamepad:
			return
		current_flightstick = Input.get_joy_name(event.device)
		dialog_text = "Actuate primary flightstick.\nCurrent: \"%s\"" % current_flightstick
		if quick_select:
			_on_confirmed()

func _on_about_to_popup():
	current_gamepad = ""
	current_flightstick = ""
	state = ASK_GAMEPAD
	get_tree().paused = true
	dialog_text = "Actuate primary gamepad.\nCurrent: NONE"

func _on_confirmed():
	match state:
		HIDDEN:
			push_error("Should not be able to press 'next'")
			hide()
		ASK_GAMEPAD:
			state = ASK_FLIGHTSTICK
			dialog_text = "Actuate primary flightstick.\nCurrent: NONE"
		ASK_FLIGHTSTICK:
			state = HIDDEN
			hide()
			var input_config: Array[Dictionary] = []
			if current_gamepad != "":
				input_config.append({
					name = current_gamepad,
					is_flight_stick = false
				})
			if current_flightstick != "":
				input_config.append({
					name = current_flightstick,
					is_flight_stick = true
				})
			get_tree().paused = false
			emit_signal("input_configured", input_config)

func _on_custom_action(action: String):
	if action == "clear":
		match state:
			ASK_GAMEPAD:
				current_gamepad = ""
				dialog_text = "Actuate primary gamepad.\nCurrent: NONE"
			ASK_FLIGHTSTICK:
				current_flightstick = ""
				dialog_text = "Actuate primary flightstick.\nCurrent: NONE"
