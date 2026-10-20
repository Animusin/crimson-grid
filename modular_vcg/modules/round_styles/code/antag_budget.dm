GLOBAL_DATUM_INIT(city_antag_budget, /datum/city_antag_budget, new)

/// Shared player capacity. Jobs and antagonist datums describe the same account,
/// so a Sabbat outfit, promotion or second datum never buys a second slot.
/datum/city_antag_budget
	var/assignment_active = FALSE
	var/assignment_pure = FALSE
	var/defer_jobs = FALSE
	var/roundstart_reservations = FALSE
	var/ignore_pure_lobby = FALSE
	var/list/deferred_players = list()

/datum/city_antag_budget/proc/enabled()
	return GLOB.city_round_style?.finalized

/datum/city_antag_budget/proc/divisor()
	switch(GLOB.city_round_style?.style_id)
		if("quiet")
			return 0
		if("war")
			return 7
	return 15

/datum/city_antag_budget/proc/managed_job(datum/job/job)
	return job && (job.faction == FACTION_SABBAT || istype(job, /datum/job/vampire/abbe) \
		|| istype(job, /datum/job/vampire/condottieri) || istype(job, /datum/job/vampire/inquisitor) \
		|| istype(job, /datum/job/vampire/novice))

/// Keep native ceilings for leaders/specialists and map-disabled jobs. Ordinary
/// members instead scale to the shared capacity, rather than a fixed pack of 3.
/datum/city_antag_budget/proc/scalable_job(datum/job/job)
	return istype(job, /datum/job/vampire/sabbatpack) || istype(job, /datum/job/vampire/bogatyr) \
		|| istype(job, /datum/job/vampire/zadruga) || istype(job, /datum/job/vampire/inquisitor) \
		|| istype(job, /datum/job/vampire/novice)

/datum/city_antag_budget/proc/fighter_job(datum/job/job)
	return istype(job, /datum/job/vampire/sheriff) || istype(job, /datum/job/vampire/hound) \
		|| istype(job, /datum/job/vampire/bruiser)

/datum/city_antag_budget/proc/real_antagonist(datum/antagonist/antagonist)
	return antagonist && !(antagonist.antag_flags & ANTAG_FAKE)

/datum/city_antag_budget/proc/antagonist_mind(datum/mind/mind)
	for(var/datum/antagonist/antagonist as anything in mind?.antag_datums)
		if(real_antagonist(antagonist))
			return TRUE
	return FALSE

/datum/city_antag_budget/proc/account(mob/body, datum/mind/mind)
	var/client/player_client
	if(body)
		player_client = GET_CLIENT(body)
	return ckey(player_client?.ckey || mind?.key)

/datum/city_antag_budget/proc/add_account(list/accounts, identifier, datum/mind/mind, datum/job/job, forced_antag = FALSE)
	if(!identifier || !mind)
		return
	var/is_antag = forced_antag || managed_job(job) || antagonist_mind(mind)
	var/list/previous = accounts[identifier]
	// An account controlling multiple bodies is still one participant. Its
	// antagonist identity wins over any ordinary body, never adding population.
	if(previous && previous["antag"])
		return
	if(previous && previous["fighter"] && !is_antag && !fighter_job(job))
		return
	accounts[identifier] = list("antag" = is_antag, "fighter" = !is_antag && fighter_job(job), "job" = job)

/// Ready/assigned lobby minds reserve capacity during job allocation and real
/// character creation. Pure Dynamic trials must not leave such reservations.
/datum/city_antag_budget/proc/accounts()
	var/list/result = list()
	for(var/mob/living/body as anything in GLOB.player_list)
		if(!isliving(body) || QDELETED(body) || body.stat == DEAD || !GET_CLIENT(body) || !body.mind)
			continue
		add_account(result, account(body, body.mind), body.mind, body.mind.assigned_role)
	if(ignore_pure_lobby && !assignment_active)
		return result
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(QDELETED(player) || !GET_CLIENT(player))
			continue
		var/datum/mind/mind = player.mind || player.new_character?.mind
		var/datum/job/job = mind?.assigned_role
		if(!job || is_unassigned_job(job))
			continue
		if(!assignment_active && !(roundstart_reservations && !SSticker.HasRoundStarted()) && !managed_job(job))
			continue
		add_account(result, account(player, mind), mind, job)
	return result

/datum/city_antag_budget/proc/totals(list/accounts)
	var/weighted_nonantags = 0
	var/antagonists = 0
	for(var/identifier in accounts)
		var/list/entry = accounts[identifier]
		if(entry["antag"])
			antagonists++
		else
			weighted_nonantags += 1 + !!entry["fighter"]
	return list("population" = weighted_nonantags, "antagonists" = antagonists)

/datum/city_antag_budget/proc/capacity(list/counts)
	var/denominator = divisor()
	return denominator ? FLOOR(counts["population"] / denominator, 1) : 0

/datum/city_antag_budget/proc/remaining()
	var/list/counts = totals(accounts())
	return max(capacity(counts) - counts["antagonists"], 0)

/// The candidate is replaced in the prospective snapshot, not added to both
/// sides. In particular a conversion removes its old ordinary/fighter weight.
/datum/city_antag_budget/proc/can_admit(datum/mind/mind, datum/job/job, forced_antag = FALSE)
	if(!enabled())
		return TRUE
	if(!divisor())
		return FALSE
	var/mob/body = mind?.current
	var/identifier = account(body, mind)
	if(!identifier)
		return TRUE // Unowned NPCs are not player capacity.
	var/list/population = accounts()
	population -= identifier
	add_account(population, identifier, mind, job, forced_antag)
	var/list/counts = totals(population)
	if(counts["antagonists"] > capacity(counts))
		// Do not break an existing member's outfit or promotion when a departure
		// lowers the live cap. Only a newly admitted account needs a free slot.
		var/list/current_accounts = accounts()
		var/list/current_entry = current_accounts[identifier]
		if(!current_entry || !current_entry["antag"])
			return FALSE
	if(managed_job(job))
		var/ceiling = SSticker.HasRoundStarted() ? job.total_positions : job.spawn_positions
		if(ceiling == 0)
			return FALSE
		if(!scalable_job(job) && ceiling > 0)
			var/role_count = 0
			for(var/key in population)
				var/list/entry = population[key]
				if(entry["job"] == job)
					role_count++
			if(role_count > ceiling)
				return FALSE
	return TRUE

/datum/city_antag_budget/proc/can_set_role(datum/mind/mind, datum/job/job)
	if(!enabled() || !managed_job(job))
		return TRUE
	if(defer_jobs)
		return FALSE
	return can_admit(mind, job)

/datum/city_antag_budget/proc/can_gain_antagonist(datum/mind/mind, datum/antagonist/antagonist)
	return !real_antagonist(antagonist) || can_admit(mind, mind?.assigned_role, TRUE)

/// Shared-cap rows are never offered as infinite jobs. Native zeroes remain a
/// map/config prohibition; existing head limits and ordinary job limits survive.
/datum/city_antag_budget/proc/job_limit(datum/job/job, latejoin = FALSE, ignore_capacity = FALSE)
	var/native_limit = latejoin ? job.total_positions : job.spawn_positions
	if(!enabled() || !managed_job(job) || native_limit == 0)
		return native_limit
	if(!divisor())
		return 0
	if(ignore_capacity)
		return scalable_job(job) ? INFINITY : native_limit
	var/limit = job.current_positions + remaining()
	return scalable_job(job) || native_limit < 0 ? limit : min(native_limit, limit)

/datum/city_antag_budget/proc/begin_assignment(pure)
	assignment_active = TRUE
	assignment_pure = pure
	defer_jobs = enabled()
	roundstart_reservations = FALSE
	ignore_pure_lobby = FALSE
	deferred_players = list()

/datum/city_antag_budget/proc/end_assignment()
	roundstart_reservations = !assignment_pure
	ignore_pure_lobby = assignment_pure
	assignment_active = FALSE
	defer_jobs = FALSE
	deferred_players = list()

/datum/city_antag_budget/proc/reset_assignment()
	assignment_active = FALSE
	assignment_pure = FALSE
	defer_jobs = FALSE
	roundstart_reservations = FALSE
	ignore_pure_lobby = FALSE
	deferred_players = list()

/// Prefer a requested antagonist job over lower-priority ordinary fallback.
/// Eligibility is checked without capacity only while building this waiting
/// list; final assignments always recheck the atomic role gate.
/datum/city_antag_budget/proc/defer_player(mob/dead/new_player/player, priority)
	if(!enabled() || !defer_jobs || !divisor())
		return FALSE
	if(player in deferred_players)
		return TRUE
	var/client/player_client = GET_CLIENT(player)
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(!managed_job(job) || player_client?.prefs?.job_preferences[job.title] != priority)
			continue
		var/limit = job_limit(job, ignore_capacity = TRUE)
		if(limit >= 0 && job.current_positions >= limit)
			continue
		if(SSjob.check_job_eligibility(player, job, "CITY DEFER", ignore_city_budget = TRUE) != JOB_AVAILABLE)
			continue
		deferred_players |= player
		return TRUE
	return FALSE

/datum/city_antag_budget/proc/defer_overflow(mob/dead/new_player/player, datum/job/overflow)
	var/client/player_client = GET_CLIENT(player)
	var/overflow_priority = player_client?.prefs?.job_preferences[overflow.title]
	for(var/priority in SSjob.level_order)
		if(defer_player(player, priority))
			return TRUE
		if(priority == overflow_priority)
			break
	return FALSE

/datum/city_antag_budget/proc/preferred_jobs(mob/dead/new_player/player, priority, antagonist_jobs)
	var/list/result = list()
	var/client/player_client = GET_CLIENT(player)
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(managed_job(job) != antagonist_jobs || player_client?.prefs?.job_preferences[job.title] != priority)
			continue
		var/limit = job_limit(job)
		if(limit >= 0 && job.current_positions >= limit)
			continue
		if(SSjob.check_job_eligibility(player, job, "CITY FINAL") == JOB_AVAILABLE)
			result += job
	return result

/// Finish ordinary assignments before measuring the real non-antagonist
/// population. If capacity is full, admit one requested ordinary fallback, then
/// retry antagonist preferences: that fallback may increase the shared cap.
/datum/city_antag_budget/proc/finish_deferred_assignments(allow_all)
	defer_jobs = FALSE
	if(!enabled() || !divisor())
		return
	while(TRUE)
		for(var/priority in SSjob.level_order)
			for(var/mob/dead/new_player/player as anything in deferred_players.Copy())
				if(!(player in SSjob.unassigned) || (!allow_all && SSjob.popcap_reached()))
					continue
				var/list/jobs = preferred_jobs(player, priority, TRUE)
				if(length(jobs) && SSjob.assign_role(player, pick(jobs), do_eligibility_checks = FALSE))
					deferred_players -= player
		var/assigned_fallback = FALSE
		for(var/priority in SSjob.level_order)
			for(var/mob/dead/new_player/player as anything in deferred_players.Copy())
				if(!(player in SSjob.unassigned) || (!allow_all && SSjob.popcap_reached()))
					continue
				var/list/jobs = preferred_jobs(player, priority, FALSE)
				if(length(jobs) && SSjob.assign_role(player, pick(jobs), do_eligibility_checks = FALSE))
					deferred_players -= player
					assigned_fallback = TRUE
					break
			if(assigned_fallback)
				break
		if(!assigned_fallback)
			break
