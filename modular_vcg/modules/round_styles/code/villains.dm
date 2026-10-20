/// Ratwood-style explicit villain signups. The manor's Tzimisce remain regular
/// jobs, but use the same antagonist capacity as the crusade and hunters.
/proc/city_villain_job(datum/job/job)
	return istype(job, /datum/job/vampire/sabbatductus) || istype(job, /datum/job/vampire/sabbatpriest) \
		|| istype(job, /datum/job/vampire/sabbatpack) || istype(job, /datum/job/vampire/abbe) \
		|| istype(job, /datum/job/vampire/condottieri) || istype(job, /datum/job/vampire/inquisitor) \
		|| istype(job, /datum/job/vampire/novice)

/atom/movable/screen/lobby/button/villains
	name = "Villains"
	desc = "Choose roundstart antagonist preferences or join an available crusade or hunter role."
	icon = 'icons/hud/lobby/signup_button.dmi'
	icon_state = "signup"
	base_icon_state = "signup"
	screen_loc = "TOP:-70,CENTER:100"
	maptext_x = 28
	maptext_y = 7
	maptext_width = 100
	maptext_height = 20

/atom/movable/screen/lobby/button/villains/Initialize(mapload, datum/hud/hud_owner)
	. = ..()
	maptext = MAPTEXT("<span style='color: #ff7777'>VILLAINS</span>")

/atom/movable/screen/lobby/button/villains/Click(location, control, params)
	. = ..()
	if(!.)
		return
	var/mob/dead/new_player/player = hud.mymob
	player.city_villain_choices()

/mob/dead/new_player/proc/city_villain_choices()
	if(!client || client.interviewee || spawning)
		return
	var/datum/browser/popup = new(src, "city_villains", "Villains", 560, 520)
	popup.set_content(city_villain_choices_html())
	popup.open(FALSE)

/mob/dead/new_player/proc/city_villain_choices_html()
	var/client/player_client = GET_CLIENT(src)
	var/pregame = SSticker.current_state < GAME_STATE_SETTING_UP
	var/list/contents = list("<h2>Villains</h2>")
	contents += "The Sabbat crusade and hunters are antagonist roles sharing one budget with the Tzimisce manor."
	contents += "<p>The crusade opposes the city's established factions. Coordinate with your pack and follow the server's antagonist escalation rules.</p>"
	var/entry_denial = GLOB.city_antag_budget.entry_denial(mind)
	if(entry_denial)
		contents += "<p><b>[html_encode(entry_denial)]</b></p>"
	if(GLOB.city_round_style.finalized)
		var/list/counts = GLOB.city_antag_budget.totals(GLOB.city_antag_budget.accounts())
		contents += "<b>[html_encode(GLOB.city_round_style.style_name())]</b><br>Antagonists: [counts["antagonists"]] / [GLOB.city_antag_budget.capacity(counts)]<br>"
	else
		contents += "<p>The round style is decided by the lobby vote. Quiet Night disables these roles.</p>"
	if(pregame)
		contents += "<p>Set preferences, then press Ready in the lobby. Slots are allocated at roundstart; preferences do not reserve a place.</p>"
	else if(!SSticker.IsRoundInProgress())
		contents += "<p>Joining is unavailable while the round is setting up or ending.</p>"
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(!city_villain_job(job) || !(pregame ? job.spawn_positions : job.total_positions))
			continue
		contents += "<hr><b>[html_encode(job.title)]</b><br>[html_encode(job.description)]<br>"
		if(pregame)
			var/datum/preferences/preferences = player_client.prefs
			var/list/profiles = preferences.create_character_profiles()
			var/profile_slot = LAZYACCESS(preferences.job_assigned_profiles, job.title)
			var/effective_slot = isnull(profile_slot) ? preferences.default_slot : profile_slot
			var/profile_name = isnum(effective_slot) && effective_slot >= 1 && effective_slot <= length(profiles) ? profiles[effective_slot] : null
			var/profile_label = isnull(profile_slot) ? "Active slot [effective_slot]" : "Slot [effective_slot]"
			contents += "Roundstart character: [html_encode(profile_label)]: [html_encode(profile_name || "Unavailable saved character")]. <a href='byond://?src=[REF(src)];city_villain_profile=[url_encode(job.title)]'>Choose / reset profile</a><br>"
			var/current = player_client?.prefs.job_preferences[job.title]
			var/list/priorities = list("Never" = null, "Low" = JP_LOW, "Medium" = JP_MEDIUM, "High" = JP_HIGH)
			for(var/label in priorities)
				var/priority = priorities[label]
				contents += current == priority ? " <b>[label]</b> " : " <a href='byond://?src=[REF(src)];city_villain_pref=[url_encode(job.title)];level=[isnull(priority) ? "off" : priority]'>[label]</a> "
		else if(SSticker.IsRoundInProgress())
			var/availability = IsJobUnavailable(job.title, latejoin = TRUE)
			var/limit = GLOB.city_antag_budget.job_limit(job, TRUE)
			contents += "[job.current_positions] / [limit] places. "
			if(entry_denial)
				contents += html_encode(entry_denial)
			else if(availability == JOB_AVAILABLE)
				contents += "<a href='byond://?src=[REF(src)];city_villain_join=[url_encode(job.title)]'>Join</a>"
			else
				contents += html_encode(get_job_unavailable_error_message(availability, job.title))
	return jointext(contents, "")

/// Only the dedicated panel changes villain preferences; the actual allocator
/// still uses native jobs, saved priorities, eligibility and atomic cap checks.
/mob/dead/new_player/proc/city_villain_preference(title, level)
	if(!client || client.interviewee || spawning || SSticker.current_state >= GAME_STATE_SETTING_UP)
		return FALSE
	var/datum/job/job = SSjob.get_job(title)
	if(!city_villain_job(job) || !job.spawn_positions)
		return FALSE
	var/priority = level == "off" ? null : text2num(level)
	if(level != "off" && priority != JP_LOW && priority != JP_MEDIUM && priority != JP_HIGH)
		return FALSE
	client.prefs.set_job_preference_level(job, priority)
	client.prefs.save_character()
	client.prefs.save_preferences()
	return TRUE

/// Keep the native per-job character selection visible after moving these jobs
/// out of the ordinary catalogue. Latejoin still uses its native active slot.
/mob/dead/new_player/proc/city_villain_profile(title)
	if(!client || client.interviewee || spawning || SSticker.current_state >= GAME_STATE_SETTING_UP)
		return FALSE
	var/datum/job/job = SSjob.get_job(title)
	if(!city_villain_job(job) || !job.spawn_positions)
		return FALSE
	var/client/choosing_client = client
	var/datum/preferences/preferences = client.prefs
	var/active_slot = preferences.default_slot
	var/list/profiles = preferences.create_character_profiles()
	var/reset_label = "Use active character (follow the selected slot)"
	var/list/choices = list(reset_label = null)
	var/current_choice = reset_label
	var/assigned_slot = LAZYACCESS(preferences.job_assigned_profiles, title)
	for(var/slot in 1 to length(profiles))
		if(isnull(profiles[slot]))
			continue
		var/label = "Slot [slot]: [profiles[slot]]"
		choices[label] = slot
		if(assigned_slot == slot)
			current_choice = label
	var/selection = tgui_input_list(src, "Choose the character used for [job.title] at roundstart.", "Villain character profile", choices, current_choice)
	if(isnull(selection) || QDELETED(src) || client != choosing_client || client?.prefs != preferences \
		|| client.interviewee || spawning || SSticker.current_state >= GAME_STATE_SETTING_UP || preferences.default_slot != active_slot || !(selection in choices))
		return FALSE
	return preferences.city_set_villain_profile(SSjob.get_job(title), choices[selection])

/// Data validation and native serialization shared with the panel callback.
/// The callback owns its client and pregame checks around the yielding dialog.
/datum/preferences/proc/city_set_villain_profile(datum/job/job, profile_slot)
	if(!city_villain_job(job) || !job.spawn_positions)
		return FALSE
	if(!isnull(profile_slot))
		if(!isnum(profile_slot) || profile_slot != round(profile_slot) || profile_slot < 1 || profile_slot > max_save_slots)
			return FALSE
		var/list/profiles = create_character_profiles()
		if(profile_slot > length(profiles) || isnull(profiles[profile_slot]))
			return FALSE
		LAZYSET(job_assigned_profiles, job.title, profile_slot)
	else
		LAZYREMOVE(job_assigned_profiles, job.title)
	save_character()
	save_preferences()
	return TRUE

/// Shared by all latejoin entry points, including stale browser links. No UI
/// callback may bypass population queue, administrative lock or character stats.
/mob/dead/new_player/proc/city_can_latejoin()
	if(!client || client.interviewee || spawning || !SSticker.IsRoundInProgress())
		return FALSE
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		to_chat(src, span_warning("Entering the game is administratively disabled."))
		return FALSE
	var/hard_cap = CONFIG_GET(number/hard_popcap)
	var/extreme_cap = CONFIG_GET(number/extreme_popcap)
	var/popcap = hard_cap && extreme_cap ? min(hard_cap, extreme_cap) : max(hard_cap, extreme_cap)
	if(!(ckey(key) in GLOB.admin_datums) && ((popcap && living_player_count() >= popcap) \
		|| (length(SSticker.queued_players) && SSticker.queued_players[1] != src)))
		SSticker.queued_players |= src
		to_chat(src, span_warning("The server is full or another player is ahead of you in the join queue."))
		return FALSE
	var/datum/st_stat/freebie/freebie_stat = client.prefs.preference_storyteller_stats[STAT_FREEBIE_POINTS]
	if(freebie_stat && freebie_stat.get_points() < 0)
		to_chat(src, span_warning("Fix your negative freebie points before joining."))
		return FALSE
	return TRUE
