/// Character identity is independent of the editable name and character slot.
/datum/preferences
	var/quality_character_id

/mob/living/carbon/human
	var/quality_character_id
	var/quality_character_account
	var/datum/job/quality_pending_job
	var/quality_character_finalized = FALSE

/datum/player_quality_store/proc/read_character(account, character_id)
	if(!ckey(account) || !istext(character_id) || !length(character_id) || length(character_id) > 64)
		return null
	var/list/account_record = read(account)
	var/list/characters = account_record["characters"]
	var/list/character = islist(characters) ? characters[character_id] : null
	return islist(character) ? deep_copy_list(character) : null

/// Only first real spawn and explicit fixtures create records. Reads never do.
/datum/player_quality_store/proc/create_character_record(account, character_id, list/fields)
	account = ckey(account)
	if(!account || !istext(character_id) || !length(character_id) || length(character_id) > 64 || !islist(fields))
		return FALSE
	var/list/account_record = read(account)
	var/list/characters = account_record["characters"]
	if(!islist(characters))
		characters = list()
		account_record["characters"] = characters
	if(characters[character_id])
		return FALSE
	characters[character_id] = deep_copy_list(fields)
	database.set_key(account, account_record)
	return TRUE

/// Patch only supplied fields into the latest record. Callers must not submit a
/// stale full snapshot containing fields owned by other progression features.
/datum/player_quality_store/proc/write_character(account, character_id, list/fields)
	account = ckey(account)
	if(!account || !istext(character_id) || !islist(fields))
		return FALSE
	var/list/account_record = read(account)
	var/list/characters = account_record["characters"]
	var/list/character = islist(characters) ? characters[character_id] : null
	if(!islist(character))
		return FALSE
	for(var/field in fields)
		var/value = fields[field]
		character[field] = islist(value) ? deep_copy_list(value) : value
	database.set_key(account, account_record)
	return TRUE

/// Retiring a sheet discards character learning without changing account scores.
/datum/player_quality_store/proc/delete_character_record(account, character_id)
	account = ckey(account)
	if(!account || !istext(character_id))
		return FALSE
	var/list/account_record = read(account)
	var/list/characters = account_record["characters"]
	if(!islist(characters) || !islist(characters[character_id]))
		return FALSE
	characters -= character_id
	database.set_key(account, account_record)
	return TRUE

/// Payment and one-spawn edit permission share a single synchronous record write.
/datum/player_quality_store/proc/unlock_character(account, character_id, scope)
	account = ckey(account)
	if(!account || !istext(character_id) || !length(character_id) || !(scope in list("stats", "full")))
		return FALSE
	var/list/account_record = read(account)
	var/list/characters = account_record["characters"]
	var/list/character = islist(characters) ? characters[character_id] : null
	if(!islist(character) || !character["locked"])
		return FALSE
	var/ticket = character["unlock_ticket"]
	if(ticket == "full" || (ticket && !(ticket == "stats" && scope == "full")))
		return FALSE
	var/cost = scope == "stats" ? 3 : 5
	if(ticket == "stats" && scope == "full")
		cost = 2
	if(account_record["karma"] < cost)
		return FALSE
	account_record["karma"] = round(account_record["karma"] - cost, 0.01)
	character["unlock_ticket"] = scope
	database.set_key(account, account_record)
	log_game("Character respec: [account]/[character_id], [scope], -[cost] Karma.")
	return TRUE

/datum/preferences/proc/quality_character_record()
	return SSplayer_quality?.store?.read_character(parent?.ckey, quality_character_id)

/datum/preferences/proc/quality_load_identity(list/save_data)
	quality_character_id = save_data?["quality_character_id"]
	if(!istext(quality_character_id) || !length(quality_character_id) || length(quality_character_id) > 64)
		quality_character_id = GUID()
	if(islist(save_data))
		save_data["quality_character_id"] = quality_character_id

/datum/preferences/proc/quality_can_edit(scope = "full")
	if(!SSplayer_quality?.store)
		return TRUE
	var/list/record = quality_character_record()
	if(!record || !record["locked"])
		return TRUE
	return record["unlock_ticket"] == "full" || (scope == "stats" && record["unlock_ticket"] == "stats")

/datum/preferences/proc/quality_require_edit(scope = "full")
	if(quality_can_edit(scope))
		return TRUE
	to_chat(parent, span_warning("This character is saved. Unlock [scope == "stats" ? "stats and abilities for 3" : "identity settings for 5"] Karma before editing; cosmetics remain free."))
	return FALSE

/// Explicit mechanical exceptions precede appearance categories: Path, clan and
/// generation also appear under secondary features in the existing interface.
/proc/quality_preference_scope(datum/preference/preference)
	if(ispath(preference))
		preference = GLOB.preference_entries[preference]
	if(!preference || preference.savefile_identifier != PREFERENCE_CHARACTER)
		return null
	if(preference.savefile_key in list("morality_path", "generation", "diablerist", "wyrm_taint", "splats", "species"))
		return "full"
	if(istype(preference, /datum/preference/choiced/subsplat))
		return "full"
	if(findtext(preference.savefile_key, "archetype") || preference.savefile_key in list("nature", "demeanor"))
		return "stats"
	if(istype(preference, /datum/preference/color))
		return null
	for(var/quirk_type in GLOB.all_quirk_constant_data)
		var/datum/quirk_constant_data/quirk_data = GLOB.all_quirk_constant_data[quirk_type]
		if(preference.type in quirk_data.customization_options)
			return "stats"
	if(preference.category in list(PREFERENCE_CATEGORY_FEATURES, PREFERENCE_CATEGORY_SECONDARY_FEATURES, PREFERENCE_CATEGORY_SUPPLEMENTAL_FEATURES, PREFERENCE_CATEGORY_CLOTHING))
		return null
	if(findtext(preference.savefile_key, "flavor_text") || findtext(preference.savefile_key, "tts_") == 1 || preference.savefile_key in list("gender", "voice", "headshot", "headshot_link", "character_notes", "ooc_notes"))
		return null
	return "full"

/datum/preferences/proc/quality_can_edit_preference(datum/preference/preference)
	var/scope = quality_preference_scope(preference)
	return !scope || quality_can_edit(scope)

/// Called only after successful player possession, with the staged actual job.
/// Failed construction and preference previews never consume an edit ticket.
/mob/living/carbon/human/proc/quality_finalize_character(client/player, datum/job/job)
	if(quality_character_finalized)
		return TRUE
	var/client/possessing_player = GET_CLIENT(src)
	if(!job || !player?.prefs || !SSplayer_quality?.store || possessing_player?.ckey != player.ckey || player.mob != src)
		return FALSE
	var/datum/preferences/preferences = player.prefs
	if(!preferences.quality_character_id)
		preferences.quality_character_id = GUID()
	// Legacy sheets receive their GUID during load, which mutates a JSON subtree
	// without triggering auto-save. Persist it before writing the account lock.
	if(!preferences.save_character())
		return FALSE
	preferences.savefile.save()
	quality_character_id = preferences.quality_character_id
	quality_character_account = player.ckey
	var/list/record = SSplayer_quality.store.read_character(quality_character_account, quality_character_id)
	if(!record)
		SSplayer_quality.store.create_character_record(quality_character_account, quality_character_id, list(
			"locked" = TRUE,
			"unlock_ticket" = null,
			"learned_paths" = list(),
			"learned_disciplines" = list(),
		))
	else
		SSplayer_quality.store.write_character(quality_character_account, quality_character_id, list("locked" = TRUE, "unlock_ticket" = null))
	// The Path feature owns its own fields and may persist updates here. Never
	// overwrite them afterward using the snapshot taken before this callback.
	record = SSplayer_quality.store.read_character(quality_character_account, quality_character_id)
	quality_apply_character_path(player, job, record)
	preferences.quality_restore_discipline_choices()
	quality_character_finalized = TRUE
	quality_pending_job = null
	return TRUE

/// Account progression follows the existing canon/original-body save policy and
/// must also belong to this exact selected sheet, not another joined slot.
/mob/living/carbon/human/proc/quality_character_save_failure()
	var/failure = cant_save_midround_reason()
	if(failure)
		return failure
	var/client/player = GET_CLIENT(src)
	if(mind.original_character_slot_index != player.prefs.default_slot)
		return "selected character sheet is not this body's original slot"
	if(!quality_character_id || quality_character_account != player.ckey || player.prefs.quality_character_id != quality_character_id)
		return "selected character sheet does not own this body's persistent identity"
	return null

/// Teaching preserves the identity at level zero, not a second pool of dots.
/// Existing positive allocations continue to use the ordinary age/clan budget.
/mob/living/carbon/human/proc/quality_learn_discipline_identity(power_type)
	if(quality_character_save_failure() || !ispath(power_type, /datum/discipline))
		return FALSE
	var/list/record = SSplayer_quality?.store?.read_character(quality_character_account, quality_character_id)
	if(!record)
		return FALSE
	var/list/learned = record["learned_disciplines"]
	learned = islist(learned) ? learned : list()
	if("[power_type]" in learned)
		return FALSE
	learned["[power_type]"] = 0
	return SSplayer_quality.store.write_character(quality_character_account, quality_character_id, list("learned_disciplines" = learned))

/datum/preferences/proc/quality_restore_discipline_choices()
	var/list/record = quality_character_record()
	var/list/learned = record?["learned_disciplines"]
	if(!islist(learned))
		return
	for(var/power_key in learned)
		if(ispath(text2path(power_key), /datum/discipline) && !(power_key in discipline_levels))
			discipline_levels[power_key] = 0

/datum/preference_middleware/character_progression
	action_delegations = list("quality_unlock_character" = PROC_REF(unlock_character))

/datum/preference_middleware/character_progression/get_ui_data(mob/user)
	if(!SSplayer_quality?.store)
		return list()
	var/list/record = preferences.quality_character_record()
	var/list/account = SSplayer_quality?.store?.read(preferences.parent?.ckey)
	var/score = account ? calculate_respect(account["pq"], account["rcp"], account["karma"]) : 0
	var/full_cost = record?["unlock_ticket"] == "stats" ? 2 : 5
	return list("character_progression" = list(
		"locked" = record?["locked"] || FALSE,
		"can_unlock" = isnewplayer(user),
		"unlock_ticket" = record?["unlock_ticket"],
		"karma" = account?["karma"] || 0,
		"full_cost" = full_cost,
		"stats_respect" = round(score - 3, 0.01),
		"full_respect" = round(score - full_cost, 0.01),
		"stats_age_cap" = CONFIG_GET(flag/respect_age_gates) ? respect_age_cap_for_score(score - 3) : 1000,
		"full_age_cap" = CONFIG_GET(flag/respect_age_gates) ? respect_age_cap_for_score(score - full_cost) : 1000,
		"stats_garou_rank_cap" = CONFIG_GET(flag/respect_garou_rank_gates) ? respect_garou_rank_cap_for_score(score - 3) : RANK_LEGEND,
		"full_garou_rank_cap" = CONFIG_GET(flag/respect_garou_rank_gates) ? respect_garou_rank_cap_for_score(score - full_cost) : RANK_LEGEND,
	))

/datum/preference_middleware/character_progression/proc/unlock_character(list/params, mob/user)
	// A purchase only edits a future round's sheet, never the current live body.
	var/client/player = GET_CLIENT(user)
	if(!isnewplayer(user) || player?.ckey != preferences.parent?.ckey)
		return FALSE
	return SSplayer_quality?.store?.unlock_character(preferences.parent.ckey, preferences.quality_character_id, params["scope"])
