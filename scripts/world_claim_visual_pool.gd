extends RefCounted
## Detached transient MeshInstance storage. World still owns every live node/Tween.
## Active loans have no cap; only completed idle objects are bounded.
const MAX_IDLE := 256
const MAX_IDLE_PER_KEY := 32
var _idle: Dictionary = {}
var _loans: Dictionary = {}
var _meshes: Dictionary = {}
var _serial := 0
var _idle_count := 0
var created := 0
var reused := 0
var discarded := 0

func mesh(key: Variant, factory: Callable) -> Mesh:
	if not _meshes.has(key): _meshes[key] = factory.call()
	return _meshes[key]

func borrow(key: Variant, factory: Callable) -> Dictionary:
	var bucket: Array = _idle.get(key,[])
	var node: MeshInstance3D
	while not bucket.is_empty():
		var candidate: Variant = bucket.pop_back()
		_idle_count -= 1
		if is_instance_valid(candidate) and candidate is MeshInstance3D and candidate.get_parent()==null and not candidate.is_queued_for_deletion():
			node = candidate
			reused += 1
			break
	if bucket.is_empty(): _idle.erase(key)
	if node==null:
		node = factory.call()
		created += 1
	_serial += 1
	var loan := {"node":node,"key":key,"token":_serial}
	_loans[node.get_instance_id()] = loan
	return loan

func prepare(key: Variant, factory: Callable, count: int) -> void:
	var leases: Array = []
	var missing := mini(MAX_IDLE_PER_KEY,count)-(_idle.get(key,[]) as Array).size()
	for _index in range(maxi(0,missing)): leases.append(borrow(key,factory))
	for lease: Dictionary in leases: release_detached(lease.node,int(lease.token))

func owns(node: MeshInstance3D, token: int) -> bool:
	if not is_instance_valid(node): return false
	var loan: Dictionary = _loans.get(node.get_instance_id(),{})
	return not loan.is_empty() and int(loan.token)==token

func release_detached(node: MeshInstance3D, token: int) -> bool:
	if not owns(node,token) or node.get_parent()!=null or node.is_queued_for_deletion(): return false
	var loan: Dictionary = _loans[node.get_instance_id()]
	_loans.erase(node.get_instance_id())
	var bucket: Array = _idle.get(loan.key,[])
	if _idle_count>=MAX_IDLE or bucket.size()>=MAX_IDLE_PER_KEY:
		node.free()
		discarded += 1
		return false
	bucket.append(node)
	_idle[loan.key] = bucket
	_idle_count += 1
	return true

func metrics() -> Dictionary:
	return {"created":created,"reused":reused,"discarded":discarded,"idle":_idle_count,"active":_loans.size(),"meshes":_meshes.size()}

func clear() -> void:
	for bucket: Array in _idle.values():
		for node in bucket:
			if is_instance_valid(node) and node.get_parent()==null: node.free()
	for loan: Dictionary in _loans.values():
		var node: Variant = loan.node
		if is_instance_valid(node) and node.get_parent()==null: node.free()
	_idle.clear()
	_loans.clear()
	_idle_count = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		# RefCounted self is already invalid here; clean member storage directly.
		for bucket: Array in _idle.values():
			for node in bucket:
				if is_instance_valid(node) and node.get_parent()==null: node.free()
		for loan: Dictionary in _loans.values():
			if is_instance_valid(loan.node) and loan.node.get_parent()==null: loan.node.free()
