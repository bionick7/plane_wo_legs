extends Node

const PORT = 4433

@export var enabled: bool = false

func _ready():
	if not enabled:
		start_game()
		return
	# Start paused.
	get_tree().paused = true
	# You can save bandwidth by disabling server relay and peer notifications.
	multiplayer.server_relay = false
	#print(IP.get_local_interfaces())
	#print(IP.get_local_addresses())
	
func _on_host_pressed():
	# Start as server.
	var peer = ENetMultiplayerPeer.new()
	var host_result = peer.create_server(PORT)
	print(host_result)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer server.")
		return
	multiplayer.multiplayer_peer = peer
	InputManager.on_multiplayer_connect()  # Needs to be called manually on the server
	#$V/OwnIP = IP.
	start_game()

func _on_connect_pressed():
	# Start as client.
	var txt : String = $V/IP.text
	if txt == "":
		OS.alert("Need a remote to connect to.")
		return
	var peer = ENetMultiplayerPeer.new()
	var connect_result = peer.create_client(txt, PORT)
	print(connect_result)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to start multiplayer client.")
		return
	multiplayer.multiplayer_peer = peer
	start_game()


func start_game():
	# Hide the UI and unpause to start the game.
	$V.hide()
	get_tree().paused = false
