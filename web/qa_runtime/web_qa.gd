extends Node
## Export only with the web_qa feature and this scene as the feature main scene.
## Browser input remains real DOM keyboard/mouse input. This bridge has no
## gameplay, purchase, reward, clock, or arbitrary-property mutation endpoint.

const MAIN_SCENE := "res://scenes/main.tscn"
const SAVE_PREFIX := "user://qa-current/web-release-"
const Catalog = preload("res://scripts/collection_catalog.gd")
const ReleaseGameConfig = preload("res://scripts/game_config.gd")
const ReleaseRules = preload("res://scripts/pack_rules.gd")
const WebSaveSession = preload("res://scripts/web_save_session.gd")
const BRIDGE_SETUP := """(function () {
	const qa = window.__RHYTHM_WEB_QA;
	let serial = 0;
	qa.version = 1;
	qa.request = function (payload) {
		const request = Object.assign({}, payload || {});
		if (request.request_id == null) request.request_id = ++serial;
		qa._dispatch(JSON.stringify(request));
		return request.request_id;
	};
})()"""

var _main
var _save_uri := ""
var _save_absolute := ""
var _boot_error := ""
var _fresh_boot := false
var _request_callback: JavaScriptObject # Keep the callback alive across GC.
var _bridge: JavaScriptObject
var _bridge_installed := false
var _fixture: Dictionary = {}
var _fault_lock_installed := false
var _events: Array[Dictionary] = []
var _sequence := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Check every argument before loading Main, whose _ready immediately reads
	# its save store. In particular, duplicate --save-dir arguments are refused.
	if not OS.has_feature("web") or not OS.has_feature("web_qa"):
		_reject_boot("QA requires both web and web_qa export features.")
		return
	_install_bridge()
	var save_arguments: Array[String] = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			save_arguments.append(argument.trim_prefix("--save-dir="))
	if save_arguments.size() != 1 or not _valid_save_uri(save_arguments[0]):
		_reject_boot("QA requires exactly one --save-dir=user://qa-current/web-release-<name>; name accepts only ASCII letters, digits, _ and -.")
		return
	_save_uri = save_arguments[0]
	_save_absolute = ProjectSettings.globalize_path(_save_uri).simplify_path()
	_fresh_boot = not DirAccess.dir_exists_absolute(_save_absolute)
	_start_production_main.call_deferred()


func _start_production_main() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_reject_boot("Could not load the production Main scene.")
		return
	_main = packed.instantiate()
	# Main remains an immediate child of /root, matching its production path.
	get_tree().root.add_child(_main)
	if not _runtime_isolated():
		_main.queue_free()
		_main = null
		_reject_boot("Production Main did not select the guarded QA save directory.")
		return
	_record("boot", {"fresh_directory":_fresh_boot})
	_publish({"request_id":0,"op":"ready","ok":true,"error":""})


func _valid_save_uri(value: String) -> bool:
	if not value.begins_with(SAVE_PREFIX) or value.contains(".."):
		return false
	var suffix := value.trim_prefix(SAVE_PREFIX)
	if suffix.is_empty() or suffix.length() > 96:
		return false
	for character in suffix:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-":
			return false
	return true


func _runtime_isolated() -> bool:
	if not is_instance_valid(_main) or _main.storage == null:
		return false
	return _valid_save_uri(_save_uri) and str(_main.storage._base_dir).simplify_path() == _save_absolute


func _reject_boot(message: String) -> void:
	_boot_error = message
	push_error(message)
	var label := Label.new()
	label.text = "Web QA refused to start.\n" + message
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	if _bridge_installed:
		_publish({"request_id":0,"op":"ready","ok":false,"error":message})


func _install_bridge() -> void:
	JavaScriptBridge.eval("window.__RHYTHM_WEB_QA = {};", true)
	_bridge = JavaScriptBridge.get_interface("__RHYTHM_WEB_QA")
	_request_callback = JavaScriptBridge.create_callback(_on_js_request)
	_bridge._dispatch = _request_callback
	JavaScriptBridge.eval(BRIDGE_SETUP, true)
	_bridge_installed = true


func _on_js_request(arguments: Array) -> void:
	if arguments.size() != 1 or not arguments[0] is String:
		_publish({"request_id":null,"op":"invalid","ok":false,"error":"Expected one JSON request."})
		return
	var parsed: Variant = JSON.parse_string(arguments[0])
	if not parsed is Dictionary:
		_publish({"request_id":null,"op":"invalid","ok":false,"error":"Expected a JSON object."})
		return
	# Avoid re-entering Godot scene mutation from the JavaScript callback.
	_handle_request.call_deferred(parsed)


func _handle_request(request: Dictionary) -> void:
	var operation := str(request.get("op", "snapshot"))
	var response := {"request_id":request.get("request_id"),"op":operation,"ok":false,"error":""}
	if not _boot_error.is_empty() or not _runtime_isolated():
		response.error = _boot_error if not _boot_error.is_empty() else "QA save isolation lost."
		_publish(response)
		return
	match operation:
		"snapshot":
			response.ok = true
		"fixture_red_inspector":
			response.merge(_fixture_red_inspector(str(request.get("id", ""))), true)
		"fault_lock_fixture":
			response.merge(_fault_lock_fixture(), true)
		_:
			response.error = "Unknown QA operation."
	_publish(response)


func _fixture_red_inspector(id: String) -> Dictionary:
	if str(_main.screen) == "battle":
		return {"ok":false,"error":"Leave battle with real UI before using the inspection fixture."}
	var definition: Dictionary = Catalog.card_definition(id)
	if definition.is_empty() or int(definition.get("grade", -1)) != 4:
		return {"ok":false,"error":"Fixture accepts only a real catalogue red-card id."}
	# _show_hub -> album.configure deep-copies this temporary profile. Restore
	# Main immediately: manual save, future gameplay and banked progress still
	# use the original profile, even while the fixture inspector is on screen.
	var real_profile: Dictionary = _main.profile
	var preview_profile := real_profile.duplicate(true)
	preview_profile.album[id] = true
	_main.profile = preview_profile
	_main._show_hub("collection")
	_main.profile = real_profile
	var album: Control = _main._collection_album()
	if not is_instance_valid(album):
		return {"ok":false,"error":"Production album was not created."}
	album.select_theme(str(definition.theme))
	album.set_owned_only(false)
	album.open_card(id)
	var inspector: Control = album.get_inspector()
	if not is_instance_valid(inspector):
		return {"ok":false,"error":"Production inspector was not created."}
	_fixture = {"active":true,"kind":"red_inspector","id":id,"memory_only":true,"main_profile_restored":true,"persisted":false}
	_record("fixture_red_inspector", {"id":id,"memory_only":true})
	return {"ok":true,"error":"","fixture":_fixture.duplicate(true)}


func _fault_lock_fixture() -> Dictionary:
	if not _fresh_boot or _fault_lock_installed:
		return {"ok":false,"error":"Fault fixture is allowed once in a directory that was fresh at this boot."}
	if str(_main.screen) == "battle" or bool(_main.storage._writing) or not _main.storage._battle_lease.is_empty():
		return {"ok":false,"error":"Fault fixture requires an idle store outside battle."}
	var session: Dictionary = WebSaveSession.check(_save_absolute)
	if not bool(session.get("ok", false)):
		return {"ok":false,"error":str(session.get("error", "Web session is not ready."))}
	# Use the real store's path, currently slot_1.lock.json (a directory).
	var directory: String = _main.storage._slot_path(int(_main.slot), "lock")
	if directory.get_base_dir() != _save_absolute or DirAccess.dir_exists_absolute(directory) or FileAccess.file_exists(directory):
		return {"ok":false,"error":"Refusing to replace an existing slot lease."}
	if DirAccess.make_dir_recursive_absolute(_save_absolute) != OK or DirAccess.make_dir_absolute(directory) != OK:
		return {"ok":false,"error":"Could not create the isolated fault lease directory."}
	# This run's token becomes an old session token after browser reload. It
	# intentionally remains busy in this page, without reserving a live store.
	var token := "web-%s-%d-1" % [str(session.token), get_instance_id()]
	var owner := directory.path_join(token + ".owner")
	var file := FileAccess.open(owner, FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(directory)
		return {"ok":false,"error":"Could not create the isolated fault owner."}
	file.store_string(token)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(owner) != token:
		return {"ok":false,"error":"Fault owner write verification failed."}
	_fault_lock_installed = true
	_record("fault_lock_fixture", {"requires_reload":true,"directory":directory})
	return {"ok":true,"error":"","requires_reload":true,"lock_path":directory,"persisted_profile_changed":false}


func _snapshot() -> Dictionary:
	var state := {"ready":is_instance_valid(_main) and _boot_error.is_empty(),"boot_error":_boot_error,"frame":Engine.get_process_frames(),"ticks_msec":Time.get_ticks_msec(),
		"qa":{"save_uri":_save_uri,"fresh_boot":_fresh_boot,"fixture":_fixture.duplicate(true),"fault_lock_installed":_fault_lock_installed,"events":_events.duplicate(true)}}
	if not _runtime_isolated():
		return state
	var profile: Dictionary = _main.profile
	state["release_contract"] = {"version":ProjectSettings.get_setting("application/config/version"),"duration_seconds":ReleaseGameConfig.RUN_DURATION_SECONDS,"run_ticks":ReleaseGameConfig.RUN_TICKS,"fever_thresholds":ReleaseRules.FEVER_THRESHOLDS.duplicate(),"track_adjust_db":_main.audio.BGM_TRACK_ADJUST_DB.duplicate()}
	var multiplier_labels: Array = []
	for label: Node in _main.world.find_children("*","Label",true,false):
		if label.has_meta("circle_bonus") and label.is_visible_in_tree():
			multiplier_labels.append({"text":label.text,"scale":label.scale,"position":label.position,"root_id":label.get_meta("root_id",0),"multiplier":label.get_meta("circle_multiplier",0.0)})
	state["circle_bonus_labels"] = multiplier_labels
	state.merge({"screen":str(_main.screen),"paused":bool(_main.paused),"current_tab":str(_main.current_tab),"has_profile":bool(_main.has_profile),
		"initialization_ok":bool(_main.initialization_ok),"save_error":str(_main.save_error),"slot":int(_main.slot),"prelude_frames":int(_main.prelude_frames),
		"rhythm_tutorial_seen":bool(_main.rhythm_tutorial_seen),"input_source":str(_main.input_source),"drum_input_device":str(_main.drum_input_device),
		"profile":{"points":int(profile.get("points", 0)),"revision":int(profile.get("revision", 0)),"album":profile.get("album", {}).duplicate(true),"talents":profile.get("talents", {}).duplicate(true),"total_banked_cards":int(profile.get("total_banked_cards", 0))},
		"last_result":profile.get("last_result", {}).duplicate(true),"collection_counts":Catalog.collection_counts(profile),"storage":_storage_state()})
	var focus := get_viewport().gui_get_focus_owner()
	state["focused_control"] = str(focus.name) if is_instance_valid(focus) else ""
	var simulation: Variant = _main.sim
	if simulation != null:
		var rhythm: Dictionary = simulation.get_rhythm_state()
		var summary: Dictionary = simulation.get_summary()
		summary.merge({"phrase_combo":int(rhythm.get("phrase_combo", 0)),"energy":int(rhythm.get("fever_energy", 0)),"echo":rhythm.get("active_echo", {}).duplicate(true)})
		state["simulation"] = summary
		state["rhythm"] = rhythm
	if is_instance_valid(_main.audio):
		state["audio"] = _main.audio.get_status()
	if is_instance_valid(_main.settlement_view):
		state["settlement"] = _main.settlement_view.get_stage_state()
	var album: Control = _main._collection_album()
	if is_instance_valid(album):
		state["album"] = album.get_page_state()
		var inspector: Control = album.get_inspector()
		if is_instance_valid(inspector):
			state["inspector"] = inspector.get_inspector_state()
	if not state.has("inspector"):
		state["inspector"] = {}
	return state


func _storage_state() -> Dictionary:
	var result := {"_base_dir":_save_absolute,"files":{},"lock_exists":false,"lock_owner_count":0}
	for suffix in ["main", "bak", "tmp"]:
		var path: String = _main.storage._slot_path(int(_main.slot), suffix)
		var exists := FileAccess.file_exists(path)
		result.files[suffix] = {"exists":exists,"sha256":FileAccess.get_sha256(path) if exists else ""}
	var lock_path: String = _main.storage._slot_path(int(_main.slot), "lock")
	result.lock_exists = DirAccess.dir_exists_absolute(lock_path)
	if result.lock_exists:
		result.lock_owner_count = DirAccess.get_files_at(lock_path).size()
	return result


func _record(kind: String, details: Dictionary) -> void:
	_events.append({"event":kind,"frame":Engine.get_process_frames(),"details":details.duplicate(true)})
	if _events.size() > 32:
		_events.pop_front()


func _publish(response: Dictionary) -> void:
	if not _bridge_installed:
		return
	_sequence += 1
	response["sequence"] = _sequence
	response["state"] = _snapshot()
	# Double encoding quotes the JSON text as one JavaScript string literal;
	# no profile text or fixture input is ever concatenated as executable JS.
	var encoded := JSON.stringify(_json_safe(response))
	JavaScriptBridge.eval("window.__RHYTHM_WEB_QA_STATE = JSON.parse(" + JSON.stringify(encoded) + ");", true)


func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key: Variant in value:
				result[str(key)] = _json_safe(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value:
				result.append(_json_safe(item))
			return result
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			return [value.x, value.y, value.z, value.w]
		TYPE_RECT2, TYPE_RECT2I:
			return [value.position.x, value.position.y, value.size.x, value.size.y]
		TYPE_COLOR:
			return [value.r, value.g, value.b, value.a]
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_FLOAT:
			return value if is_finite(value) else null
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
	return value
