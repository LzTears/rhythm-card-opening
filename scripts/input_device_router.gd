extends Node
## Observe native input before a modal consumes it. The host owns device policy;
## this node never handles events or replaces their normal GUI routing.

func _input(event: InputEvent) -> void:
	var host := get_parent()
	if is_instance_valid(host) and host.has_method("_observe_input_device"):
		host._observe_input_device(event)
