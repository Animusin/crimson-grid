#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Only the yielding spawn body is replaced; test the real entry serialization.
/mob/dead/new_player/city_entry_probe
	var/spawn_attempts = 0

/mob/dead/new_player/city_entry_probe/city_can_latejoin()
	return TRUE

/mob/dead/new_player/city_entry_probe/city_attempt_late_spawn(rank, villain_entry)
	spawn_attempts++
	sleep(2)
	return TRUE

/datum/unit_test/city_round_budget/villain_concurrent_entry/Run()
	var/mob/dead/new_player/city_entry_probe/candidate = allocate(/mob/dead/new_player/city_entry_probe)
	INVOKE_ASYNC(candidate, TYPE_PROC_REF(/mob/dead/new_player, AttemptLateSpawn), JOB_SABBAT_PACK, TRUE)
	if(!candidate.city_latejoin_pending || candidate.AttemptLateSpawn(JOB_SABBAT_PACK, TRUE) || candidate.spawn_attempts != 1)
		Fail("A second join request must not enter the yielding spawn body while the first request is pending.")
	sleep(3)
	if(candidate.city_latejoin_pending || !candidate.AttemptLateSpawn(JOB_SABBAT_PACK, TRUE) || candidate.spawn_attempts != 2)
		Fail("Completing a spawn request must release the entry guard for a later attempt.")

/datum/unit_test/city_round_budget/villain_panel/Run()
	var/datum/job/pack = SSjob.get_job_type(/datum/job/vampire/sabbatpack)
	var/datum/job/hunter = SSjob.get_job_type(/datum/job/vampire/inquisitor)
	var/datum/job/manor = SSjob.get_job_type(/datum/job/vampire/bogatyr)
	if(!city_villain_job(pack) || !city_villain_job(hunter) || city_villain_job(manor) || !budget.managed_job(manor))
		Fail("The explicit villain panel must contain the crusade and hunters while manor jobs retain ordinary selection and shared capacity.")
	var/datum/preference_middleware/jobs/middleware = allocate(/datum/preference_middleware/jobs)
	var/list/data = middleware.get_constant_data()
	var/list/jobs = data["jobs"]
	if(jobs[pack.title] || jobs[hunter.title] || !jobs[manor.title])
		Fail("The actual normal preferences catalogue must exclude panel jobs and retain the manor.")
	// Exercise a real panel job with deterministic eligible mortal preferences.
	// This panel test must not require a separate Kindred progression module.
	var/mob/dead/new_player/candidate = lobby_player("villain_panel_candidate", list(hunter.title = JP_HIGH))
	var/datum/preferences/preferences = candidate.mock_client.prefs
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/splats], SPLAT_NONE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/numeric/age], 30)
	if(preferences.read_preference(/datum/preference/choiced/splats) != SPLAT_NONE || preferences.read_preference(/datum/preference/numeric/age) != 30)
		Fail("The panel allocation fixture must use an adult mortal who is eligible for the real hunter job.")
	var/old_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PREGAME
	var/html = candidate.city_villain_choices_html()
	SSticker.current_state = old_state
	if(!findtext(html, html_encode(pack.title)) || !findtext(html, "city_villain_pref=") || findtext(html, "city_villain_join="))
		Fail("The real pregame panel must offer preferences rather than a premature spawn link.")
	budget.begin_assignment(FALSE)
	if(!budget.defer_player(candidate, JP_HIGH))
		Fail("A saved hunter preference must participate in native roundstart allocation.")
	budget.finish_deferred_assignments(TRUE)
	budget.end_assignment()
	if(candidate.mind.assigned_role != hunter)
		Fail("A roundstart hunter must receive its actual native job using the baseline antagonist allowance.")

/datum/unit_test/city_round_budget/villain_random_fallback/Run()
	var/datum/job/pack = allocate(/datum/job/vampire/sabbatpack)
	var/datum/job/ordinary = allocate(/datum/job/city_budget_probe)
	SSjob.joinable_occupations = list(pack, ordinary)
	var/mob/dead/new_player/candidate = lobby_player("random_fallback_candidate", list())
	if(!SSjob.give_random_job(candidate) || candidate.mind.assigned_role != ordinary || pack.current_positions)
		Fail("The real random roundstart fallback must select an ordinary role and never force a player into the crusade.")

/datum/unit_test/city_round_budget/villain_profile_serialization/Run()
	var/datum/job/pack = SSjob.get_job_type(/datum/job/vampire/sabbatpack)
	var/mob/dead/new_player/candidate = lobby_player("villain_profile_candidate", list(pack.title = JP_HIGH))
	var/datum/preferences/preferences = candidate.mock_client.prefs
	var/path = "data/city_villain_profile_test_[world.time].json"
	QDEL_NULL(preferences.savefile)
	preferences.path = path
	preferences.savefile = new /datum/json_savefile(path)
	preferences.character_data = null
	preferences.load_and_save = TRUE
	preferences.max_save_slots = 3
	preferences.default_slot = 1
	preferences.write_preference(GLOB.preference_entries[/datum/preference/name/real_name], "First Villain")
	preferences.save_character()
	preferences.savefile.set_entry("character2", list("real_name" = "Other Villain"))
	if(!preferences.city_set_villain_profile(pack, 2))
		Fail("The panel's profile setter must accept an existing alternate character.")
	var/list/on_disk = json_decode(file2text(path))
	var/list/saved_profiles = on_disk["job_assigned_profiles"]
	var/list/current_character = on_disk["character1"]
	var/list/saved_jobs = current_character["job_preferences"]
	if(saved_profiles?[pack.title] != 2 || saved_jobs?[pack.title] != JP_HIGH)
		Fail("Native serialization must retain both the selected per-job profile and the active character's villain priority on disk.")
	for(var/invalid_slot in list(0, 3, 4, -1, 1.5, "2"))
		if(preferences.city_set_villain_profile(pack, invalid_slot) || preferences.job_assigned_profiles?[pack.title] != 2)
			Fail("Invalid or uncreated profile slots must not overwrite the saved selection.")
	if(preferences.city_set_villain_profile(SSjob.get_job_type(/datum/job/vampire/citizen), 2))
		Fail("The villain profile callback must not edit an ordinary job's assignment.")
	var/old_state = SSticker.current_state
	SSticker.current_state = GAME_STATE_PREGAME
	if(!findtext(candidate.city_villain_choices_html(), "Slot 2: Other Villain"))
		Fail("The actual panel must show the selected alternate character, not the active character's name.")
	if(!preferences.city_set_villain_profile(pack, null))
		Fail("The explicit reset must restore the native active-slot behavior.")
	on_disk = json_decode(file2text(path))
	saved_profiles = on_disk["job_assigned_profiles"]
	if(saved_profiles?[pack.title] || !findtext(candidate.city_villain_choices_html(), "Active slot 1: First Villain"))
		Fail("Reset must remove the mapping on disk and show the actual active character in the panel.")
	SSticker.current_state = old_state
	QDEL_NULL(preferences.savefile)
	fdel(path)
	fdel("[path].savebac")

#endif
