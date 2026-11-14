extends Node
## Human-controlled evaluation entry. It never injects input or follows targets.
const MainScene = preload("res://scenes/main.tscn")
const Store = preload("res://scripts/save_store.gd")
const Rules = preload("res://scripts/pack_rules.gd")
const Catalog = preload("res://scripts/attack_spec.gd")
const SAVE_NAMESPACE := "user://rhythm-workshop-v14-manual-review"

func _ready() -> void:
	var arguments: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-dir="):
			arguments.append(argument.trim_prefix("--save-dir="))
	if arguments!=[SAVE_NAMESPACE]:
		push_error("Manual build review requires its explicit isolated save namespace")
		get_tree().quit(2)
		return
	var store := Store.new(SAVE_NAMESPACE)
	var loaded: Dictionary = store.load_slot(1)
	if not loaded.ok:
		push_error("Cannot open isolated build review: "+str(loaded.error))
		get_tree().quit(2)
		return
	if not loaded.exists:
		var profile: Dictionary = store.default_profile()
		profile.points = 100000
		profile.total_banked_cards = 300
		for id in Catalog.card_ids():
			profile.inventory[id] = 1
			profile.discovery_flags[id] = true
		# Supply is ready for evaluating a full board. New combat/growth talents
		# remain purchasable with the disclosed review coins.
		for talent in Rules.talent_definitions():
			if talent.id in ["TAL-C","TAL-R"]:
				profile.talents[talent.id] = talent.max_level
		store._grant_launchers(profile)
		profile.selected_loadout = {"launcher_id":"E01","slots":[null,null,null,null]}
		var saved: Dictionary = store.save_slot(1,profile)
		if not saved.ok:
			push_error("Cannot initialize isolated build review: "+str(saved.error))
			get_tree().quit(2)
			return
	var app = MainScene.instantiate()
	add_child(app)
	if app.initialization_ok and app.profile.active_run.is_empty():
		app._show_hub("deck")
	get_window().title = "节拍开卡 · 独立试玩档"
