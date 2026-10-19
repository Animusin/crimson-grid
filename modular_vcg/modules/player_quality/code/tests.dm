#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/datum/unit_test/player_quality
	abstract_type = /datum/unit_test/player_quality
#ifdef PLAYER_QUALITY_TESTS
	test_flags = UNIT_TEST_FOCUS
#endif

/datum/unit_test/player_quality/persistence/Run()
	var/path = "data/pq-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	if(store.commend("Recipient", "recipient"))
		Fail("Normalized self-commendations must be rejected.")
	store.commend("Recipient", "Voter A")
	for(var/i in 1 to 20)
		store.commend("recipient", "votera")
	store.commend("recipient", "Voter B")
	var/list/record = store.read("recipient")
	var/list/commends = record["commends"]
	if(record["pq"] != 2 || commends["votera"] != 21 || commends["voterb"] != 1)
		Fail("Repeated compliments must be recorded but saturate at one PQ per giver.")
	store.award_rcp("recipient", 0.5, "round-one")
	if(store.award_rcp("Recipient", 0.5, "round-one"))
		Fail("A repeated round-end callback must not award RCP twice.")
	store.award_rcp("recipient", 1, "round-two")
	// Let the JSON database's deferred write execute, then recreate the store.
	sleep(2)
	qdel(store)
	store = new(path)
	record = store.read("Recipient")
	if(record["pq"] != 2 || record["rcp"] != 1.5)
		Fail("Both independent scores must survive a database reload.")
	store.commend("recipient", "votera")
	record = store.read("recipient")
	if(record["pq"] != 2)
		Fail("The per-giver saturation ledger must survive a reload.")
	sleep(2)
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/voting_and_rewards/Run()
	if(!SSverbs.verbs_by_verb_path[/client/verb/commend_player] || !SSverbs.verbs_by_verb_path[/client/verb/player_quality])
		Fail("Player quality actions must be registered with the current verb dispatcher.")
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/list/old_participants = controller.participants
	var/list/old_voters = controller.voters
	var/old_ended = controller.round_ended
	var/path = "data/pq-votes-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.participants = list("one" = new /datum/quality_participant, "two" = new /datum/quality_participant)
	controller.voters = list()
	controller.round_ended = FALSE
	if(controller.can_vote("one", "two"))
		Fail("Voting during a live round must be rejected.")
	controller.round_ended = TRUE
	if(controller.can_vote("lobby", "two") || controller.can_vote("one", "lobby") || controller.can_vote("one", "one"))
		Fail("Lobby-only accounts, non-participants and self-votes must be rejected.")
	if(!controller.submit_vote("one", "two") || controller.submit_vote("one", "two"))
		Fail("A participant must be able to vote exactly once per round.")
	var/datum/quality_participant/participant = new
	participant.active_time = CONFIG_GET(number/rcp_minimum_minutes) MINUTES
	participant.role_time = list("human" = participant.active_time)
	if(controller.participation_reward(participant) != CONFIG_GET(number/rcp_human_reward))
		Fail("A human must receive the configured full-round reward.")
	participant.role_time = list("ghoul" = participant.active_time)
	if(controller.participation_reward(participant) != CONFIG_GET(number/rcp_ghoul_reward))
		Fail("A ghoul must receive the configured smaller reward.")
	participant.role_time = list("supernatural" = participant.active_time)
	if(controller.participation_reward(participant))
		Fail("Supernatural play must not earn the mortal participation bonus.")
	participant.role_time = list("human" = participant.active_time / 2, "supernatural" = participant.active_time / 2)
	if(controller.participation_reward(participant) != round(CONFIG_GET(number/rcp_human_reward)/2, 0.01))
		Fail("A midround transformation must preserve the actual time split.")
	participant.active_time = CONFIG_GET(number/rcp_minimum_minutes) MINUTES - 1
	if(controller.participation_reward(participant))
		Fail("A short appearance must not earn a full-round participation grant.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.participants = old_participants
	controller.voters = old_voters
	controller.round_ended = old_ended
	qdel(participant)
	fdel(path)
	fdel("[path].savebac")
#endif
