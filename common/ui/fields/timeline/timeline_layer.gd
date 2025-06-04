class_name Layer extends PanelContainer

signal delete_button_pressed

@onready var timeline_label := %Label
@onready var hover_button := %HoverButton


func _on_delete_button_pressed() -> void:
	delete_button_pressed.emit()
