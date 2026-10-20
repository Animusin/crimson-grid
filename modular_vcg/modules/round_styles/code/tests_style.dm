#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/city_round_style/unit_test
	var/list/committed
	var/commits = 0

/datum/city_round_style/unit_test/commit_owners(list/payload)
	commits++
	committed = payload

/datum/unit_test/city_round_style
	abstract_type = /datum/unit_test/city_round_style
#ifdef ROUND_STYLE_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/city_round_style/vote/Run()
	var/datum/city_round_style/old_state = GLOB.city_round_style
	var/datum/city_round_style/unit_test/state = allocate(/datum/city_round_style/unit_test)
	GLOB.city_round_style = state
	var/datum/vote/city_round_style/vote = allocate(/datum/vote/city_round_style)
	vote.create_vote()
	if(length(vote.get_vote_result(list())))
		Fail("Zero actual votes must have no winner, even though all three choices tie at zero.")
	if(vote.tiebreaker(list("Война Принцев", "Вечная Борьба")) != "Вечная Борьба")
		Fail("A tie containing the default must prefer Eternal Struggle.")
	vote.finalize_vote(null)
	if(state.style_id != "eternal" || !state.finalized)
		Fail("No votes must finalize Eternal Struggle before job selection.")
	state.finalize_style("war")
	if(state.style_id != "eternal")
		Fail("A finalized round style must not change mid-round.")
	state.finalized = FALSE
	vote.finalize_vote("Спокойная ночь")
	if(state.style_id != "quiet")
		Fail("The Quiet Night choice must map to the quiet policy.")
	state.finalized = FALSE
	vote.finalize_vote("Война Принцев")
	if(state.style_id != "war")
		Fail("War must remain selected independently of starting lobby population.")
	GLOB.city_round_style = old_state

/datum/unit_test/city_round_style/persistence_eligibility/Run()
	var/datum/city_round_style/unit_test/state = allocate(/datum/city_round_style/unit_test)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	state.businesses["test-shop"] = business
	state.required_factions = list(FACTION_CAMARILLA = TRUE, FACTION_SABBAT = TRUE)
	state.finalized = TRUE
	state.style_id = "war"
	for(var/index in 1 to 39)
		state.record_activity("Player [index]", 40 MINUTES, FACTION_CAMARILLA)
	state.record_activity("Player 40", 39 MINUTES, FACTION_SABBAT)
	if(state.qualified_accounts() != 39 || state.save_owners() || state.commits)
		Fail("Forty joined accounts do not qualify when one has fewer than forty active minutes.")
	// Reconnecting/changing capitalization accumulates on the same account.
	state.record_activity("PLAYER 40", 1 MINUTES, FACTION_SABBAT)
	if(length(state.active_time) != 40 || state.qualified_accounts() != 40 || !state.can_save_owners())
		Fail("Late arrivals may reach forty active minutes; reconnects must not duplicate accounts.")
	state.represented_factions -= FACTION_SABBAT
	if(state.can_save_owners())
		Fail("Every initially owning faction must have actual representation, even at forty eligible accounts.")
	state.record_activity("Player 40", 1, FACTION_SABBAT)
	state.style_id = "eternal"
	if(state.save_owners() || state.commits)
		Fail("Eternal Struggle must leave the previous ownership file untouched.")
	state.style_id = "quiet"
	if(state.save_owners() || state.commits)
		Fail("Quiet Night must never write territory ownership.")
	state.style_id = "war"
	if(!state.save_owners() || state.commits != 1 || state.save_owners())
		Fail("An eligible completed War must commit ownership exactly once.")
	var/list/owners = state.committed["owners"]
	if(length(state.committed) != 2 || state.committed["version"] != 1 || length(owners) != 1 || owners["test-shop"] != business.owner_faction)
		Fail("Persistence may contain only a schema version and territory-to-owner mapping.")

/datum/unit_test/city_round_style/ownership_loading/Run()
	var/datum/city_round_style/unit_test/state = allocate(/datum/city_round_style/unit_test)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	state.businesses["test-shop"] = business
	business.register_cash = 150
	business.robbery_retry_at = 42
	state.required_factions[FACTION_CAMARILLA] = TRUE
	state.load_owners(list("version" = 1, "owners" = list("test-shop" = FACTION_GIOVANNI, "stale-shop" = FACTION_SABBAT)))
	if(business.owner_faction != FACTION_GIOVANNI || business.register_cash != 150 || business.robbery_retry_at != 42 || length(state.businesses) != 1 || !state.required_factions[FACTION_CAMARILLA])
		Fail("Loading owners must not change the required seed factions, cash, cooldowns or map's territory set.")
	state.load_owners(list("version" = 1, "owners" = list("test-shop" = "not-a-faction")))
	state.load_owners(list("version" = 99, "owners" = list("test-shop" = FACTION_ANARCHS)))
	state.load_owners(list("version" = 1, "owners" = "malformed"))
	if(business.owner_faction != FACTION_GIOVANNI)
		Fail("Unknown factions, schemas and malformed ownership data must not replace valid owners.")

/datum/unit_test/city_round_style/active_clock/Run()
	var/datum/city_round_style/unit_test/state = allocate(/datum/city_round_style/unit_test)
	state.required_factions[FACTION_CAMARILLA] = TRUE
	state.sample_accounts(list("player" = FACTION_CAMARILLA), 1 SECONDS)
	if(state.active_time["player"])
		Fail("The first active sample must not credit time before arrival.")
	state.sample_accounts(list("player" = FACTION_CAMARILLA), 1 SECONDS)
	if(state.active_time["player"] != 1 SECONDS || !state.represented_factions[FACTION_CAMARILLA])
		Fail("A continuous active interval must credit exactly its duration and actual faction.")
	state.sample_accounts(list(), 10 MINUTES)
	state.sample_accounts(list("player" = FACTION_CAMARILLA), 1 SECONDS)
	if(state.active_time["player"] != 1 SECONDS)
		Fail("An AFK/disconnected/ghost interval and the first sample after returning must earn no time.")
	state.sample_accounts(list("player" = FACTION_CAMARILLA), 1 SECONDS)
	if(length(state.active_time) != 1 || state.active_time["player"] != 2 SECONDS)
		Fail("Rejoining must resume the same account's active total without counting the gap.")

/datum/unit_test/city_round_style/map_database/Run()
	var/path = "data/city_owners_test_[world.time].json"
	var/datum/city_round_style/state = allocate(/datum/city_round_style)
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	state.businesses["shared-id"] = business
	state.map_key = "map-a"
	state.owners_database = new(path)
	business.owner_faction = FACTION_GIOVANNI
	state.commit_owners(state.owner_payload())
	sleep(1) // Exercise the real JSON database's deferred disk write.
	QDEL_NULL(state.owners_database)
	state.owners_database = new(path)
	business.owner_faction = FACTION_CAMARILLA
	state.load_owners(state.owners_database.get_key("map-b"))
	if(business.owner_faction != FACTION_CAMARILLA)
		Fail("An identical territory ID on another map must not load this map's owners.")
	state.load_owners(state.owners_database.get_key("map-a"))
	if(business.owner_faction != FACTION_GIOVANNI)
		Fail("The real JSON database must restore owners after closing and reopening it.")
	QDEL_NULL(state.owners_database)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/city_round_style/capture_policy/Run()
	var/datum/city_round_style/old_state = GLOB.city_round_style
	var/datum/city_round_style/unit_test/state = allocate(/datum/city_round_style/unit_test)
	GLOB.city_round_style = state
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	state.style_id = "quiet"
	if(business.capture_allowed())
		Fail("Quiet Night must disable territory challenges.")
	business.declare_attack(null, FACTION_ANARCHS)
	if(business.attack_faction || business.retry_at)
		Fail("A rejected Quiet Night declaration must not reserve a faction or business cooldown.")
	state.style_id = "eternal"
	if(!business.capture_allowed() || state.can_save_owners())
		Fail("Eternal Struggle permits captures without persistence.")
	state.style_id = "war"
	if(!business.capture_allowed())
		Fail("War captures must work before the eventual persistence population threshold is met.")
	GLOB.city_round_style = old_state
#endif
