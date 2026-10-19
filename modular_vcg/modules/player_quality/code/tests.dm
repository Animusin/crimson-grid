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
		Fail("Below the donor soft cap, repeated compliments must be recorded but only a new giver awards PQ.")
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

/datum/unit_test/player_quality/pending_database_flush/Run()
	var/path = "data/pq-pending-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	store.award_karma("pendingwriter", 0.1, "first", "round")
	store.award_karma("pendingwriter", 0.2, "second", "round")
	// No sleep: destruction must flush the queued write before removing the DB.
	qdel(store)
	store = new(path)
	var/list/record = store.read("pendingwriter")
	if(abs(record["karma"] - 0.3) > 0.001)
		Fail("Destroying a database with pending awards must preserve every update on disk.")
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/ratwood_commend_policy/Run()
	var/path = "data/pq-commend-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	var/softcap = CONFIG_GET(number/pq_commend_softcap)
	var/cap = CONFIG_GET(number/pq_commend_cap)
	store.database.set_key("veteran", list("version" = 2, "pq" = softcap, "rcp" = 0, "commends" = list("oldgiver" = 10)))
	store.commend("veteran", "oldgiver")
	store.commend("veteran", "newgiver")
	store.commend("veteran", "newgiver")
	var/list/record = store.read("veteran")
	var/list/commends = record["commends"]
	if(abs(record["pq"] - softcap - 0.6) > 0.001 || commends["oldgiver"] != 11 || commends["newgiver"] != 2)
		Fail("Ratwood-2.0's mature band must award 0.5 for a new giver and 0.05 for each later commend.")
	store.database.set_key("capped", list("pq" = cap - 0.01))
	store.commend("capped", "first")
	store.commend("capped", "second")
	record = store.read("capped")
	if(record["pq"] != cap)
		Fail("Automatic commendations must saturate at the donor's configured PQ ceiling.")
	store.database.set_key("reduced", list("version" = 2, "pq" = -3, "commends" = list("oldgiver" = 20)))
	store.commend("reduced", "oldgiver")
	record = store.read("reduced")
	if(record["pq"] != -3 || record["version"] != 3)
		Fail("Migration and administrative reductions must retain scores and the previous giver ledger without backfill.")
	store.commend("reduced", "newgiver")
	record = store.read("reduced")
	if(record["pq"] != -2)
		Fail("A new giver must still award one point to a recipient with negative PQ.")
	sleep(2)
	qdel(store)
	store = new(path)
	store.commend("veteran", "oldgiver")
	record = store.read("veteran")
	if(abs(record["pq"] - softcap - 0.65) > 0.001)
		Fail("The donor's repeat-giver policy and ledger must survive database reloads.")
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/karma_debits/Run()
	var/path = "data/pq-debit-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	if(store.spend_karma("empty", 3, "respec", "empty", "one") || store.database.get_key("empty"))
		Fail("Insufficient funds must neither debit nor create a persisted account record.")
	store.database.set_key("payer", list("pq" = 12, "rcp" = 8, "karma" = 8))
	var/before = json_encode(store.database.get_key("payer"))
	if(store.spend_karma("payer", -3, "respec", "payer") || store.spend_karma("payer", 0, "respec", "payer") || store.spend_karma("payer", 0.001, "respec", "payer") || store.spend_karma("payer", 3, "", "payer") || store.spend_karma("payer", 3, "respec", null))
		Fail("A Karma debit requires a positive cent-precision amount, actor and reason.")
	if(json_encode(store.database.get_key("payer")) != before)
		Fail("Rejected debit requests must leave all persisted data unchanged.")
	if(!store.spend_karma("Payer", 3, "attributes respec", "Payer", "unlock-one") || !store.spend_karma("payer", 3, "attributes respec", "payer", "unlock-one"))
		Fail("A valid debit and its exact idempotent retry must both succeed.")
	if(store.spend_karma("payer", 5, "other respec", "payer", "unlock-one"))
		Fail("A transaction token cannot be reused for a different debit.")
	var/list/record = store.read("payer")
	if(record["karma"] != 5 || record["pq"] != 12 || record["rcp"] != 8)
		Fail("An exact debit retry must spend once and preserve PQ/RCP.")
	sleep(2)
	qdel(store)
	store = new(path)
	if(!store.spend_karma("payer", 3, "attributes respec", "payer", "unlock-one"))
		Fail("An exact debit retry must remain idempotent after database reload.")
	if(!store.spend_karma("payer", 5, "other respec", "payer", "unlock-two") || store.spend_karma("payer", 1, "no funds", "payer", "unlock-three"))
		Fail("Sequential debits must recheck the latest balance and reject overdrafts.")
	record = store.read("payer")
	if(record["karma"] != 0 || store.respect("payer") != 14)
		Fail("A debit must immediately update Respect using the RCP quarter weight.")
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
	for(var/account in controller.participants)
		var/datum/quality_participant/eligible = controller.participants[account]
		eligible.active_time = 5 MINUTES
	controller.voters = list()
	controller.round_ended = FALSE
	if(controller.can_vote("one", "two"))
		Fail("Voting during a live round must be rejected.")
	controller.round_ended = TRUE
	if(controller.can_vote("lobby", "two") || controller.can_vote("one", "lobby") || controller.can_vote("one", "one"))
		Fail("Lobby-only accounts, non-participants and self-votes must be rejected.")
	controller.store.database.set_key("two", list("pq" = CONFIG_GET(number/pq_commend_softcap)))
	if(!controller.submit_vote("one", "two") || controller.submit_vote("one", "two"))
		Fail("A participant must be able to vote exactly once per round.")
	var/list/vote_record = controller.store.read("two")
	if(abs(vote_record["pq"] - CONFIG_GET(number/pq_commend_softcap) - 0.5) > 0.001)
		Fail("A repeat submission must not bypass the round limit and earn a mature-band repeat award.")
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

/datum/unit_test/player_quality/karma_and_respect/Run()
	if(calculate_respect(3, 4, 0) != 4 || calculate_respect(-3, -4, 0) != -4 || calculate_respect(3, 4, -5) != -1 || calculate_respect(0, 0, -5) != -5)
		Fail("Respect must sum PQ, one quarter RCP and Karma, including negative results.")
	if(calculate_respect(-3, 4, 0) != -2 || calculate_respect(0, -4, 0) != -1)
		Fail("Negative PQ, RCP and Karma must subtract with their selected weights.")
	if(respect_age_cap_for_score(-1) != -1 || respect_age_cap_for_score(CONFIG_GET(number/respect_fledgling_threshold) - 0.01) != -1 || respect_age_cap_for_score(CONFIG_GET(number/respect_fledgling_threshold)) != 10 || respect_age_cap_for_score(CONFIG_GET(number/respect_neonate_threshold)) != 100 || respect_age_cap_for_score(CONFIG_GET(number/respect_ancilla_threshold)) != 200 || respect_age_cap_for_score(CONFIG_GET(number/respect_elder_threshold)) != 1000)
		Fail("Kindred caps must follow the configured Respect thresholds and existing age bands.")
	var/path = "data/pq-karma-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	store.database.set_key("legacy", list("version" = 1, "pq" = -3, "rcp" = 4, "commends" = list("giver" = 1)))
	var/list/record = store.read("legacy")
	if(record["karma"] != 0 || record["pq"] != -3 || record["rcp"] != 4 || record["version"] != 3)
		Fail("Legacy saves must gain Karma without resetting negative or positive scores.")
	if(!store.award_karma("legacy", -1, "kill:first", "round") || store.award_karma("Legacy", -1, "kill:first", "round"))
		Fail("Karma events must be normalized and idempotent.")
	sleep(2)
	qdel(store)
	store = new(path)
	record = store.read("legacy")
	if(record["karma"] != -1 || store.award_karma("legacy", -1, "kill:first", "round"))
		Fail("Karma and the event ledger must survive a database reload.")
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/contribution_limits/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/list/old_sessions = controller.karma_sessions
	var/path = "data/pq-limits-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.karma_sessions = list()
	controller.record_help_amount("healer", "patient", 10)
	var/list/record = controller.store.read("healer")
	if(record["karma"])
		Fail("Nominal medical item use must not award Karma before 20 real damage is restored.")
	if(!controller.record_help_amount("healer", "patient", 10) || controller.record_help_amount("healer", "patient", 1000) || controller.record_help_amount("healer", "healer", 1000))
		Fail("Only another patient's first meaningful treatment may award Karma each round.")
	if(!controller.record_defense("defender", "shop-one", "attack-one", "anarchs") || controller.record_defense("defender", "shop-one", "attack-two", "sabbat") || controller.record_defense("defender", "shop-two", "attack-two", "anarchs") || !controller.record_defense("defender", "shop-two", "attack-three", "sabbat") || controller.record_defense("defender", "shop-three", "attack-four", "triads"))
		Fail("Defense rewards must reject repeat points/opponents and stop after two points per round.")
	var/message = "This is a distinct sentence about the unfolding scene and the people involved. "
	for(var/i in 1 to 30)
		controller.record_roleplay_text("speaker", message)
	record = controller.store.read("speaker")
	if(record["karma"])
		Fail("Repeating the same say-log line must never generate Karma.")
	for(var/i in 1 to 30)
		controller.record_roleplay_text("speaker", "[message] [i] [message]")
	record = controller.store.read("speaker")
	if(abs(record["karma"] - CONFIG_GET(number/karma_roleplay_reward)) > 0.001)
		Fail("Distinct RP text must produce one bounded award, not a reward per message.")
	var/datum/quality_karma_session/session = controller.karma_sessions["speaker"]
	if(session.next_roleplay_award <= world.time)
		Fail("RP text rewards must have a real cooldown.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.karma_sessions = old_sessions
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/combat_attribution/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-combat-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/npc = allocate(/mob/living/carbon/human/consistent)
	attacker.mind_initialize()
	victim.mind_initialize()
	attacker.mind.key = "qualityattacker"
	victim.mind.key = "qualityvictim"
	// Player minds count even without a human job (event/animal/custom roles).
	npc.mind_initialize()
	if(quality_player_account(npc))
		Fail("An NPC mind without a player key must not be treated as a player.")
	if(controller.record_harm(npc, attacker, 10, BRUTE) || controller.record_harm(victim, attacker, 10, STAMINA) || controller.record_harm(victim, attacker, 0, BRUTE))
		Fail("NPCs, stamina-only attacks and blocked hits must not acquire kill attribution.")
	var/obj/projectile/projectile = allocate(/obj/projectile/bullet)
	projectile.firer = attacker
	victim.apply_damage(10, BRUTE, attacking_item = projectile)
	if(victim.quality_last_attacker != "qualityattacker")
		Fail("Actual projectile damage must record its firing player, not melee-only lastattackerckey.")
	// A real lethal hit can emit DEATH from inside apply_damage, before its return.
	victim.apply_damage(500, OXY, attacking_item = projectile)
	if(victim.stat != DEAD)
		Fail("The combat fixture must actually die from the applied lethal damage.")
	require_death_settlement(victim)
	var/list/record = controller.store.read("qualityattacker")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("Killing a player character, including a disconnected body, must lose Karma once.")
	victim.apply_damage(10, BRUTE, attacking_item = projectile)
	if(victim.quality_last_attack_time == world.time)
		Fail("Attacking a corpse must not create a new killing event.")
	victim.revive(ADMIN_HEAL_ALL)
	if(victim.quality_last_attacker)
		Fail("A revive must clear stale attribution from the previous life.")
	controller.record_harm(victim, attacker, 10, BRUTE)
	projectile.firer = victim
	victim.apply_damage(10, BRUTE, attacking_item = projectile)
	if(victim.quality_last_attacker)
		Fail("Actual self-harm must replace a prior opponent's attribution.")
	victim.death()
	require_death_settlement(victim)
	record = controller.store.read("qualityattacker")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("Self-inflicted death must not punish the preceding attacker.")
	victim.revive(ADMIN_HEAL_ALL)
	victim.adjust_attributed_damage(500, OXY, attacker)
	if(victim.stat != DEAD)
		Fail("Attributed direct discipline-style damage must actually kill the fixture.")
	require_death_settlement(victim)
	record = controller.store.read("qualityattacker")
	if(record["karma"] != -2 * CONFIG_GET(number/karma_player_kill_penalty))
		Fail("Direct offensive powers using explicit actor attribution must lose Karma for a player kill.")
	var/mob/living/carbon/human/new_attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/gib_victim = allocate(/mob/living/carbon/human/consistent)
	new_attacker.mind_initialize()
	gib_victim.mind_initialize()
	new_attacker.mind.key = "qualitynewattacker"
	gib_victim.mind.key = "qualitygibvictim"
	controller.record_harm(gib_victim, attacker, 10, BRUTE)
	var/datum/quality_gib_fixture/gibber = allocate(/datum/quality_gib_fixture)
	gibber.RegisterSignal(gib_victim, COMSIG_MOB_AFTER_APPLY_DAMAGE, TYPE_PROC_REF(/datum/quality_gib_fixture, gib_after_damage))
	projectile.firer = new_attacker
	gib_victim.apply_damage(10, BRUTE, attacking_item = projectile)
	require_death_settlement(gib_victim)
	record = controller.store.read("qualitynewattacker")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("A synchronously gibbed victim must preserve the actual new attacker after its mind is removed.")
	record = controller.store.read("qualityattacker")
	if(record["karma"] != -2 * CONFIG_GET(number/karma_player_kill_penalty))
		Fail("An earlier attacker must not inherit a new attacker's lethal gib.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/execution_attribution/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-execution-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/executioner = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/previous_attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	executioner.mind_initialize()
	previous_attacker.mind_initialize()
	victim.mind_initialize()
	executioner.mind.key = "qualityexecutor"
	previous_attacker.mind.key = "qualityprevious"
	victim.mind.key = "qualitysacrifice"
	var/obj/structure/retail/occult/baali/rune = allocate(/obj/structure/retail/occult/baali)
	controller.record_harm(victim, previous_attacker, 10, BRUTE)
	victim.set_stat(HARD_CRIT)
	// Both live-sacrifice branches use this actual dust path, without fake damage.
	rune.dust_sacrifice(victim, executioner)
	if(victim.stat != DEAD)
		Fail("The live Baali sacrifice fixture must really die through dust().")
	require_death_settlement(victim)
	var/list/record = controller.store.read("qualityexecutor")
	if(abs(record["karma"] + CONFIG_GET(number/karma_player_kill_penalty)) > 0.001)
		Fail("A live player sacrifice must penalize its explicit executioner once.")
	record = controller.store.read("qualityprevious")
	if(record["karma"])
		Fail("The sacrifice must not blame an earlier attacker instead of the executioner.")
	// Reprocessing a corpse, including another sacrifice, must not change its source.
	if(controller.record_execution(victim, previous_attacker))
		Fail("A dead player's corpse cannot acquire new execution attribution.")
	rune.dust_sacrifice(victim, previous_attacker)
	var/mob/living/carbon/human/npc = allocate(/mob/living/carbon/human/consistent)
	npc.mind_initialize()
	if(controller.record_execution(npc, executioner))
		Fail("An NPC with no player key must not count as an executed player.")
	rune.dust_sacrifice(npc, executioner)
	controller.record_harm(executioner, previous_attacker, 10, BRUTE)
	controller.record_execution(executioner, executioner)
	executioner.death()
	require_death_settlement(executioner)
	record = controller.store.read("qualityprevious")
	if(record["karma"])
		Fail("Corpse processing and self-execution must not penalize an earlier attacker.")
	record = controller.store.read("qualityexecutor")
	if(abs(record["karma"] + CONFIG_GET(number/karma_player_kill_penalty)) > 0.001)
		Fail("NPC sacrifices and repeated dust calls must not create extra Karma penalties.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/client_interface/quality_test/proc/is_afk(duration)
	return FALSE

/datum/quality_gib_fixture/proc/gib_after_damage(mob/living/victim, amount)
	SIGNAL_HANDLER
	if(amount > 0)
		victim.gib()

/datum/unit_test/player_quality/medical_and_age_hooks/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/list/old_sessions = controller.karma_sessions
	var/old_ended = controller.round_ended
	var/path = "data/pq-hooks-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.karma_sessions = list()
	controller.round_ended = FALSE
	var/mob/living/carbon/human/healer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/quality_test/healer_client = allocate(/datum/client_interface/quality_test, "qualitymedic")
	var/datum/client_interface/quality_test/patient_client = allocate(/datum/client_interface/quality_test, "qualitypatient")
	healer.mock_client = healer_client
	patient.mock_client = patient_client
	healer_client.mob = healer
	patient_client.mob = patient
	healer.mind_initialize()
	patient.mind_initialize()
	healer.mind.key = healer_client.key
	patient.mind.key = patient_client.key
	var/obj/item/stack/medical/bruise_pack/pack = allocate(/obj/item/stack/medical/bruise_pack)
	patient.apply_damage(25, BRUTE, BODY_ZONE_CHEST)
	pack.heal_carbon(patient, healer, BODY_ZONE_CHEST)
	var/list/record = controller.store.read(healer_client.ckey)
	if(patient.get_brute_loss() != 0 || abs(record["karma"] - CONFIG_GET(number/karma_help_reward)) > 0.001)
		Fail("Real medical-pack treatment must report real restored damage into Karma.")
	pack.heal_carbon(patient, healer, BODY_ZONE_CHEST)
	record = controller.store.read(healer_client.ckey)
	if(abs(record["karma"] - CONFIG_GET(number/karma_help_reward)) > 0.001)
		Fail("Using a medical pack on an unhurt patient cannot create additional Karma.")
	var/datum/client_interface/quality_test/gate_client = allocate(/datum/client_interface/quality_test, "qualitygate")
	gate_client.prefs = new(gate_client)
	var/datum/preferences/preferences = gate_client.prefs
	// Simulate an existing older saved character, including bypasses of UI setters.
	preferences.value_cache[/datum/preference/choiced/splats] = /datum/splat/vampire/kindred
	preferences.value_cache[/datum/preference/numeric/immortal_age] = 300
	if(preferences.respect_kindred_age_cap() != -1 || respect_kindred_available(gate_client.ckey))
		Fail("Below ten Respect, all Kindred including age-zero fledglings must be unavailable.")
	if(preferences.respect_immortal_age() != 0)
		Fail("An unavailable Kindred sheet must never produce a negative applied age.")
	var/mob/dead/new_player/lobby = allocate(/mob/dead/new_player)
	if(SSjob.check_kindred_prefs(gate_client, lobby, SSjob.get_job_type(/datum/job/vampire/citizen)) != JOB_UNAVAILABLE_KINDRED_AGE_MAX)
		Fail("An existing over-age saved character must be rejected by actual job assignment.")
	preferences.value_cache[/datum/preference/numeric/immortal_age] = 0
	if(SSjob.check_kindred_prefs(gate_client, lobby, SSjob.get_job_type(/datum/job/vampire/citizen)) != JOB_UNAVAILABLE_KINDRED_AGE_MAX)
		Fail("A saved age-zero Kindred must also be rejected below the access threshold.")
	preferences.value_cache[/datum/preference/numeric/immortal_age] = 300
	var/datum/preference_middleware/player_respect/middleware = new(preferences)
	if(!middleware.pre_set_preference(healer, "splats", SPLAT_KINDRED) || middleware.pre_set_preference(healer, "splats", SPLAT_GHOUL) || middleware.pre_set_preference(healer, "splats", SPLAT_NONE))
		Fail("Selection middleware must block Kindred while preserving mortal and ghoul options.")
	var/datum/preference/choiced/splats/splat_preference = GLOB.preference_entries[/datum/preference/choiced/splats]
	var/mob/living/carbon/human/spawn_target = allocate(/mob/living/carbon/human/consistent)
	splat_preference.apply_to_human(spawn_target, /datum/splat/vampire/kindred, preferences)
	if(spawn_target.get_splat(/datum/splat/vampire/kindred))
		Fail("Direct preference application must not bypass the unavailable Kindred gate.")
	controller.store.database.set_key(gate_client.ckey, list("pq" = CONFIG_GET(number/respect_fledgling_threshold)))
	if(preferences.respect_kindred_age_cap() != 10 || !respect_kindred_available(gate_client.ckey))
		Fail("The fledgling tier must unlock exactly at its configured Respect threshold.")
	if(preferences.respect_immortal_age() != 10 || get_discipline_point_budget(preferences.respect_immortal_age())["points"] != DISCIPLINE_BUDGET_FLEDGLING)
		Fail("A saved elder sheet must not retain an elder discipline budget behind the age cap.")
	var/datum/preference/numeric/immortal_age/age_preference = GLOB.preference_entries[/datum/preference/numeric/immortal_age]
	var/before_age = healer.chronological_age
	age_preference.apply_to_human(healer, 300, preferences)
	if(healer.chronological_age != before_age + 10 || preferences.read_preference(/datum/preference/numeric/immortal_age) != 300)
		Fail("Spawn application must enforce the cap without silently rewriting the saved age.")
	preferences.value_cache[/datum/preference/choiced/splats] = /datum/splat/vampire/ghoul
	if(preferences.respect_kindred_age_cap() != 1000)
		Fail("Switching to a ghoul must not inherit a Kindred age restriction.")
	preferences.value_cache[/datum/preference/choiced/splats] = /datum/splat/werewolf/shifter
	if(preferences.respect_kindred_age_cap() != 1000)
		Fail("Werewolf progression must remain outside the Kindred Respect gate.")
	preferences.value_cache[/datum/preference/choiced/splats] = /datum/splat/vampire/kindred
	if(preferences.respect_kindred_age_cap() != 10)
		Fail("Switching back to Kindred must restore account age restrictions.")
	qdel(middleware)
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.karma_sessions = old_sessions
	controller.round_ended = old_ended
	qdel(gate_client.prefs)
	fdel(path)
	fdel("[path].savebac")
#ifdef BUSINESS_TESTS
/datum/unit_test/player_quality/business_defense_integration/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/list/old_sessions = controller.karma_sessions
	var/old_ended = controller.round_ended
	var/path = "data/pq-defense-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.karma_sessions = list()
	controller.round_ended = FALSE
	var/obj/structure/city_business/unit_test/business = allocate(/obj/structure/city_business/unit_test)
	business.territory_id = "pq-integration-shop"
	business.owner_faction = FACTION_CAMARILLA
	business.attack_faction = FACTION_ANARCHS
	business.attack_token = "pq-integration-attack"
	var/mob/living/carbon/human/business_test/defender = allocate(/mob/living/carbon/human/business_test)
	var/datum/client_interface/quality_test/player = allocate(/datum/client_interface/quality_test, "qualitydefender")
	defender.mock_client = player
	player.mob = defender
	defender.mind_initialize()
	defender.mind.key = player.key
	business.track_defense(list(defender), TRUE)
	var/list/record = controller.store.read(player.ckey)
	if(record["karma"] != CONFIG_GET(number/karma_defense_reward))
		Fail("An actual business defense signal must reach the optional progression listener and persist Karma.")
	business.track_defense(list(defender), TRUE)
	record = controller.store.read(player.ckey)
	if(record["karma"] != CONFIG_GET(number/karma_defense_reward))
		Fail("Repeated tracking within the same business contest must not duplicate Karma.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.karma_sessions = old_sessions
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")
#endif
#endif
