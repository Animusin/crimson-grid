#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/player_quality/proc/attach_canonical_character(mob/living/carbon/human/body, datum/client_interface/quality_test/player)
	body.mock_client = player
	player.mob = body
	if(!body.mind)
		body.mind_initialize()
	body.mind.key = player.key
	body.mind.original_character_slot_index = player.prefs.default_slot
	body.mind.set_original_character(body)
	LAZYADD(player.persistent_client.joined_as_slots, "[player.prefs.default_slot]")

/datum/unit_test/player_quality/character_records/Run()
	var/path = "data/pq-character-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	if(store.read_character("owner", "character") || store.database.get_key("owner"))
		Fail("Reading a character for a preview must not create an account or character record.")
	store.database.set_key("owner", list("pq" = 12, "rcp" = 8, "karma" = 10))
	if(!store.create_character_record("owner", "character", list("locked" = TRUE, "path_rating" = 4, "learned_paths" = list("humanity"), "learned_disciplines" = list("/datum/discipline/potence" = 0))))
		Fail("A trusted first-spawn operation must be able to create one character record.")
	if(store.create_character_record("owner", "character", list()) || store.write_character("other", "character", list("locked" = FALSE)))
		Fail("Character records cannot be duplicated or patched through a different account.")
	var/list/copy = store.read_character("owner", "character")
	var/list/paths = copy["learned_paths"]
	paths += "tampered copy"
	var/list/record = store.read_character("owner", "character")
	paths = record["learned_paths"]
	if(length(paths) != 1)
		Fail("Reading a character must return an independent deep copy.")
	if(!store.unlock_character("Owner", "character", "stats") || store.unlock_character("owner", "character", "stats"))
		Fail("A stats ticket must charge once and reject repeated purchases.")
	if(!store.write_character("owner", "character", list("path_rating" = 3)))
		Fail("A Path update must patch its owned fields into the latest character record.")
	record = store.read_character("owner", "character")
	if(record["unlock_ticket"] != "stats" || record["path_rating"] != 3 || store.respect("owner") != 21)
		Fail("A Path patch must retain the atomic debit/ticket and immediately changed Respect.")
	if(!store.unlock_character("owner", "character", "full") || store.unlock_character("owner", "character", "full"))
		Fail("A stats-to-full upgrade must succeed once for only the remaining two Karma.")
	var/list/account = store.read("owner")
	record = store.read_character("owner", "character")
	if(account["karma"] != 5 || record["unlock_ticket"] != "full" || !islist(record["learned_disciplines"]) || length(record["learned_paths"]) != 1)
		Fail("A full edit session must cost five total and preserve learned Paths/disciplines.")
	sleep(2)
	qdel(store)
	store = new(path)
	record = store.read_character("owner", "character")
	account = store.read("owner")
	if(record["unlock_ticket"] != "full" || account["karma"] != 5)
		Fail("The debit and matching edit ticket must survive persistence together.")
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/character_edit_guards/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/path = "data/pq-edit-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	var/datum/client_interface/quality_test/player = allocate(/datum/client_interface/quality_test, "quality-character-[world.realtime]")
	player.prefs = new(player)
	var/datum/preferences/preferences = player.prefs
	var/mob/dead/new_player/lobby = allocate(/mob/dead/new_player)
	lobby.mock_client = player
	player.mob = lobby
	preferences.quality_character_id = "guarded-character"
	controller.store.database.set_key(player.ckey, list("pq" = 30, "rcp" = 0, "karma" = 10))
	controller.store.create_character_record(player.ckey, preferences.quality_character_id, list("locked" = TRUE, "learned_disciplines" = list("/datum/discipline/temporis" = 0), "learned_paths" = list("humanity")))
	var/datum/preference/name/name_preference = GLOB.preference_entries[/datum/preference/name/real_name]
	if(quality_preference_scope(GLOB.preference_entries[/datum/preference/choiced/language]) != "stats")
		Fail("Mechanical quirk customization must share the three-Karma stats and abilities tier.")
	var/original_name = preferences.read_preference(name_preference.type)
	if(preferences.update_preference(name_preference, "Aster Vale") || preferences.read_preference(name_preference.type) != original_name)
		Fail("The actual preference setter must reject locked identity changes.")
	var/datum/preference/color/hair_color/hair = GLOB.preference_entries[/datum/preference/color/hair_color]
	if(!preferences.update_preference(hair, "#123456") || preferences.read_preference(hair.type) != "#123456")
		Fail("Cosmetic colors must remain editable without buying a ticket.")
	preferences.randomise_appearance_prefs()
	if(preferences.read_preference(name_preference.type) != original_name || preferences.quality_character_id != "guarded-character")
		Fail("Full appearance randomization must not replace a locked identity or its stable ID.")
	var/datum/preference_middleware/stats/stats = new(preferences)
	var/datum/preference_middleware/disciplines/disciplines = new(preferences)
	var/datum/preference_middleware/quirks/quirks = new(preferences)
	if(stats.reset_stats(list(), lobby) || disciplines.set_discipline_level(list("discipline" = "/datum/discipline/potence", "level" = "1"), lobby) || quirks.give_quirk(list("quirk" = "invalid fixture"), lobby))
		Fail("Actual stat, discipline and quirk actions must not bypass a locked sheet.")
	var/datum/preference_middleware/character_progression/controls = new(preferences)
	if(!controls.unlock_character(list("scope" = "stats"), lobby))
		Fail("The actual lobby action must buy a stats ticket for the owning account.")
	if(!stats.reset_stats(list(), lobby) || !disciplines.set_discipline_level(list("discipline" = "/datum/discipline/potence", "level" = "1"), lobby))
		Fail("The three-Karma ticket must authorize actual stats and discipline allocation actions.")
	if(preferences.update_preference(name_preference, "Aster Vale"))
		Fail("A stats ticket must not authorize identity changes.")
	preferences.discipline_levels = list()
	preferences.quality_restore_discipline_choices()
	if(!("/datum/discipline/temporis" in preferences.discipline_levels) || preferences.discipline_levels["/datum/discipline/temporis"] != 0)
		Fail("A respec must retain taught identities at zero without adding free allocated levels.")
	if(!controls.unlock_character(list("scope" = "full"), lobby) || !preferences.update_preference(name_preference, "Aster Vale"))
		Fail("The two-Karma upgrade must authorize identity editing without a second full charge.")
	var/list/account = controller.store.read(player.ckey)
	if(account["karma"] != 5)
		Fail("The actual UI purchase path must spend only five Karma in total.")
	var/list/ui_data = controls.get_ui_data(lobby)
	var/list/progression = ui_data["character_progression"]
	if(progression["stats_respect"] != 32 || progression["full_respect"] != 30)
		Fail("The widget must show projected Respect after the selected cost.")
	qdel(stats)
	qdel(disciplines)
	qdel(quirks)
	qdel(controls)
	qdel(player.prefs)
	player.prefs = null
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/character_spawn_lifecycle/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/path = "data/pq-spawn-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	var/datum/client_interface/quality_test/player = allocate(/datum/client_interface/quality_test, "quality-spawn-[world.realtime]")
	player.prefs = new(player)
	var/datum/preferences/preferences = player.prefs
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/splats], SPLAT_KINDRED)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/numeric/immortal_age], 50)
	var/datum/preference/path_preference = GLOB.preference_entries[/datum/preference/choiced/vtm_morality]
	preferences.write_preference(path_preference, path_preference.serialize(/datum/morality/power))
	preferences.write_preference(GLOB.preference_entries[/datum/preference/personality], list())
	controller.store.database.set_key(player.ckey, list("pq" = 60))
	var/mob/dead/new_player/lobby = allocate(/mob/dead/new_player)
	lobby.mock_client = player
	player.mob = lobby
	lobby.mind_initialize()
	// Start with an existing pre-migration sheet, then load its new GUID without
	// closing the preferences UI or saving that JSON subtree.
	preferences.save_character()
	var/list/legacy_sheet = preferences.savefile.get_entry("character[preferences.default_slot]")
	legacy_sheet -= "quality_character_id"
	preferences.savefile.save()
	preferences.load_character()
	if(preferences.read_preference(/datum/preference/choiced/splats) != /datum/splat/vampire/kindred || preferences.read_preference(/datum/preference/numeric/immortal_age) != 50 || preferences.read_preference(/datum/preference/choiced/vtm_morality) != /datum/morality/power)
		Fail("The migrated fixture must reload its serialized Kindred splat, age and requested Path before testing job spawn.")
	var/id = preferences.quality_character_id
	var/mob/living/carbon/human/dummy/consistent/preview = allocate(/mob/living/carbon/human/dummy/consistent)
	preferences.apply_prefs_to(preview)
	if(controller.store.read_character(player.ckey, id))
		Fail("Rendering actual preference previews must not create or lock a character record.")
	var/datum/job/job = SSjob.get_job_type(/datum/job/vampire/citizen)
	var/mob/living/carbon/human/body = job.get_spawn_mob(player, run_loc_floor_bottom_left)
	allocated += body
	if(body.quality_finalize_character(player, job) || controller.store.read_character(player.ckey, id))
		Fail("A failed/disconnected spawn must neither create a record nor consume permissions.")
	// Match create_character: transfer the preserved mind and set its original
	// slot/body, append the joined slot, then possess and finalize the real job body.
	lobby.mind.original_character_slot_index = preferences.default_slot
	lobby.mind.transfer_to(body)
	body.mind.set_original_character(body)
	LAZYADD(player.persistent_client.joined_as_slots, "[preferences.default_slot]")
	body.mock_client = player
	player.mob = body
	if(!body.quality_finalize_character(player, body.quality_pending_job))
		Fail("Successful possession must finalize the owning character.")
	var/list/record = controller.store.read_character(player.ckey, id)
	if(!record?["locked"] || record["unlock_ticket"] || body.quality_character_id != id || body.quality_character_account != player.ckey)
		Fail("Successful first spawn must attach stable identity and lock once.")
	if(!get_kindred_splat(body))
		Fail("Actual job preferences must create a Kindred body from the reloaded sheet (saved splat: [preferences.read_preference(/datum/preference/choiced/splats)]).")
	if(record["path"] != "/datum/morality/humanity" || !isnum(record["path_rating"]))
		Fail("Actual first spawn must persist initial Humanity through the canon guard (saved Path: [record["path"]], rating: [record["path_rating"]], save failure: [body.quality_character_save_failure()]).")
	if(body.quality_character_save_failure())
		Fail("The native spawn order must satisfy the exact character save guard: [body.quality_character_save_failure()].")
	var/datum/json_savefile/reloaded_sheet = new(preferences.savefile.path)
	var/list/disk_sheet = reloaded_sheet.get_entry("character[preferences.default_slot]")
	if(disk_sheet?["quality_character_id"] != id)
		Fail("A migrated GUID must survive reopening the physical savefile before its account lock is created.")
	qdel(reloaded_sheet)
	if(!body.quality_learn_discipline_identity(/datum/discipline/temporis))
		Fail("Explicit teaching must preserve its unlocked identity on the actual spawned character.")
	var/list/account = controller.store.read(player.ckey)
	account["pq"] = 30
	account["rcp"] = 0
	account["karma"] = 10
	controller.store.database.set_key(player.ckey, account)
	controller.store.unlock_character(player.ckey, id, "stats")
	var/mob/living/carbon/human/failed = allocate(/mob/living/carbon/human/consistent)
	failed.quality_finalize_character(player, job)
	record = controller.store.read_character(player.ckey, id)
	if(record["unlock_ticket"] != "stats")
		Fail("Another failed spawn must leave an existing paid ticket intact.")
	var/mob/living/carbon/human/next_body = allocate(/mob/living/carbon/human/consistent)
	next_body.mock_client = player
	player.mob = next_body
	next_body.quality_finalize_character(player, job)
	record = controller.store.read_character(player.ckey, id)
	if(record["unlock_ticket"] || !record["locked"])
		Fail("Only the next successfully possessed body may consume the one-spawn edit ticket.")
	var/list/learned = record["learned_disciplines"]
	if(!("/datum/discipline/temporis" in learned) || preferences.discipline_levels["/datum/discipline/temporis"] != 0)
		Fail("A respawn must retain taught choices at zero without granting an additional discipline point pool.")
	preferences.save_character()
	preferences.switch_to_slot(2)
	var/second_id = preferences.quality_character_id
	if(!second_id || second_id == id || preferences.quality_character_record())
		Fail("An unused slot must receive its own free, unplayed identity.")
	preferences.switch_to_slot(1)
	if(preferences.quality_character_id != id || !preferences.quality_character_record())
		Fail("Slot changes and saves must restore the original identity and lock.")
	call(preferences, "remove_current_slot")()
	if(controller.store.read_character(player.ckey, id) || preferences.quality_character_id != second_id)
		Fail("The actual delete-slot action must discard the old character learning and select the other sheet.")
	preferences.switch_to_slot(1)
	if(preferences.quality_character_id == id || preferences.quality_character_id == second_id || preferences.quality_character_record() || length(preferences.discipline_levels))
		Fail("A replacement in the deleted slot must be free, have a new GUID and inherit no discipline learning.")
	account = controller.store.read(player.ckey)
	if(account["pq"] != 30 || account["rcp"] != 0 || account["karma"] != 7)
		Fail("Deleting and replacing a character must preserve account PQ, RCP and Karma without a new charge.")
	qdel(player.prefs)
	player.prefs = null
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	fdel(path)
	fdel("[path].savebac")
#endif
