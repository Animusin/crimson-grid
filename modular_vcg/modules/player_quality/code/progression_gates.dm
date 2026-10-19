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
	return list(
		"respect_age_cap" = preferences.respect_kindred_age_cap(),
		"respect_kindred_available" = respect_kindred_available(preferences.parent?.ckey),
		"respect_kindred_threshold" = CONFIG_GET(number/respect_fledgling_threshold),
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
