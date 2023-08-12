class_name InputAtlas
extends Resource

## Grants acess to all input sprites
##
## Supposed to be a singletonresource, shared between all nodes that need to
## access input sprites (keys / gamepad buttons).

## Key map, generated automatically by editor script
@export var key_map := {}

## 21-length Array of Joypad button icons; Should match [JoyButton] enum
@export var button_map: Array[Texture2D]

## 21-length Array of Joypad button icons; Should match [JoyButton] enum
## If available, it overrides buttonmap if the device is a plastation controller
@export var button_map_playstation: Array[Texture2D]

## 10-length Array of Mouse button icons; Should match [MouseButton] enum
@export var mousebutton_map: Array[Texture2D]

## Default icon, displayed if no other icon is applicable
@export var default: Texture2D

## Returns the refernce to a texture that is meant to represent the 
## given [InputEvent]
func get_icon(event: InputEvent) -> Texture2D:
	var res = null
	if event is InputEventJoypadButton:
		if event.button_index < 0 or event.button_index >= button_map.size():
			res = null
		if (
				is_ps_controller(event.device) and 
				event.button_index < button_map_playstation.size() and 
				button_map_playstation[event.button_index] != null
		):
			res = button_map_playstation[event.button_index]
		else:
			res = button_map[event.button_index]
	elif event is InputEventMouseButton:
		if event.button_index < 0 or event.button_index >= mousebutton_map.size():
			res = null
		res = mousebutton_map[event.button_index]
	elif event is InputEventKey:
		var key_text := (event as InputEventKey).as_text_physical_keycode()
		res = key_map.get(key_text, null)
	if res == null or not (res is Texture2D):
		return default
	return res

func is_ps_controller(device: int) -> bool:
	if device not in Input.get_connected_joypads():
		return false
	return [
		"PS1", "PS2", "PS3", "PS4", "PS5", "PS6", "PS7", "PS8"  # Futureproof :)
	].any(func(x): return x.to_lower() in Input.get_joy_name(device).to_lower())
