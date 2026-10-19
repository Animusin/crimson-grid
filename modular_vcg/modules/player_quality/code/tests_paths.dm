#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/player_quality/paths_policy/Run()
	if(quality_initial_path(/datum/morality/power, 200, null) != /datum/morality/humanity || quality_initial_path(/datum/morality/power, 201, null) != /datum/morality/power)
		Fail("Alternative initial Paths require actual Elder age, including the 200/201 boundary.")
	if(quality_initial_path(/datum/morality/power, 0, FACTION_SABBAT) != /datum/morality/power || quality_initial_path(/obj/item, 500, FACTION_SABBAT) != /datum/morality/humanity)
		Fail("The actual Sabbat job exemption must allow valid Paths and reject non-Path types.")
	var/list/training = list()
	if(!quality_credit_path_lesson(training, "night-a") || quality_credit_path_lesson(training, "night-a") || !quality_credit_path_lesson(training, "night-b") || !quality_credit_path_lesson(training, "night-c"))
		Fail("A lesson can count once per distinct round without a timer grind.")
	var/list/nights = training["rounds"]
	if(length(nights) != 3)
		Fail("Repeated lessons in one round must not stand in for three nights.")
	if(quality_path_teaching_rating(-1, 3) != 1 || quality_path_teaching_rating(8, 3) != 3 || quality_path_teaching_rating(8, 2) != 2)
		Fail("The saved teaching outcome must remain within 1..3 and the teacher's rating.")

/datum/unit_test/player_quality/paths_preview_isolation/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/path = "data/pq-path-preview-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	var/mob/living/carbon/human/character = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/preview = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/quality_test/player = allocate(/datum/client_interface/quality_test, "qualitypathpreview")
	player.prefs = new(player)
	character.make_kindred()
	character.quality_character_account = player.ckey
	character.quality_character_id = "preview-original"
	player.prefs.quality_character_id = character.quality_character_id
	player.prefs.apply_stats_from_prefs(character)
	var/datum/st_stat/morality_path/morality/preference_stat = player.prefs.preference_storyteller_stats[STAT_MORALITY]
	preference_stat.morality_path = new /datum/morality/humanity(preview)
	var/datum/morality/original_preference_path = preference_stat.morality_path
	preference_stat.set_score(3)
	preference_stat.set_points(4)
	preference_stat.freebie_cost_spent = 2
	preference_stat.add_stat_mod(-1, "preview-test")
	preference_stat.add_auto_successes(1, "preview-test")
	preference_stat.add_stat_clamps(7, "preview-test")
	controller.store.create_character_record(player.ckey, character.quality_character_id, list("path" = "/datum/morality/power", "path_rating" = 2, "learned_paths" = list("/datum/morality/power"), "training" = list()))
	if(!character.quality_apply_character_path(player, SSjob.get_job_type(/datum/job/vampire/citizen), controller.store.read_character(player.ckey, character.quality_character_id)))
		Fail("The actual body must apply its persistent Path before preview isolation can be tested.")
	var/datum/st_stat/morality_path/morality/live_stat = character.storyteller_stats[STAT_MORALITY]
	var/datum/morality/live_path = get_morality_path(character)
	if(live_stat == preference_stat || preference_stat.morality_path != original_preference_path || QDELETED(original_preference_path) || preference_stat.get_pure_score() != 3)
		Fail("Restoring a live Path must not replace/delete the shared preference Path or mutate its score.")
	if(live_stat.get_points() != 4 || live_stat.freebie_cost_spent != 2 || live_stat.get_bonus_score() != -1 || live_stat.get_auto_success_score() != 1 || live_stat.get_score() != 2)
		Fail("Detaching morality must preserve points, freebie spending and active modifiers.")
	player.prefs.apply_stats_from_prefs(preview)
	var/datum/preference/choiced/vtm_morality/path_preference = GLOB.preference_entries[/datum/preference/choiced/vtm_morality]
	path_preference.apply_to_human(preview, /datum/morality/humanity, player.prefs)
	var/datum/st_stat/conviction = player.prefs.preference_storyteller_stats[STAT_CONVICTION]
	var/datum/st_stat/instinct = player.prefs.preference_storyteller_stats[STAT_INSTINCT]
	conviction.set_score(5)
	instinct.set_score(5)
	update_middleware_stats(player.prefs.preference_storyteller_stats)
	preference_stat.set_points(99)
	preference_stat.add_stat_mod(5, "preview-test")
	preference_stat.add_auto_successes(4, "preview-test")
	preference_stat.add_stat_clamps(1, "preview-test")
	if(preference_stat.get_pure_score() == 2 || live_stat.get_pure_score() != 2 || get_morality_path(character) != live_path || get_morality_path(preview) == live_path)
		Fail("Real preview application and virtue middleware must not change the live Path or rating.")
	if(live_stat.get_points() != 4 || live_stat.get_bonus_score() != -1 || live_stat.get_auto_success_score() != 1 || live_stat.get_score() != 2)
		Fail("Preview mutations must not alias live morality modifier lists, clamps or points.")
	player.prefs.quality_character_id = "preview-other-slot"
	player.prefs.value_cache[/datum/preference/numeric/immortal_age] = 0
	path_preference.apply_to_human(preview, /datum/morality/humanity, player.prefs)
	update_middleware_stats(player.prefs.preference_storyteller_stats)
	if(get_morality_path(character) != live_path || live_stat.get_pure_score() != 2 || controller.store.read_character(player.ckey, "preview-other-slot"))
		Fail("Switching preview slots must neither create a record nor alter the spawned character's Path.")
	var/list/record = controller.store.read_character(player.ckey, character.quality_character_id)
	if(record["path"] != "/datum/morality/power" || record["path_rating"] != 2)
		Fail("Preview/middleware activity must leave the authoritative saved Path untouched.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	qdel(player.prefs)
	player.prefs = null
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/paths_persistence/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_round = controller.round_token
	var/path = "data/pq-paths-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_token = "night-c"
	var/mob/living/carbon/human/student = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/teacher = allocate(/mob/living/carbon/human/consistent)
	student.forceMove(run_loc_floor_bottom_left)
	teacher.forceMove(run_loc_floor_bottom_left)
	var/datum/client_interface/quality_test/student_client = allocate(/datum/client_interface/quality_test, "qualitypathstudent")
	var/datum/client_interface/quality_test/teacher_client = allocate(/datum/client_interface/quality_test, "qualitypathteacher")
	student_client.prefs = new(student_client)
	teacher_client.prefs = new(teacher_client)
	student.mock_client = student_client
	teacher.mock_client = teacher_client
	student_client.mob = student
	teacher_client.mob = teacher
	student.mind_initialize()
	teacher.mind_initialize()
	student.mind.key = student_client.key
	teacher.mind.key = teacher_client.key
	student.make_kindred()
	teacher.make_kindred()
	student.quality_character_account = student_client.ckey
	student.quality_character_id = "student-character"
	teacher.quality_character_account = teacher_client.ckey
	teacher.quality_character_id = "teacher-character"
	student_client.prefs.quality_character_id = student.quality_character_id
	teacher_client.prefs.quality_character_id = teacher.quality_character_id
	student_client.prefs.value_cache[/datum/preference/choiced/splats] = /datum/splat/vampire/kindred
	student_client.prefs.value_cache[/datum/preference/numeric/immortal_age] = 50
	student_client.prefs.value_cache[/datum/preference/choiced/vtm_morality] = /datum/morality/power
	if(student_client.prefs.quality_preference_path(/datum/morality/power) != /datum/morality/humanity || controller.store.read_character(student_client.ckey, student.quality_character_id))
		Fail("A preview must enforce initial Humanity without creating a character record.")
	controller.store.create_character_record(student_client.ckey, student.quality_character_id, list("path" = "/datum/morality/humanity", "path_rating" = 2, "learned_paths" = list("/datum/morality/humanity"), "training" = list()))
	controller.store.create_character_record(teacher_client.ckey, teacher.quality_character_id, list("path" = "/datum/morality/power", "path_rating" = 3, "learned_paths" = list("/datum/morality/power"), "training" = list()))
	student.quality_apply_character_path(student_client, SSjob.get_job_type(/datum/job/vampire/citizen), controller.store.read_character(student_client.ckey, student.quality_character_id))
	teacher.quality_apply_character_path(teacher_client, SSjob.get_job_type(/datum/job/vampire/citizen), controller.store.read_character(teacher_client.ckey, teacher.quality_character_id))
	if(student.st_get_stat(STAT_MORALITY) != 2 || get_morality_path(student)?.type != /datum/morality/humanity)
		Fail("A forged preference must not replace the persistent current Path.")
	student.st_set_stat(STAT_MORALITY, 0)
	var/list/record = controller.store.read_character(student_client.ckey, student.quality_character_id)
	if(record["path_rating"] != 2)
		Fail("A direct virtue/stat edit must not manufacture a real degeneration event.")
	student.quality_apply_character_path(student_client, SSjob.get_job_type(/datum/job/vampire/citizen), record)
	if(student.st_get_stat(STAT_MORALITY) != 2)
		Fail("Applying preferences again must restore the saved Path rating.")
	var/list/training = list("id" = "training-one", "original_path" = "/datum/morality/humanity", "target_path" = "/datum/morality/power", "teacher_id" = teacher.quality_character_id, "teacher_account" = teacher_client.ckey, "rounds" = list("night-a", "night-b", "night-c"), "roll" = 2)
	controller.store.write_character(student_client.ckey, student.quality_character_id, list("training" = training))
	student.st_set_stat(STAT_MORALITY, 0)
	if(student.quality_try_path_initiation(teacher))
		Fail("Rating zero without actual degeneration must not unlock a Path.")
	SEND_SIGNAL(student, COMSIG_LIVING_CHANGED_HUMANITY, -2)
	record = controller.store.read_character(student_client.ckey, student.quality_character_id)
	training = record["training"]
	if(!training["renounced"] || !training["degeneration_seen"] || record["path_rating"] != 0)
		Fail("The real morality-change signal must persist genuine degeneration to zero.")
	student.quality_try_path_initiation(teacher)
	if(!student.quality_path_initiation_pending || !HAS_TRAIT(student, TRAIT_IN_FRENZY))
		Fail("A qualified initiation must enter the existing frenzy status effect.")
	var/first_attempt = student.quality_path_initiation_attempt
	ADD_TRAIT(teacher, TRAIT_KNOCKEDOUT, "path-test")
	if(student.quality_finish_path_initiation(WEAKREF(teacher), "training-one", first_attempt))
		Fail("An unconscious teacher must interrupt the initiation.")
	record = controller.store.read_character(student_client.ckey, student.quality_character_id)
	training = record["training"]
	if(training["roll"] != 2 || record["path"] != "/datum/morality/humanity")
		Fail("Interruption must preserve the snapshotted roll and original Path.")
	REMOVE_TRAIT(teacher, TRAIT_KNOCKEDOUT, "path-test")
	student.quality_try_path_initiation(teacher)
	var/current_attempt = student.quality_path_initiation_attempt
	student.quality_finish_path_initiation(WEAKREF(teacher), "training-one", first_attempt)
	if(!student.quality_path_initiation_pending)
		Fail("A stale callback must not finish or cancel a newer retry.")
	controller.store.write_character(student_client.ckey, student.quality_character_id, list("unlock_ticket" = TRUE, "learned_disciplines" = list("/datum/discipline/auspex" = 2)))
	if(!student.quality_finish_path_initiation(WEAKREF(teacher), "training-one", current_attempt))
		Fail("A valid same-teacher retry must complete with its stored roll.")
	record = controller.store.read_character(student_client.ckey, student.quality_character_id)
	var/list/disciplines = record["learned_disciplines"]
	var/list/known = record["learned_paths"]
	if(record["path"] != "/datum/morality/power" || record["path_rating"] != 2 || !("/datum/morality/power" in known) || !record["unlock_ticket"] || disciplines["/datum/discipline/auspex"] != 2)
		Fail("Completion must grant the Path while preserving concurrent unlock and discipline fields.")
	student.quality_apply_character_path(student_client, SSjob.get_job_type(/datum/job/vampire/citizen), record)
	if(get_morality_path(student)?.type != /datum/morality/power || student.st_get_stat(STAT_MORALITY) != 2)
		Fail("A completed Path and its rating must survive preference reapplication.")
	// Death during the vulnerable interval cannot be a free resurrection/conversion.
	teacher.quality_set_live_path(/datum/morality/humanity, 3)
	controller.store.write_character(teacher_client.ckey, teacher.quality_character_id, list("learned_paths" = list("/datum/morality/humanity")))
	training = list("id" = "training-death", "original_path" = "/datum/morality/power", "target_path" = "/datum/morality/humanity", "teacher_id" = teacher.quality_character_id, "teacher_account" = teacher_client.ckey, "rounds" = list("night-a", "night-b", "night-c"), "roll" = 1, "renounced" = TRUE, "degeneration_seen" = TRUE)
	controller.store.write_character(student_client.ckey, student.quality_character_id, list("training" = training, "path_rating" = 0))
	student.st_set_stat(STAT_MORALITY, 0)
	student.quality_try_path_initiation(teacher)
	var/death_attempt = student.quality_path_initiation_attempt
	student.death()
	if(student.quality_finish_path_initiation(WEAKREF(teacher), "training-death", death_attempt) || student.stat != DEAD)
		Fail("A dead student must remain dead and retain the interrupted initiation.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.round_token = old_round
	qdel(student_client.prefs)
	student_client.prefs = null
	qdel(teacher_client.prefs)
	teacher_client.prefs = null
	fdel(path)
	fdel("[path].savebac")
/mob/living/carbon/human/consistent/quality_embrace_test/prompt_permanent_embrace()
	// Suppress the later confirmation dialog; exercise the real Embrace itself.
	return

/datum/unit_test/player_quality/paths_inround_embrace/proc/fail_degeneration_roll(datum/source, datum/storyteller_roll/roll)
	SIGNAL_HANDLER
	// Exercise the normal degeneration flow with a deterministic failed roll.
	roll.successes_needed = INFINITY

/datum/unit_test/player_quality/paths_inround_embrace/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/path = "data/pq-embrace-path-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	var/mob/living/carbon/human/sire = allocate(/mob/living/carbon/human/consistent)
	sire.make_kindred(clan = GLOB.vampire_clans[/datum/subsplat/vampire_clan/brujah])
	var/mob/dead/observer/spectator = allocate(/mob/dead/observer)
	GLOB.player_list |= spectator
	for(var/was_ghoul in list(FALSE, TRUE))
		var/mob/living/carbon/human/childe = allocate(/mob/living/carbon/human/consistent/quality_embrace_test)
		var/datum/client_interface/quality_test/player = allocate(/datum/client_interface/quality_test, "qualityembrace[was_ghoul]")
		player.prefs = new(player)
		player.prefs.apply_stats_from_prefs(childe)
		var/datum/st_stat/morality_path/morality/preference_stat = player.prefs.preference_storyteller_stats[STAT_MORALITY]
		preference_stat.set_score(7)
		childe.st_set_stat(STAT_CONSCIENCE, 0)
		childe.st_set_stat(STAT_SELF_CONTROL, 5)
		childe.quality_character_id = "already-joined-[was_ghoul]"
		childe.quality_character_account = player.ckey
		player.prefs.quality_character_id = childe.quality_character_id
		controller.store.create_character_record(player.ckey, childe.quality_character_id, list(
			"locked" = TRUE,
			"unlock_ticket" = "stats",
			"learned_disciplines" = list("/datum/discipline/temporis" = 0),
			"learned_paths" = list(),
		))
		if(was_ghoul)
			childe.make_ghoul(sire)
		sire.embrace_target(childe)
		var/list/record = controller.store.read_character(player.ckey, childe.quality_character_id)
		if(!get_kindred_splat(childe) || record["path"] != "/datum/morality/humanity" || record["path_rating"] != 5 || controller.store.respect(player.ckey) != 0)
			Fail("A real mortal/ghoul Embrace must initialize saved Humanity without retrospectively imposing the Kindred Respect gate.")
		var/list/learned = record["learned_disciplines"]
		if(record["unlock_ticket"] != "stats" || !("/datum/discipline/temporis" in learned) || learned["/datum/discipline/temporis"] != 0 || !record["locked"])
			Fail("An Embrace must preserve the joined character's lock, pending edit ticket and taught discipline identities.")
		if(childe.storyteller_stats[STAT_MORALITY] == preference_stat || preference_stat.get_pure_score() != 7)
			Fail("Embrace must detach morality before initializing the body rather than editing its preference/preview stat.")
		controller.store.write_character(player.ckey, childe.quality_character_id, list("training" = list("original_path" = "/datum/morality/humanity", "teacher_account" = "offline-teacher", "teacher_id" = "offline-character")))
		var/datum/splat/vampire/kindred/kindred = get_kindred_splat(childe)
		RegisterSignal(childe, COMSIG_LIVING_PRE_DICE_ROLLED, PROC_REF(fail_degeneration_roll))
		kindred.adjust_morality(childe, -5, 0, TRUE)
		UnregisterSignal(childe, COMSIG_LIVING_PRE_DICE_ROLLED)
		record = controller.store.read_character(player.ckey, childe.quality_character_id)
		var/list/training = record["training"]
		if(record["path_rating"] != 0 || !training["renounced"] || !training["degeneration_seen"] || preference_stat.get_pure_score() != 7)
			Fail("Actual degeneration after an in-round Embrace must persist its score and the Path initiation prerequisites.")
		// Reinitializing the same transformed character must honor saved learning.
		controller.store.write_character(player.ckey, childe.quality_character_id, list("path" = "/datum/morality/power", "path_rating" = 2, "learned_paths" = list("/datum/morality/power")))
		childe.quality_initialize_embraced_path()
		if(get_morality_path(childe)?.type != /datum/morality/power || childe.st_get_stat(STAT_MORALITY) != 2)
			Fail("An existing learned Path must survive a later Embrace instead of being erased by Humanity initialization.")
		qdel(player.prefs)
		player.prefs = null
	var/mob/living/carbon/human/dummy/preview = allocate(/mob/living/carbon/human/dummy)
	preview.make_kindred()
	preview.quality_character_id = "preview-only"
	preview.quality_character_account = "qualitypreviewembrace"
	if(preview.quality_initialize_embraced_path() || controller.store.read_character(preview.quality_character_account, preview.quality_character_id))
		Fail("The Embrace persistence helper must not create records for previews or unjoined sheets.")
	GLOB.player_list -= spectator
	qdel(controller.store)
	controller.store = old_store
	fdel(path)
	fdel("[path].savebac")
#endif
