GLOBAL_DATUM_INIT(city_round_style, /datum/city_round_style, new)

/// Selected before job assignment; only ownership crosses round boundaries.
/datum/city_round_style
	var/style_id = "eternal"
	var/finalized = FALSE
	var/bootstrapped = FALSE
	var/map_key
	var/datum/json_database/owners_database
	var/list/businesses = list()
	var/list/required_factions = list()
	var/list/represented_factions = list()
	/// Active deciseconds, keyed by canonical account rather than character/body.
	var/list/active_time = list()
	var/list/previous_active = list()
	var/last_sample
	var/saved = FALSE

/datum/city_round_style/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	UnregisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED)
	QDEL_NULL(owners_database)
	return ..()

/datum/city_round_style/proc/style_name()
	switch(style_id)
		if("quiet")
			return "Спокойная ночь"
		if("war")
			return "Война Принцев"
	return "Вечная Борьба"

/datum/city_round_style/proc/bootstrap()
	if(bootstrapped)
		return
	bootstrapped = TRUE
	map_key = "[SSmapping.current_map.map_path]/[json_encode(SSmapping.current_map.map_file)]"
	// Capture the map's original factions before loading a previous war's owners.
	for(var/obj/structure/city_business/business as anything in GLOB.city_businesses)
		if(!business.mapped_business || !business.territory_id)
			continue
		if(businesses[business.territory_id])
			stack_trace("Duplicate persistent business ID [business.territory_id]")
			continue
		businesses[business.territory_id] = business
		required_factions[business.owner_faction] = TRUE
	owners_database = new("data/city_territory_owners.json")
	if(islist(owners_database.get()))
		load_owners(owners_database.get_key(map_key))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED, PROC_REF(round_ended))
	last_sample = world.time
	START_PROCESSING(SSprocessing, src)

/datum/city_round_style/proc/valid_owner(owner)
	return owner in list(FACTION_CAMARILLA, FACTION_ANARCHS, FACTION_SABBAT, FACTION_GIOVANNI, "triads")

/datum/city_round_style/proc/load_owners(list/payload)
	if(!islist(payload) || payload["version"] != 1 || !islist(payload["owners"]))
		return
	var/list/owners = payload["owners"]
	for(var/id in businesses)
		var/obj/structure/city_business/business = businesses[id]
		if(QDELETED(business) || !valid_owner(owners[id]))
			continue
		business.owner_faction = owners[id]
		business.update_appearance()

/// Called in the lobby; an unrelated vote is allowed to finish first.
/datum/city_round_style/proc/ensure_vote()
	bootstrap()
#ifdef UNIT_TESTS
	return
#endif
	if(finalized || SSvote.current_vote)
		return
	SSvote.initiate_vote(/datum/vote/city_round_style, "the city", forced = TRUE)

/datum/city_round_style/proc/ready_for_setup()
#ifdef UNIT_TESTS
	// Headless test worlds have nobody to vote and must not wait out a lobby.
	finalize_style()
	return TRUE
#else
	ensure_vote()
	return finalized
#endif

/datum/city_round_style/proc/finalize_style(choice)
	if(finalized)
		return
	if(choice in list("quiet", "eternal", "war"))
		style_id = choice
	finalized = TRUE
	to_chat(world, span_boldannounce("Стиль раунда: [style_name()]."))
	if(style_id == "war")
		to_chat(world, span_notice("Владельцы территорий сохранятся только при 40 разных участниках с 40 активными минутами у каждого и участии всех фракций с начальными территориями."))

/datum/city_round_style/process(seconds_per_tick)
	var/current_time = world.time
	// Never count lobby, postgame, lag stalls, disconnected gaps or ghost time.
	var/elapsed = min(2 SECONDS, max(0, current_time - last_sample))
	last_sample = current_time
	if(!SSticker.IsRoundInProgress())
		previous_active.Cut()
		return
	var/list/current_active = list()
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/body = player.mob
		if(!istype(body) || body.stat == DEAD || !body.mind?.assigned_role || player.is_afk())
			continue
		var/account = ckey(player.ckey)
		if(!account || current_active[account])
			continue
		current_active[account] = body.city_faction() || "unaffiliated"
	sample_accounts(current_active, elapsed)

/// Both ends of an interval must be active; a returning account starts fresh.
/datum/city_round_style/proc/sample_accounts(list/current_active, elapsed)
	for(var/account in current_active)
		if(previous_active[account])
			record_activity(account, elapsed, current_active[account])
	previous_active = current_active

/datum/city_round_style/proc/record_activity(account, elapsed, faction)
	account = ckey(account)
	if(!account || !isnum(elapsed) || elapsed <= 0)
		return
	active_time[account] = (active_time[account] || 0) + elapsed
	if(required_factions[faction])
		represented_factions[faction] = TRUE

/datum/city_round_style/proc/qualified_accounts()
	var/count = 0
	for(var/account in active_time)
		if(active_time[account] >= 40 MINUTES)
			count++
	return count

/datum/city_round_style/proc/can_save_owners()
	if(!finalized || style_id != "war" || qualified_accounts() < 40)
		return FALSE
	for(var/faction in required_factions)
		if(!represented_factions[faction])
			return FALSE
	return length(businesses) > 0

/datum/city_round_style/proc/owner_payload()
	var/list/owners = list()
	for(var/id in businesses)
		var/obj/structure/city_business/business = businesses[id]
		if(!QDELETED(business) && valid_owner(business.owner_faction))
			owners[id] = business.owner_faction
	return list("version" = 1, "owners" = owners)

/datum/city_round_style/proc/save_owners()
	if(saved || !can_save_owners())
		return FALSE
	commit_owners(owner_payload())
	saved = TRUE
	return TRUE

/datum/city_round_style/proc/commit_owners(list/payload)
	if(!islist(owners_database.get()))
		owners_database.replace(list())
	owners_database.set_key(map_key, payload)

/datum/city_round_style/proc/round_ended()
	SIGNAL_HANDLER
	var/did_save = save_owners()
	if(style_id == "war")
		to_chat(world, span_notice("Территории [did_save ? "сохранены" : "не сохранены"]. Участников с 40 активными минутами: [qualified_accounts()]/40. [did_save ? "" : "Нужны также представители всех фракций с начальными территориями."]"))

/obj/structure/city_business/proc/capture_allowed()
	return GLOB.city_round_style.style_id != "quiet"
