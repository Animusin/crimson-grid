/// Path persistence is character-scoped. Actual spawn, not previews, creates
/// the record and supplies the authoritative job, account and character ID.
/datum/config_entry/number/path_training_rounds
	default = 3
	min_val = 1

/datum/config_entry/number/path_initiation_frenzy_seconds
	default = 15
	min_val = 1

/datum/config_entry/number/path_teaching_difficulty
	default = 6
	min_val = 2
	max_val = 10

/mob/living/carbon/human
	var/quality_path_initiation_pending = FALSE
	var/quality_path_initiation_attempt = 0
	var/datum/weakref/quality_path_frenzy_ref
	var/datum/st_stat/morality_path/morality/quality_owned_morality

/// apply_stats_from_prefs copies its list, but the stat datums still belong to
/// preferences and preview mobs. Only the persistent body's morality is detached.
/datum/st_stat/morality_path/morality/proc/quality_copy_for_body()
	var/datum/st_stat/morality_path/morality/copied = new type
	copied.min_score = min_score
	copied.max_score = max_score
	copied.starting_score = starting_score
	copied.freebie_cost_spent = freebie_cost_spent
	copied.set_score(get_pure_score())
	copied.set_points(get_points())
	copied.modifiers = modifiers?.Copy()
	copied.auto_successes = auto_successes?.Copy()
	copied.stat_clamps = stat_clamps?.Copy()
	copied.update_modifiers()
	copied.update_auto_successes()
	copied.update_stat_clamps()
	// The preference's Path also remains owned by the preference/preview datum.
	return copied

/mob/living/carbon/human/proc/quality_detach_morality()
	var/datum/st_stat/morality_path/morality/current = storyteller_stats[STAT_MORALITY]
	if(!current)
		return FALSE
	if(current == quality_owned_morality)
		return TRUE
	quality_owned_morality = current.quality_copy_for_body()
	storyteller_stats[STAT_MORALITY] = quality_owned_morality
	return TRUE

/datum/storyteller_roll/quality_path_teaching
	bumper_text = "Path initiation"
	applicable_stats = list(STAT_CHARISMA, STAT_LEADERSHIP)
	numerical = TRUE
	roll_output_type = ROLL_FLAG_ROLLER|ROLL_FLAG_TARGET|ROLL_FLAG_ADMIN

/proc/quality_valid_path(path_type)
	return ispath(path_type, /datum/morality) && path_type != /datum/morality && length(initial(path_type:name))

/// Never send an old lock/ticket/discipline snapshot back to the character store.
/proc/quality_write_path_fields(account, character_id, list/record)
	if(!islist(record))
		return FALSE
	var/list/fields = list()
	for(var/key in list("path", "path_rating", "training", "learned_paths"))
		if(key in record)
			fields[key] = record[key]
	return SSplayer_quality?.store?.write_character(account, character_id, fields)

/proc/quality_initial_path(path_type, immortal_age, faction)
	if(!quality_valid_path(path_type))
		return /datum/morality/humanity
	if(path_type == /datum/morality/humanity || (isnum(immortal_age) && immortal_age > 200) || faction == FACTION_SABBAT)
		return path_type
	return /datum/morality/humanity

/datum/preferences/proc/quality_preference_path(path_type)
	if(!SSplayer_quality?.store)
		return path_type
	var/list/record = SSplayer_quality?.store?.read_character(parent?.ckey, quality_character_id)
	var/saved_path = text2path(record?["path"])
	if(quality_valid_path(saved_path))
		return saved_path
	// Preview mobs have no authoritative job. A young Sabbat character receives
	// its requested initial Path in quality_apply_character_path after spawning.
	return quality_initial_path(path_type, respect_immortal_age(), null)

/datum/preference_middleware/quality_paths/pre_set_preference(mob/user, preference, value)
	if(preference != "morality_path")
		return FALSE
	var/list/record = SSplayer_quality?.store?.read_character(preferences.parent?.ckey, preferences.quality_character_id)
	var/saved_path = text2path(record?["path"])
	if(!quality_valid_path(saved_path))
		return FALSE
	var/datum/preference/path_preference = GLOB.preference_entries[/datum/preference/choiced/vtm_morality]
	if(path_preference.deserialize(value, preferences) == saved_path)
		return FALSE
	to_chat(user, span_warning("Your current Path belongs to this character. Changing it requires an in-game teacher and initiation."))
	return TRUE

/// Preserve the existing creation formula; this is not a new growth reward.
/mob/living/carbon/human/proc/quality_initial_path_rating(path_type)
	if(initial(path_type:alignment) == MORALITY_ENLIGHTENMENT)
		return clamp(st_get_stats(list(STAT_CONVICTION, STAT_INSTINCT), include_bonus = TRUE), 0, 10)
	return clamp(st_get_stats(list(STAT_CONSCIENCE, STAT_SELF_CONTROL), include_bonus = TRUE), 0, 10)

/mob/living/carbon/human/proc/quality_apply_character_path(client/player, datum/job/job, list/record)
	if(!get_kindred_splat(src) || !player || !islist(record) || !quality_character_id || !quality_character_account)
		return FALSE
	if(!quality_detach_morality())
		return FALSE
	var/path_type = text2path(record["path"])
	if(!quality_valid_path(path_type))
		var/requested_path = player.prefs.read_preference(/datum/preference/choiced/vtm_morality)
		path_type = quality_initial_path(requested_path, player.prefs.respect_immortal_age(), job?.faction)
		record["path"] = "[path_type]"
		record["path_rating"] = quality_initial_path_rating(path_type)
		if(path_type != requested_path)
			to_chat(src, span_warning("This character begins on Humanity. An initial alternative Path requires Elder age or a Sabbat role; other characters must learn it in play."))
	if(!isnum(record["path_rating"]))
		record["path_rating"] = quality_initial_path_rating(path_type)
	record["path_rating"] = clamp(record["path_rating"], 0, 10)
	if(!islist(record["learned_paths"]))
		record["learned_paths"] = list()
	var/list/learned = record["learned_paths"]
	learned |= "[path_type]"
	if(!islist(record["training"]))
		record["training"] = list()
	if(!quality_write_path_fields(quality_character_account, quality_character_id, record))
		return FALSE
	quality_set_live_path(path_type, record["path_rating"])
	RegisterSignal(src, COMSIG_LIVING_CHANGED_HUMANITY, PROC_REF(quality_path_rating_changed), override = TRUE)
	return TRUE

/mob/living/carbon/human/proc/quality_set_live_path(path_type, rating)
	var/datum/st_stat/morality_path/morality/stat_morality = storyteller_stats[STAT_MORALITY]
	if(!stat_morality || !quality_valid_path(path_type))
		return FALSE
	QDEL_NULL(stat_morality.morality_path)
	stat_morality.morality_path = new path_type(src)
	st_set_stat(STAT_MORALITY, clamp(rating, 0, 10))
	return TRUE

/mob/living/carbon/human/proc/quality_path_rating_changed(datum/source, change)
	SIGNAL_HANDLER
	if(!quality_character_id || !quality_character_account || !get_kindred_splat(src))
		return
	var/list/record = SSplayer_quality?.store?.read_character(quality_character_account, quality_character_id)
	var/datum/st_stat/morality_path/morality/stat_morality = storyteller_stats[STAT_MORALITY]
	if(!islist(record) || !stat_morality?.morality_path)
		return
	record["path"] = "[stat_morality.morality_path.type]"
	record["path_rating"] = st_get_stat(STAT_MORALITY)
	var/list/training = record["training"]
	if(islist(training) && record["path_rating"] > 0)
		training["renounced"] = FALSE
	if(islist(training) && training["original_path"] == record["path"] && change < 0)
		training["degeneration_seen"] = TRUE
		if(record["path_rating"] == 0)
			training["renounced"] = TRUE
	quality_write_path_fields(quality_character_account, quality_character_id, record)
	if(training?["renounced"])
		for(var/mob/living/carbon/human/teacher as anything in GLOB.player_list)
			if(teacher.quality_character_account == training["teacher_account"] && teacher.quality_character_id == training["teacher_id"])
				INVOKE_ASYNC(src, PROC_REF(quality_try_path_initiation), teacher)
				break

/proc/quality_path_teaching_rating(successes, teacher_rating)
	return min(clamp(successes, 1, 3), teacher_rating)

/// One mutually acknowledged lesson per round. No duration grind, fake
/// degeneration, or minimum score protection is attached to these credits.
/proc/quality_credit_path_lesson(list/training, round_token)
	if(!islist(training) || !istext(round_token) || !length(round_token))
		return FALSE
	if(!islist(training["rounds"]))
		training["rounds"] = list()
	var/list/rounds = training["rounds"]
	if(round_token in rounds)
		return FALSE
	rounds |= round_token
	return TRUE

/mob/living/carbon/human/proc/quality_path_pair_valid(mob/living/carbon/human/teacher)
	return istype(teacher) && teacher != src && !QDELETED(teacher) && get_kindred_splat(src) && get_kindred_splat(teacher) \
		&& GET_CLIENT(src) && GET_CLIENT(teacher) && stat != DEAD && teacher.stat != DEAD && !IS_UNCONSCIOUS_OR_CRIT(src) && !IS_UNCONSCIOUS_OR_CRIT(teacher) \
		&& quality_character_id && teacher.quality_character_id && quality_character_account && teacher.quality_character_account \
		&& quality_character_account != teacher.quality_character_account && IN_GIVEN_RANGE(src, teacher, 1)

/mob/living/carbon/human/proc/quality_path_teacher_matches(mob/living/carbon/human/teacher, list/training)
	if(!quality_path_pair_valid(teacher) || !islist(training))
		return FALSE
	var/datum/morality/teacher_path = get_morality_path(teacher)
	if(training["teacher_id"] != teacher.quality_character_id || training["teacher_account"] != teacher.quality_character_account \
		|| !teacher_path || training["target_path"] != "[teacher_path.type]" || teacher.st_get_stat(STAT_MORALITY) < 1)
		return FALSE
	var/list/teacher_record = SSplayer_quality?.store?.read_character(teacher.quality_character_account, teacher.quality_character_id)
	var/list/known_paths = teacher_record?["learned_paths"]
	return islist(known_paths) && (training["target_path"] in known_paths)

/client/verb/teach_path()
	set name = "Offer Path Lesson"
	set category = "IC"
	set desc = "Offer a nearby Kindred a mutually agreed lesson in your current Path."
	var/mob/living/carbon/human/teacher = mob
	if(!istype(teacher) || !get_kindred_splat(teacher) || !teacher.quality_character_id || !teacher.quality_character_account)
		return
	var/datum/morality/teacher_path = get_morality_path(teacher)
	if(!teacher_path || teacher.st_get_stat(STAT_MORALITY) < 1)
		to_chat(src, span_warning("You must follow your Path with at least one dot to teach it."))
		return
	var/list/candidates = list()
	for(var/mob/living/carbon/human/student in oview(1, teacher))
		if(student.quality_path_pair_valid(teacher))
			candidates["[student] ([length(candidates) + 1])"] = student
	var/choice = tgui_input_list(src, "Choose a nearby student.", "Path lesson", candidates)
	var/mob/living/carbon/human/student = candidates[choice]
	if(!student?.quality_path_pair_valid(teacher))
		return
	var/teacher_id = teacher.quality_character_id
	var/student_id = student.quality_character_id
	var/path_type = teacher_path.type
	var/datum/morality/original_path = get_morality_path(student)
	if(!original_path || original_path.type == path_type)
		to_chat(src, span_warning("They already follow your Path."))
		return
	var/original_path_type = original_path.type
	var/accepted = tgui_alert(student, "[teacher] offers a lesson in [teacher_path.name]. Initiation requires [CONFIG_GET(number/path_training_rounds)] distinct rounds with the same teacher and abandoning your original Path through real degeneration to zero. One agreed lesson counts per round. When ready, accepting triggers a short frenzy and a permanent change to this Path at 1–3 dots, limited by your teacher. Accept?", "Path lesson", list("Accept", "Decline"))
	if(accepted != "Accept" || !student.quality_path_pair_valid(teacher) || teacher.quality_character_id != teacher_id || student.quality_character_id != student_id)
		return
	var/datum/morality/current_teacher_path = get_morality_path(teacher)
	var/datum/morality/current_student_path = get_morality_path(student)
	if(current_teacher_path?.type != path_type || current_student_path?.type != original_path_type)
		return
	student.quality_record_path_lesson(teacher, path_type)

/mob/living/carbon/human/proc/quality_record_path_lesson(mob/living/carbon/human/teacher, path_type)
	if(!quality_path_pair_valid(teacher) || !quality_valid_path(path_type))
		return FALSE
	var/list/record = SSplayer_quality?.store?.read_character(quality_character_account, quality_character_id)
	var/datum/morality/current_path = get_morality_path(src)
	if(!islist(record) || !current_path || current_path.type == path_type)
		return FALSE
	var/list/training = record["training"]
	if(!islist(training) || !length(training))
		training = list(
			"id" = "[world.realtime]-[rand(1, 1000000)]",
			"original_path" = "[current_path.type]",
			"target_path" = "[path_type]",
			"teacher_id" = teacher.quality_character_id,
			"teacher_account" = teacher.quality_character_account,
			"rounds" = list(),
		)
		record["training"] = training
	if(training["original_path"] != "[current_path.type]" || training["target_path"] != "[path_type]" || !quality_path_teacher_matches(teacher, training))
		to_chat(src, span_warning("Your existing training is bound to its original Path and the same teacher. It cannot be replaced through another lesson."))
		return FALSE
	var/credited = quality_credit_path_lesson(training, SSplayer_quality.round_token)
	if(!quality_write_path_fields(quality_character_account, quality_character_id, record))
		return FALSE
	var/list/rounds = training["rounds"]
	to_chat(src, span_notice("[credited ? "Lesson recorded" : "This round's lesson is already recorded"]: [length(rounds)]/[CONFIG_GET(number/path_training_rounds)] distinct rounds."))
	log_game("Path lesson: [quality_character_account]/[quality_character_id] with [teacher.quality_character_account]/[teacher.quality_character_id] in [training["target_path"]], round [SSplayer_quality.round_token].")
	quality_try_path_initiation(teacher)
	return TRUE

/mob/living/carbon/human/proc/quality_try_path_initiation(mob/living/carbon/human/teacher)
	if(quality_path_initiation_pending || HAS_TRAIT(src, TRAIT_IN_FRENZY))
		return FALSE
	var/list/record = SSplayer_quality?.store?.read_character(quality_character_account, quality_character_id)
	var/list/training = record?["training"]
	var/list/rounds = training?["rounds"]
	var/datum/morality/current_path = get_morality_path(src)
	if(!quality_path_teacher_matches(teacher, training) || !islist(rounds) || length(rounds) < CONFIG_GET(number/path_training_rounds) \
		|| !(SSplayer_quality.round_token in rounds) || !training["renounced"] || !training["degeneration_seen"] \
		|| training["original_path"] != "[current_path?.type]" || st_get_stat(STAT_MORALITY) != 0)
		return FALSE
	if(!isnum(training["roll"]))
		var/datum/storyteller_roll/quality_path_teaching/roll = new
		roll.difficulty = CONFIG_GET(number/path_teaching_difficulty)
		training["roll"] = quality_path_teaching_rating(roll.st_roll(teacher, src), teacher.st_get_stat(STAT_MORALITY))
		qdel(roll)
		if(!quality_write_path_fields(quality_character_account, quality_character_id, record))
			return FALSE
	// The roll is durable before the vulnerable frenzy; interrupted retries
	// retain it and must return to this same, still-valid teacher.
	// Use the existing frenzy status directly. enter_frenzy_mode also schedules
	// an unrelated three-minute global exit which could calm a later frenzy.
	var/datum/status_effect/frenzy/frenzy = apply_status_effect(/datum/status_effect/frenzy/vampire_hunger, teacher)
	if(!frenzy)
		return FALSE
	set_jitter_if_lower(CONFIG_GET(number/path_initiation_frenzy_seconds) SECONDS)
	to_chat(src, span_bolddanger("Your last convictions collapse. FRENZY."))
	SEND_SOUND(src, sound('modular_darkpack/modules/frenzy/sounds/frenzy.ogg', volume = 50))
	message_admins("[ADMIN_LOOKUPFLW(src)] entered a brief Path-initiation frenzy with [ADMIN_LOOKUPFLW(teacher)].")
	quality_path_initiation_pending = TRUE
	quality_path_initiation_attempt++
	quality_path_frenzy_ref = WEAKREF(frenzy)
	addtimer(CALLBACK(src, PROC_REF(quality_finish_path_initiation), WEAKREF(teacher), training["id"], quality_path_initiation_attempt), CONFIG_GET(number/path_initiation_frenzy_seconds) SECONDS)
	return TRUE

/mob/living/carbon/human/proc/quality_finish_path_initiation(datum/weakref/teacher_ref, training_id, attempt)
	if(attempt != quality_path_initiation_attempt || !quality_path_initiation_pending)
		return FALSE
	var/datum/status_effect/frenzy/frenzy = quality_path_frenzy_ref?.resolve()
	quality_path_frenzy_ref = null
	quality_path_initiation_pending = FALSE
	var/mob/living/carbon/human/teacher = teacher_ref?.resolve()
	var/list/record = SSplayer_quality?.store?.read_character(quality_character_account, quality_character_id)
	var/list/training = record?["training"]
	var/list/rounds = training?["rounds"]
	var/datum/morality/current_path = get_morality_path(src)
	var/can_finish = frenzy && quality_path_teacher_matches(teacher, training) && training["id"] == training_id \
		&& islist(rounds) && length(rounds) >= CONFIG_GET(number/path_training_rounds) && training["renounced"] \
		&& training["original_path"] == "[current_path?.type]" && st_get_stat(STAT_MORALITY) == 0
	if(frenzy)
		qdel(frenzy)
	if(!can_finish)
		to_chat(src, span_warning("The initiation was interrupted. Your saved lesson history and initiation roll remain; return to the same teacher to retry."))
		return FALSE
	return quality_commit_path_initiation(record, teacher.st_get_stat(STAT_MORALITY))

/mob/living/carbon/human/proc/quality_commit_path_initiation(list/record, teacher_rating)
	var/list/training = record?["training"]
	var/path_type = text2path(training?["target_path"])
	if(!quality_valid_path(path_type) || !isnum(training["roll"]) || teacher_rating < 1)
		return FALSE
	var/rating = quality_path_teaching_rating(training["roll"], teacher_rating)
	record["path"] = "[path_type]"
	record["path_rating"] = rating
	var/list/known = record["learned_paths"]
	known |= "[path_type]"
	record["training"] = list()
	if(!quality_write_path_fields(quality_character_account, quality_character_id, record))
		return FALSE
	quality_set_live_path(path_type, rating)
	to_chat(src, span_boldnotice("You emerge from the Beast's grip following [initial(path_type:name)] at [rating] dots."))
	log_game("Path initiation completed: [quality_character_account]/[quality_character_id] entered [path_type] at [rating] dots.")
	return TRUE
