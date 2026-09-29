extends Control

var ws := WebSocketPeer.new()
var joined := false

@onready var status_label = $MarginContainer/VBoxContainer/StatusLabel
@onready var server_url_input = $MarginContainer/VBoxContainer/ServerUrlInput
@onready var name_input = $MarginContainer/VBoxContainer/NameInput
@onready var connect_btn = $MarginContainer/VBoxContainer/ConnectButton
@onready var display_text_label = $MarginContainer/VBoxContainer/DisplayTextLabel
@onready var input_text = $MarginContainer/VBoxContainer/InputText
@onready var submit_btn = $MarginContainer/VBoxContainer/SubmitButton
@onready var result_label = $MarginContainer/VBoxContainer/ResultLabel

func _ready():
	connect_btn.pressed.connect(_on_connect_pressed)
	submit_btn.pressed.connect(_on_submit_pressed)
	submit_btn.disabled = true
	status_label.text = "Enter the server URL and your name."

func _process(_delta):
	# WebSockets have to be polled every frame in Godot
	ws.poll()
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED and joined:
		joined = false
		connect_btn.disabled = false
		submit_btn.disabled = true
		status_label.text = "Disconnected: " + ws.get_close_reason()
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not joined:
		joined = true
		_send({"type": "join", "name": name_input.text, "roomId": "lobby"})
	while ws.get_available_packet_count() > 0:
		var msg = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if msg is Dictionary:
			_handle_message(msg)

func _on_connect_pressed():
	ws.connect_to_url(server_url_input.text.strip_edges())
	connect_btn.disabled = true
	status_label.text = "Connecting..."

func _on_submit_pressed():
	_send({"type": "submit", "text": input_text.text})
	submit_btn.disabled = true
	status_label.text = "Sent! Waiting for the others..."

func _send(data: Dictionary):
	ws.send_text(JSON.stringify(data))

func _handle_message(msg: Dictionary):
	match msg.type:
		"waiting":
			status_label.text = "Players: " + ", ".join(msg.players) + " – waiting..."
		"round":
			display_text_label.text = msg.prompt
			input_text.text = ""
			result_label.text = ""
			submit_btn.disabled = false
			status_label.text = "Your turn!"
		"results":
			var text = msg.title + "\n"
			for entry in msg.entries:
				text += "\n" + entry.name + ": " + entry.text
			result_label.text = text
			status_label.text = "Game over!" if msg.gameOver else "Next round starts soon..."
		"error":
			status_label.text = "Error: " + msg.message
