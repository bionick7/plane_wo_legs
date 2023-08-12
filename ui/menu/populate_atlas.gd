@tool
extends EditorScript

const KEYBOARD_ATLAS_PATH := "res://ui/menu/Keyboard & Mouse/"
const GAMEPAD_ATLAS_PATH := "res://ui/menu/Xbox One/"

func _run():
	var atlas: InputAtlas = preload("res://ui/menu/input_atlas.tres")
	
	var all_keys: Array[Key] = []
	all_keys.append_array(range(KEY_ESCAPE, KEY_F12+1))
	all_keys.append_array(range(KEY_KP_MULTIPLY, KEY_KP_9+1))
	all_keys.append_array(range(KEY_SPACE, KEY_ASCIITILDE+1))
	#for k in all_keys:
	#	print(OS.get_keycode_string(k))
	var file_names = DirAccess.get_files_at(KEYBOARD_ATLAS_PATH)
	
	var map := {}
	for key in all_keys:
		var key_name = OS.get_keycode_string(key)
		var file_name = "Keyboard_Black_%s.png" % key_name
		if file_name in file_names:
			map[key_name] = load(KEYBOARD_ATLAS_PATH.path_join(file_name))
	atlas.key_map = map
	print("%d keys set" % map.size())
