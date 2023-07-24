extends CanvasLayer

const SETTINGS_FILEPATH: String = "res://data/saves/settings.json"

@export var tab_button_group: ButtonGroup

var settings = {
	"cross wind": false,
	"coreolis force": true,
	"rotate light": true,
}

@onready var option_tree: Tree = $PauseMenu/PauseMenu/Options
@onready var root: TreeItem = option_tree.create_item()

func _ready():
	get_tree().paused = false
	hide()
	
	if FileAccess.file_exists(SETTINGS_FILEPATH):
		load_settings()
	else:
		save_settings()
		
	tab_button_group.pressed.connect(_on_button_group_pressed)
	option_tree.set_column_expand(1, true)
	add_setting_check("cross wind")
	add_setting_check("coreolis force")
	add_setting_check("rotate light")

func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILEPATH):
		push_error("Settings file path \"%s\" not found" % SETTINGS_FILEPATH)
		return
	var file: FileAccess = FileAccess.open(SETTINGS_FILEPATH, FileAccess.READ)
	var json: JSON = JSON.new()
	var error = json.parse((file.get_as_text()))
	if error == OK:
		settings = json.data
	else:
		push_error("Error while parsing \"%s\", line %d : \"%s\"" % [
			SETTINGS_FILEPATH, json.get_error_line(), json.get_error_message()
		]) 

func save_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILEPATH):
		push_warning("Settings file path \"%s\" not found; Creating new file" % SETTINGS_FILEPATH)
	var file: FileAccess = FileAccess.open(SETTINGS_FILEPATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "  "))

func add_setting_check(key: String) -> void:
	var item: TreeItem = option_tree.create_item(root)
	item.set_text(0, key)
	item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
	item.set_editable(1, true)
	item.set_metadata(0, key)
	item.set_metadata(1, "check")
	item.set_checked(1, settings[key])

func _on_resume_pressed():
	get_tree().paused = false
	hide()

func _on_quit_pressed():
	get_tree().quit()

func _on_button_group_pressed(button: BaseButton):
	if button.has_meta("tab"):
		$PauseMenu/PauseMenu.current_tab = button.get_meta("tab")
		#print($PauseMenu.current_tab)

func get_setting(key: String, default: Variant) -> Variant:
	if not key in settings:
		return default
	return settings[key]

func _on_options_item_edited():
	var item: TreeItem = option_tree.get_selected()
	var key: String = item.get_metadata(0)
	var type: String = item.get_metadata(1)
	if key in settings:
		match type:
			"check":
				settings[key] = item.is_checked(1)
	save_settings()

func _on_gamepad_pressed():
	pass # Replace with function body.

func _on_flightstick_pressed():
	pass # Replace with function body.
