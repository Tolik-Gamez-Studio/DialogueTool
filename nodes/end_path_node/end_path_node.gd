@icon("res://ui/assets/icons/exit.svg")
class_name EndPathNode extends MonologueGraphNode

var next_story := Property.new(FILE, {"filters":  ["*.json;Monologue File"]})


func _ready():
	node_type = "NodeEndPath"
	super._ready()


func _from_dict(dict: Dictionary):
	next_story.value = dict.get("NextStoryName", "")  # backwards compatibility
	super._from_dict(dict)


func _on_close_request():
	queue_free()
	get_parent().clear_all_empty_connections()
