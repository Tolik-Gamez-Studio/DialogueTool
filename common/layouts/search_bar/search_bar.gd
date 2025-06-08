extends PanelContainer

@export var graph_edit_switcher: GraphEditSwitcher

@onready var line_edit: LineEdit = $HBoxContainer/LineEdit


func focus() -> void:
	line_edit.grab_focus()
	line_edit.select_all()


func _on_line_edit_text_changed(new_text: String) -> void:
	var graph_edit: MonologueGraphEdit = graph_edit_switcher.current
	var all_nodes: Array = graph_edit.get_nodes()
	
	for node: MonologueGraphNode in all_nodes:
		if node.node_type.containsn(new_text):
			continue
