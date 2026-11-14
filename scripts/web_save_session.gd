extends RefCounted
## The HTML shell holds a same-origin Web Lock before initializing IDBFS or
## starting Godot. This registry arbitrates synchronous stores inside that run;
## a filesystem directory alone cannot arbitrate separate browser IDBFS copies.

static var _active_leases: Dictionary = {}
static var _guard: Mutex = Mutex.new()

const SESSION_SCRIPT := """(function () {
	const s = window.__RHYTHM_WEB_SESSION;
	if (!s) return "";
	return JSON.stringify({lockHeld: s.lockHeld === true,
		storageReady: s.storageReady === true,
		token: typeof s.token === "string" ? s.token : "",
		error: typeof s.error === "string" ? s.error : ""});
})()"""


static func check(base_dir: String) -> Dictionary:
	# Never probe JavaScript or change native persistence behavior on desktop.
	if not OS.has_feature("web"):
		return {"ok": true, "error": "", "token": ""}
	var user_root := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	var pc_directory := ProjectSettings.globalize_path("user://rhythm-workshop-v15").simplify_path()
	if not base_dir.begins_with(user_root + "/") or base_dir == pc_directory:
		return _error("网页版需要独立存档目录，请从正式启动页重新打开。")
	var raw: Variant = JavaScriptBridge.eval(SESSION_SCRIPT, true)
	if not raw is String or raw.is_empty():
		return _error("浏览器存档会话未就绪，请从正式启动页重新打开。")
	var session: Variant = JSON.parse_string(raw)
	if not session is Dictionary:
		return _error("浏览器存档会话未就绪，请从正式启动页重新打开。")
	if not str(session.get("error", "")).is_empty():
		return _error(str(session.error))
	if session.get("lockHeld") != true:
		return _error("另一个标签页正在运行游戏，请关闭它后重新打开。")
	if session.get("storageReady") != true or not OS.is_userfs_persistent():
		return _error("浏览器未允许持久化存档，请退出无痕模式并允许站点存储后重试。")
	var token: String = str(session.get("token", ""))
	if token.length() < 16 or token.length() > 128:
		return _error("浏览器存档会话标识无效，请重新打开启动页。")
	# A fresh shell token identifies this run, independently of Web's PID 0.
	return {"ok": true, "error": "", "token": token.sha256_text().substr(0, 32)}


static func reserve(directory: String, token: String) -> bool:
	if not _guard.try_lock():
		return false
	var available := not _active_leases.has(directory)
	if available:
		_active_leases[directory] = token
	_guard.unlock()
	return available


static func owns(directory: String, token: String) -> bool:
	if not _guard.try_lock():
		return false
	var owned: bool = _active_leases.get(directory, "") == token
	_guard.unlock()
	return owned


static func release(directory: String, token: String) -> void:
	_guard.lock()
	if _active_leases.get(directory, "") == token:
		_active_leases.erase(directory)
	_guard.unlock()


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "token": ""}
