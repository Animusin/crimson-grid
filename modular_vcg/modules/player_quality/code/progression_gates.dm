/datum/config_entry/number/respect_antagonist_threshold
	default = 10
	min_val = 0

/// Optional contract with the city antagonist admission policy. Its caller owns
/// the canonical account and whether it continues an accepted living antagonist.
/// A string signal avoids a compile dependency on that separate module.
/datum/controller/subsystem/player_quality/proc/on_antagonist_admission(datum/source, datum/mind/candidate, continuing, list/denial)
	SIGNAL_HANDLER
	if(!store || !CONFIG_GET(flag/player_quality_enabled) || continuing || !islist(denial) || denial["message"])
		return
	// The trusted caller uses the current client when mind.key is stale. This
	// list is constructed by the policy, never supplied by preference/UI params.
	var/account = ckey(denial["account"] || candidate?.key)
	if(!account)
		return
	var/score = store.respect(account)
	var/threshold = CONFIG_GET(number/respect_antagonist_threshold)
	if(score < threshold)
		denial["message"] = "Antagonist roles require [threshold] Respect; your account has [num2text(score, 10)], below that threshold."

/datum/config_entry/flag/respect_age_gates
	default = TRUE

/datum/config_entry/number/respect_fledgling_threshold
	default = 10
	min_val = 0

/datum/config_entry/number/respect_neonate_threshold
	default = 20
	min_val = 0

/datum/config_entry/number/respect_ancilla_threshold
	default = 40
	min_val = 0

/datum/config_entry/number/respect_elder_threshold
	default = 60
	min_val = 0

/datum/config_entry/flag/respect_garou_rank_gates
	default = TRUE

/datum/config_entry/number/respect_garou_cub_threshold
	default = 10
	min_val = 0

/datum/config_entry/number/respect_garou_cliath_threshold
	default = 20
	min_val = 0

/datum/config_entry/number/respect_garou_fostern_threshold
	default = 30
	min_val = 0

/datum/config_entry/number/respect_garou_adren_threshold
	default = 40
	min_val = 0

/datum/config_entry/number/respect_garou_athro_threshold
	default = 50
	min_val = 0

/datum/config_entry/number/respect_garou_elder_threshold
	default = 60
	min_val = 0

/// Garou already derive rank from their Auspice and three Renown values.
/// Corax have no implemented rank ladder and do not use this account gate.
/proc/respect_garou_rank_cap_for_score(score)
	if(score < CONFIG_GET(number/respect_garou_cub_threshold))
		return -1
	if(score >= CONFIG_GET(number/respect_garou_elder_threshold))
		return RANK_ELDER
	if(score >= CONFIG_GET(number/respect_garou_athro_threshold))
		return RANK_ATHRO
	if(score >= CONFIG_GET(number/respect_garou_adren_threshold))
		return RANK_ADREN
	if(score >= CONFIG_GET(number/respect_garou_fostern_threshold))
		return RANK_FOSTERN
	if(score >= CONFIG_GET(number/respect_garou_cliath_threshold))
		return RANK_CLIATH
	return RANK_CUB

/proc/respect_garou_rank_cap(account)
	if(!SSplayer_quality?.store || !CONFIG_GET(flag/respect_garou_rank_gates))
		return RANK_LEGEND
	return respect_garou_rank_cap_for_score(SSplayer_quality.store.respect(account))

/proc/respect_garou_available(account)
	return respect_garou_rank_cap(account) >= RANK_CUB

/// Inspect the full saved sheet without modifying it. An Auspice change can
/// alter rank even if all three Renown sliders stay unchanged.
/datum/preferences/proc/quality_garou_rank(renown_key = null, renown_value = null, auspice_value = null)
	var/datum/subsplat/werewolf/auspice/auspice = get_fera_auspice(auspice_value || read_preference(/datum/preference/choiced/subsplat/fera_auspice/garou))
	var/list/renown = list(
		RENOWN_HONOR = read_preference(/datum/preference/numeric/renown/honor),
		RENOWN_GLORY = read_preference(/datum/preference/numeric/renown/glory),
		RENOWN_WISDOM = read_preference(/datum/preference/numeric/renown/wisdom),
	)
	if(renown_key in ALL_RENOWNS)
		renown[renown_key] = renown_value
	return auspice ? auspice.rank_requirments(renown) : RANK_CUB

/// Only preference application caps a starting rank. Normal in-round Renown
/// gains/losses continue through adjust_renown without an account-score clamp.
/mob/living/carbon/human/proc/quality_apply_garou_starting_rank(datum/preferences/preferences)
	var/datum/splat/werewolf/shifter/garou/garou = get_splat(/datum/splat/werewolf/shifter/garou)
	if(!garou)
		return FALSE
	garou.renown_rank = garou.auspice_rank_check()
	if(preferences)
		garou.renown_rank = min(garou.renown_rank, max(RANK_CUB, respect_garou_rank_cap(preferences.parent?.ckey)))
	return TRUE

/// Reuse existing age bands. A negative cap explicitly means no playable Kindred.
/proc/respect_age_cap(account)
	if(!SSplayer_quality?.store || !CONFIG_GET(flag/respect_age_gates))
		return 1000
	return respect_age_cap_for_score(SSplayer_quality.store.respect(account))

/proc/respect_age_cap_for_score(score)
	if(score < CONFIG_GET(number/respect_fledgling_threshold))
		return -1
	if(score >= CONFIG_GET(number/respect_elder_threshold))
		return 1000
	if(score >= CONFIG_GET(number/respect_ancilla_threshold))
		return 200
	if(score >= CONFIG_GET(number/respect_neonate_threshold))
		return 100
	return 10

/proc/respect_kindred_available(account)
	return respect_age_cap(account) >= 0

/datum/preferences/proc/respect_kindred_age_cap()
	if(!ispath(read_preference(/datum/preference/choiced/splats), /datum/splat/vampire/kindred))
		return 1000
	return respect_age_cap(parent?.ckey)

/// Discipline allocation must use the same effective age as spawn application,
/// including an older saved sheet which the UI has not yet been edited to fix.
/datum/preferences/proc/respect_immortal_age()
	return max(0, min(read_preference(/datum/preference/numeric/immortal_age), respect_kindred_age_cap()))

/datum/preference_middleware/player_respect/get_ui_data(mob/user)
	var/is_garou = ispath(preferences.read_preference(/datum/preference/choiced/splats), /datum/splat/werewolf/shifter/garou)
	var/rank_cap = is_garou ? respect_garou_rank_cap(preferences.parent?.ckey) : null
	var/saved_rank = is_garou ? preferences.quality_garou_rank() : null
	return list(
		"respect_age_cap" = preferences.respect_kindred_age_cap(),
		"respect_kindred_available" = respect_kindred_available(preferences.parent?.ckey),
		"respect_kindred_threshold" = CONFIG_GET(number/respect_fledgling_threshold),
		"respect_garou_rank_cap" = rank_cap,
		"respect_garou_rank_name" = is_garou && rank_cap >= 0 ? fera_rank_name(rank_cap, SPLAT_GAROU) : null,
		"respect_garou_saved_rank" = saved_rank,
		"respect_garou_saved_rank_name" = is_garou ? fera_rank_name(saved_rank, SPLAT_GAROU) : null,
		"respect_garou_threshold" = CONFIG_GET(number/respect_garou_cub_threshold),
		"player_respect" = SSplayer_quality?.store ? round(SSplayer_quality.store.respect(preferences.parent?.ckey), 0.01) : null,
	)

/// UI checks give feedback without silently replacing a saved character's age.
/// Job assignment and spawn application independently enforce the same account cap.
/datum/preference_middleware/player_respect/pre_set_preference(mob/user, preference, value)
	if(preference == "splats")
		var/splat_type = ispath(value) ? value : GLOB.splat_list[value]
		if(ispath(splat_type, /datum/splat/vampire/kindred) && !respect_kindred_available(preferences.parent?.ckey))
			to_chat(user, span_warning("Kindred require [CONFIG_GET(number/respect_fledgling_threshold)] Respect. Mortals and ghouls remain available."))
			return TRUE
		if(ispath(splat_type, /datum/splat/werewolf/shifter/garou) && !respect_garou_available(preferences.parent?.ckey))
			to_chat(user, span_warning("Garou require [CONFIG_GET(number/respect_garou_cub_threshold)] Respect. Mortals, ghouls and kinfolk remain available."))
			return TRUE
		return FALSE
	if((preference in ALL_RENOWNS) || preference == "garou_auspice")
		if(!ispath(preferences.read_preference(/datum/preference/choiced/splats), /datum/splat/werewolf/shifter/garou))
			return FALSE
		var/garou_cap = respect_garou_rank_cap(preferences.parent?.ckey)
		var/proposed_rank
		if(preference == "garou_auspice")
			proposed_rank = preferences.quality_garou_rank(auspice_value = value)
		else
			var/renown_value = isnum(value) ? value : text2num(value)
			if(!isnum(renown_value))
				return FALSE
			proposed_rank = preferences.quality_garou_rank(preference, renown_value)
			var/datum/preference/numeric/renown/renown_preference = GLOB.preference_entries_by_key[preference]
			// Three sliders may need several reductions to repair an old sheet.
			if(renown_value < preferences.read_preference(renown_preference.type))
				return FALSE
		if(proposed_rank > garou_cap)
			var/allowed = garou_cap < 0 ? "Garou require [CONFIG_GET(number/respect_garou_cub_threshold)] Respect" : "Respect currently permits Garou rank [fera_rank_name(garou_cap, SPLAT_GAROU)]"
			to_chat(user, span_warning("[allowed]. Reduce the saved Renown before joining; changing Auspice cannot bypass the rank limit."))
			return TRUE
		return FALSE
	if(preference != "immortal_age")
		return FALSE
	var/age = isnum(value) ? value : text2num(value)
	var/cap = preferences.respect_kindred_age_cap()
	if(isnum(age) && age > cap)
		if(cap < 0)
			to_chat(user, span_warning("Kindred require [CONFIG_GET(number/respect_fledgling_threshold)] Respect. Choose a mortal or ghoul until then."))
		else
			to_chat(user, span_warning("Your Respect currently permits a Kindred age of up to [cap] years since Embrace. Choose a younger age or another splat."))
		return TRUE
	return FALSE
