extends RefCounted
## Detached Label storage only. World owns active nodes, Tweens and feedback records.
## A lease's cold_minimum is the first NEW, detached Label's legacy layout result.
## Reused nodes may already clamp size to the real font minimum: do not substitute
## their current get_minimum_size()/size for cold_minimum in placement calculations.
const MAX_IDLE := 256
const MAX_IDLE_PER_KEY := 64
const KEY_META := &"_feedback_label_pool_key"
const COLD_MINIMUM_META := &"_feedback_label_cold_minimum"
const STATIC_META := [KEY_META,COLD_MINIMUM_META,&"damage_style",&"pixel_feedback"]

var _idle_by_key: Dictionary = {}
var _idle_labels: Dictionary = {}
var _borrowed_labels: Dictionary = {}
var created_count := 0
var reused_count := 0
var discarded_count := 0

static func make_key(kind: String, style: String, text: String, bd_element: String = "") -> String:
	# Length prefixes also distinguish strings containing separators or colons.
	return "%d:%s%d:%s%d:%s%d:%s" % [kind.length(),kind,style.length(),style,text.length(),text,bd_element.length(),bd_element]

func borrow(kind: String, style: String, text: String, bd_element: String, factory: Callable) -> Dictionary:
	var key := make_key(kind,style,text,bd_element)
	var bucket: Array = _idle_by_key.get(key,[])
	while not bucket.is_empty():
		var identity := int(bucket.pop_back())
		var cached: Variant = _idle_labels.get(identity)
		_idle_labels.erase(identity)
		if bucket.is_empty():
			_idle_by_key.erase(key)
		if not is_instance_valid(cached) or not cached is Label:
			continue
		var warm_label: Label = cached
		# Idle nodes must stay detached. If an outside owner reparented one, that
		# owner now controls it; never steal it back or free its active node.
		if warm_label.get_parent()!=null or warm_label.is_queued_for_deletion():
			continue
		if str(warm_label.get_meta(KEY_META,""))!=key or not warm_label.get_meta(COLD_MINIMUM_META) is Vector2:
			warm_label.free()
			discarded_count += 1
			continue
		reused_count += 1
		_borrowed_labels[identity] = warm_label
		_reset_transient_properties(warm_label)
		return {"label":warm_label,"cold_minimum":warm_label.get_meta(COLD_MINIMUM_META),"key":key,"reused":true}
	if not factory.is_valid():
		push_error("Feedback Label pool requires a valid cold Label factory.")
		return {}
	var created: Variant = factory.call(kind,style,text,bd_element)
	if not created is Label or not is_instance_valid(created):
		push_error("Feedback Label factory must return a new detached Label.")
		return {}
	var label: Label = created
	if label.get_parent()!=null or label.is_queued_for_deletion():
		push_error("Feedback Label factory returned an attached or retiring Label.")
		return {}
	var cold_minimum := label.get_minimum_size()
	label.set_meta(KEY_META,key)
	label.set_meta(COLD_MINIMUM_META,cold_minimum)
	_borrowed_labels[label.get_instance_id()] = label
	created_count += 1
	return {"label":label,"cold_minimum":cold_minimum,"key":key,"reused":false}

func release_detached(label: Label) -> bool:
	# Call from World's deferred retirement callback, AFTER removing the Label
	# from its active parent and invalidating the owned feedback snapshot. The
	# completed node-bound Tween must have returned before any over-limit free.
	if not is_instance_valid(label) or label.is_queued_for_deletion():
		return false
	if label.get_parent()!=null:
		push_error("Detach a retired feedback Label before returning it to the pool.")
		return false
	var identity := label.get_instance_id()
	if _idle_labels.has(identity):
		return false
	if not _borrowed_labels.has(identity):
		return false
	if not label.has_meta(KEY_META) or not label.get_meta(COLD_MINIMUM_META) is Vector2:
		return false
	_borrowed_labels.erase(identity)
	var key := str(label.get_meta(KEY_META))
	for metadata in label.get_meta_list():
		if not metadata in STATIC_META:
			label.remove_meta(metadata)
	var bucket: Array = _idle_by_key.get(key,[])
	if _idle_labels.size()>=MAX_IDLE or bucket.size()>=MAX_IDLE_PER_KEY:
		label.free()
		discarded_count += 1
		return false
	bucket.append(identity)
	_idle_by_key[key] = bucket
	_idle_labels[identity] = label
	return true

func idle_count() -> int:
	return _idle_labels.size()

func idle_count_for(kind: String, style: String, text: String, bd_element: String = "") -> int:
	return (_idle_by_key.get(make_key(kind,style,text,bd_element),[]) as Array).size()

func clear() -> void:
	# Active attached leases remain World's responsibility. Also free any lease
	# that never reached add_child, so an interrupted creation cannot leak a Node.
	for cached in _idle_labels.values()+_borrowed_labels.values():
		if is_instance_valid(cached) and cached is Label and cached.get_parent()==null:
			cached.free()
	_idle_labels.clear()
	_idle_by_key.clear()
	_borrowed_labels.clear()

func _reset_transient_properties(label: Label) -> void:
	# These can change during the previous floating/fading Tween. Geometry is
	# assigned by World from cold_minimum; Theme/font/text and shape caches stay.
	label.modulate = Color.WHITE
	label.self_modulate = Color.WHITE
	label.visible = true
	label.position = Vector2.ZERO
	label.z_index = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		# RefCounted's self is already invalid for another script method call here.
		# Its member containers are still available during this notification.
		for cached in _idle_labels.values()+_borrowed_labels.values():
			if is_instance_valid(cached) and cached is Label and cached.get_parent()==null:
				cached.free()
