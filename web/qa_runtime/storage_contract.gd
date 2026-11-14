extends SceneTree
## Main engine owner only. For a browser QA export include this script, then:
## --script res://verification/current/web-release-20261114/storage_contract.gd
## -- --save-dir=user://qa-current/web-release-<unique> --storage-stage=write
## Reload with stage=read and the same directory to prove actual persistence.
## stage=crash-write holds a lease and stays alive after READY_FOR_ABRUPT_CLOSE;
## close that tab, then stage=read verifies automatic run-lock/lease recovery.
const Store = preload("res://scripts/save_store.gd")
const Session = preload("res://scripts/web_save_session.gd")
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var directory := ""
var stage := "write"
var held_lease := {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			directory = argument.trim_prefix("--save-dir=")
		if argument.begins_with("--storage-stage="):
			stage = argument.trim_prefix("--storage-stage=")
	var allowed := ProjectSettings.globalize_path("user://qa-current").simplify_path().trim_suffix("/") + "/"
	var resolved := ProjectSettings.globalize_path(directory).simplify_path()
	if not directory.begins_with("user://qa-current/web-release-") or not resolved.begins_with(allowed) or stage not in ["write", "read", "crash-write"]:
		push_error("Storage QA requires an isolated --save-dir=user://qa-current/web-release-<unique> and a valid stage")
		quit(2)
		return
	if stage != "read" and DirAccess.dir_exists_absolute(resolved):
		push_error("Storage write QA requires a NEW directory; existing contents were left untouched")
		quit(2)
		return
	_run.call_deferred()


func check(label: String, passed: bool) -> void:
	checks.append({"name": label, "passed": passed})
	if not passed:
		failures.append(label)
		push_error(label)


func _run() -> void:
	var store = Store.new(directory)
	if stage == "read":
		var loaded: Dictionary = store.load_slot(1)
		check("Reload actually finds the persistent profile", loaded.ok and loaded.exists)
		if loaded.ok and loaded.exists:
			check("Reload retains exact coins, collection and settlement identity", loaded.profile.points == 105 and loaded.profile.album == {"GAL-001": true} and loaded.profile.total_banked_cards == 2 and loaded.profile.banked_collection_runs.get("web-storage-contract") == true)
			var resaved: Dictionary = store.save_slot(1, loaded.profile)
			check("Reload can save after a prior run's held lease", resaved.ok and resaved.profile.revision == loaded.profile.revision + 1)
		else:
			check("Missing browser data is not mistaken for a new successful profile", false)
	else:
		_contract(store)
	if OS.has_feature("web") and failures.is_empty():
		# Let Godot's normal dirty-file sync run. Completion is proven only by
		# a fresh page reading the fixture, not by this bounded frame wait.
		if stage == "crash-write":
			held_lease = store._acquire_slot_lease(1)
			check("Abrupt-close fixture holds a live Web lease", held_lease.ok)
		for frame in range(120):
			await process_frame
	var report := {"suite": "web-storage-contract", "platform": OS.get_name(), "stage": stage,
		"directory": directory, "total": checks.size(), "passed": checks.size() - failures.size(), "failures": failures, "checks": checks}
	print("WEB_STORAGE_CONTRACT_RESULT=" + JSON.stringify(report))
	if stage == "crash-write" and OS.has_feature("web") and failures.is_empty():
		print("WEB_STORAGE_READY_FOR_ABRUPT_CLOSE")
		return
	quit(0 if failures.is_empty() else 1)


func _contract(store) -> void:
	var loaded: Dictionary = store.load_slot(1)
	check("Isolated startup is empty and valid", loaded.ok and not loaded.exists and loaded.profile.points == 0 and loaded.profile.album.is_empty())
	if not loaded.ok:
		return
	var result := {"run_id": "web-storage-contract", "loot": {"GAL-001": 2}, "score": 100,
		"coins": 100, "pack_coins": 100, "reason": "completed", "elapsed_ticks": 7200,
		"shots": 1, "card_count": 2, "destroyed_pack_count": 2}
	var banked: Dictionary = store.bank_collection(1, loaded.profile, result)
	check("Production bank commits real coins and collection once", banked.ok and banked.get("banked", false))
	if not banked.ok:
		return
	var profile: Dictionary = banked.profile
	check("Production settlement awards 100 coins and one duplicate worth 5", profile.points == 105 and profile.album == {"GAL-001": true} and profile.total_banked_cards == 2)
	var reader = Store.new(directory)
	var reread: Dictionary = reader.load_slot(1)
	check("Another store reads exact committed progress", reread.ok and reread.profile == profile)
	var main_path: String = store._slot_path(1, "main")
	var before := FileAccess.get_file_as_bytes(main_path)
	var retried: Dictionary = reader.bank_collection(1, loaded.profile, result)
	check("Settlement retry is idempotent and changes no file bytes", retried.ok and not retried.banked and FileAccess.get_file_as_bytes(main_path) == before)
	var lease: Dictionary = store._acquire_slot_lease(1)
	check("First store acquires slot ownership", lease.ok)
	if lease.ok:
		if OS.has_feature("web"):
			check("Browser lease uses session ownership instead of PID 0", lease.get("web", false) and str(lease.token).begins_with("web-"))
		else:
			check("Desktop still uses its native process-token lease", not lease.get("web", false) and store._lease_owner_pid(str(lease.owner).get_file()) == OS.get_process_id())
		var blocked: Dictionary = reader.save_slot(1, profile)
		check("A competing store cannot overwrite a live lease", not blocked.ok and blocked.error == "save_busy" and FileAccess.get_file_as_bytes(main_path) == before)
		store._release_slot_lease(lease)
	var saved: Dictionary = reader.save_slot(1, profile)
	check("Ownership release allows the next save", saved.ok and saved.profile.revision == profile.revision + 1)
	var stale: Dictionary = store.save_slot(1, profile)
	check("Stale revisions cannot overwrite a newer save", not stale.ok and stale.error == "revision_conflict")
	_lock_recovery(store)
	if OS.has_feature("web"):
		_web_failures(store)
		var status := Session.check(ProjectSettings.globalize_path(directory).simplify_path())
		check("Official shell session is valid after error probes", status.ok)
		var recovered: Dictionary = store.save_slot(1, saved.profile)
		check("Browser saves successfully after lease recovery probes", recovered.ok)
		check("Web rejects the native default save directory before reading it", not Store.new().load_slot(1).ok)


func _lock_recovery(store) -> void:
	# These exact Web recovery cases run on desktop too, without changing OS
	# feature flags, spawning another engine or opening native player saves.
	var lock_dir: String = store._slot_path(2, "lock")
	var current_session := "11111111111111111111111111111111"
	var old_token := "web-00000000000000000000000000000000-9223372036854775808-1"
	_fixture_owner(lock_dir, old_token + ".owner", old_token)
	check("Prior Web session owner can be reclaimed", store._reclaim_web_lease(lock_dir, current_session) and not DirAccess.dir_exists_absolute(lock_dir))
	DirAccess.make_dir_absolute(lock_dir)
	check("An empty lease left by a closed page is reclaimable", store._reclaim_web_lease(lock_dir, current_session))
	var current_token := "web-" + current_session + "-9223372036854775808-1"
	_fixture_owner(lock_dir, current_token + ".owner", current_token)
	check("Current session owner is preserved", not store._reclaim_web_lease(lock_dir, current_session) and FileAccess.file_exists(lock_dir.path_join(current_token + ".owner")))
	DirAccess.remove_absolute(lock_dir.path_join(current_token + ".owner"))
	DirAccess.remove_absolute(lock_dir)
	_fixture_owner(lock_dir, "unrecognized.data", "keep this QA sentinel")
	check("Unknown lease contents are never deleted", not store._reclaim_web_lease(lock_dir, current_session) and FileAccess.get_file_as_string(lock_dir.path_join("unrecognized.data")) == "keep this QA sentinel")
	DirAccess.remove_absolute(lock_dir.path_join("unrecognized.data"))
	DirAccess.remove_absolute(lock_dir)
	check("Same-page registry reserves a single owner", Session.reserve(lock_dir, "first") and not Session.reserve(lock_dir, "second"))
	Session.release(lock_dir, "second")
	check("A stale release cannot remove a live registry owner", Session.owns(lock_dir, "first"))
	Session.release(lock_dir, "first")
	check("Matching release frees the page registry", not Session.owns(lock_dir, "first") and Session.reserve(lock_dir, "second"))
	Session.release(lock_dir, "second")


func _web_failures(store) -> void:
	# Probe errors synchronously, then restore the actual lock-bearing session.
	JavaScriptBridge.eval("window.__RHYTHM_WEB_SESSION.error = '浏览器保存测试：站点存储不可用。'", true)
	var denied: Dictionary = store.load_slot(1)
	check("Browser persistence errors are readable and block reads", not denied.ok and str(denied.error).contains("站点存储不可用"))
	var save_denied: Dictionary = store.save_slot(1, store.default_profile())
	check("Browser persistence errors block writes before mutation", not save_denied.ok and str(save_denied.error).contains("站点存储不可用"))
	JavaScriptBridge.eval("window.__RHYTHM_WEB_SESSION.error = ''; window.__RHYTHM_WEB_SESSION.storageReady = false", true)
	var unavailable: Dictionary = store.load_slot(1)
	check("Unavailable persistence reports how to recover", not unavailable.ok and str(unavailable.error).contains("持久化存档"))
	JavaScriptBridge.eval("window.__RHYTHM_WEB_SESSION.storageReady = true; window.__RHYTHM_WEB_SESSION.lockHeld = false", true)
	var unlocked: Dictionary = store.load_slot(1)
	check("Missing page ownership cannot read a competing profile", not unlocked.ok and str(unlocked.error).contains("另一个标签页"))
	JavaScriptBridge.eval("window.__RHYTHM_WEB_SESSION.lockHeld = true", true)


func _fixture_owner(lock_dir: String, name: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(lock_dir)
	var file := FileAccess.open(lock_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		check("Create isolated lock fixture", false)
		return
	file.store_string(contents)
	file.close()
