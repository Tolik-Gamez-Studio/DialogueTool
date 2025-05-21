class_name Layer extends PanelContainer


@onready var timeline_label := %Label
@onready var eye_button := %EyeButton
@onready var hover_button := %HoverButton

var eye_open := preload("res://ui/assets/icons/eye.svg")
var eye_closed := preload("res://ui/assets/icons/eye_closed.svg")


func _on_eye_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		eye_button.icon = eye_open
	else:
		eye_button.icon = eye_closed
