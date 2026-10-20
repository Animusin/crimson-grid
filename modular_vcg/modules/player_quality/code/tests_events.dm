#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/// SStimer can run later than a fixed sleep under map-initialization load.
/// qdel happens after the debit write; settled alone is set before that write.
/datum/unit_test/player_quality/proc/wait_for_death_settlement(mob/living/victim)
	var/datum/quality_death_event/event = victim.quality_pending_death
	if(!event)
		return FALSE
	var/deadline = world.time + 5 SECONDS
	while(!QDELETED(event) && world.time < deadline)
		sleep(1)
	return QDELETED(event)

/datum/unit_test/player_quality/proc/require_death_settlement(mob/living/victim)
	if(!wait_for_death_settlement(victim))
		Fail("The captured death must settle before its persisted Karma is checked.")

/datum/unit_test/player_quality/summon_kills/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-summon-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/master = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	master.mind_initialize()
	victim.mind_initialize()
	master.mind.key = "qualitysummoner"
	victim.mind.key = "qualitysummonvictim"
	var/mob/living/basic/mouse/minion = allocate(/mob/living/basic/mouse)
	if(!master.add_beastmaster_minion(minion))
		Fail("The fixture must bind through the actual beastmaster ownership API.")
	if(quality_player_account(minion) || minion.quality_responsible_account() != "qualitysummoner")
		Fail("An owned NPC must resolve its damage actor to its owner while remaining an NPC victim.")
	minion.melee_damage_lower = 500
	minion.melee_damage_upper = 500
	minion.melee_damage_type = OXY
	var/damage_done = victim.attack_basic_mob(minion)
	var/stat_after_hit = victim.stat
	if(!wait_for_death_settlement(victim))
		Fail("The summon kill's captured death event did not finish settlement within five seconds.")
	var/list/record = controller.store.read("qualitysummoner")
	if(victim.stat != DEAD || record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("A real lethal basic-mob attack must debit its summoner once. damage=[damage_done], stat_after_hit=[stat_after_hit], stat_now=[victim.stat], DEAD=[DEAD], health=[victim.health], karma=[record["karma"]], expected=[-CONFIG_GET(number/karma_player_kill_penalty)], last_actor=[victim.quality_last_attacker], record=[json_encode(record)].")
	if(controller.record_harm(minion, master, 10, BRUTE) || controller.record_execution(minion, master))
		Fail("Killing a player-owned NPC must never be counted as killing its owner.")
	master.remove_beastmaster_minion(minion)
	if(minion.quality_responsible_account())
		Fail("Releasing an NPC must clear its former owner's attribution.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/corpse_dismember_attribution/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-corpse-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/killer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/master = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/quality_corpse/victim = allocate(/mob/living/carbon/human/consistent/quality_corpse)
	killer.mind_initialize()
	master.mind_initialize()
	victim.mind_initialize()
	killer.mind.key = "qualityactualkiller"
	master.mind.key = "qualitycorpseowner"
	victim.mind.key = "qualitycorpse"
	var/mob/living/basic/mouse/minion = allocate(/mob/living/basic/mouse)
	master.add_beastmaster_minion(minion)
	minion.limb_destroyer = TRUE
	minion.set_combat_mode(TRUE)
	minion.melee_damage_lower = 10
	minion.melee_damage_upper = 10
	victim.adjust_attributed_damage(500, OXY, killer)
	for(var/obj/item/bodypart/limb as anything in victim.bodyparts)
		if(limb.body_zone != BODY_ZONE_CHEST && limb.body_zone != BODY_ZONE_HEAD)
			limb.brute_dam = limb.max_damage
	var/list/original_parts = victim.bodyparts.Copy()
	var/original_limbs = 0
	var/original_stumps = 0
	var/list/limb_states = list()
	for(var/obj/item/bodypart/limb as anything in victim.bodyparts)
		if(IS_STUMP(limb))
			original_stumps++
		else
			original_limbs++
		limb_states += "[limb.body_zone]:[limb.get_damage()]/[limb.max_damage]:flags[limb.bodypart_flags]:owned[limb.owner == victim]"
	// Same tick as the real death: a corpse attack must not rewrite its source.
	var/attack_result = victim.attack_basic_mob(minion)
	var/remaining_limbs = 0
	var/remaining_stumps = 0
	for(var/obj/item/bodypart/limb as anything in victim.bodyparts)
		if(IS_STUMP(limb))
			remaining_stumps++
		else
			remaining_limbs++
	var/detached_originals = 0
	for(var/obj/item/bodypart/limb as anything in original_parts)
		if(!IS_STUMP(limb) && isnull(limb.owner))
			detached_originals++
	// Darkpack replaces a lost limb with a stump, preserving bodyparts.len.
	if(remaining_limbs != original_limbs - 1 || remaining_stumps != original_stumps + 1 || detached_originals != 1 || victim.quality_strike_calls != 1 || !isnull(victim.quality_strike_result))
		Fail("The corpse regression must actually take the successful dismemberment branch. result=[attack_result], strike_calls=[victim.quality_strike_calls], strike_result=[victim.quality_strike_result], block_source=[victim.quality_block_source], block_result=[victim.quality_block_result], melee=[minion.melee_damage_lower]..[minion.melee_damage_upper], wounds=[length(victim.all_wounds)], intact=[original_limbs]->[remaining_limbs], stumps=[original_stumps]->[remaining_stumps], detached_originals=[detached_originals], limb_states=[json_encode(limb_states)], victim_stat=[victim.stat], combat=[minion.combat_mode], limb_destroyer=[minion.limb_destroyer], pacifist=[HAS_TRAIT(minion, TRAIT_PACIFISM)], nodismember=[HAS_TRAIT(victim, TRAIT_NODISMEMBER)], godmode=[HAS_TRAIT(victim, TRAIT_GODMODE)].")
	if(!wait_for_death_settlement(victim))
		Fail("The corpse regression's original death event did not finish settlement within five seconds.")
	var/list/killer_record = controller.store.read("qualityactualkiller")
	var/list/master_record = controller.store.read("qualitycorpseowner")
	if(killer_record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty) || master_record["karma"])
		Fail("Dismembering a corpse must not transfer the same-tick kill to a minion's owner. killer_karma=[killer_record["karma"]], expected=[-CONFIG_GET(number/karma_player_kill_penalty)], master_karma=[master_record["karma"]], last_actor=[victim.quality_last_attacker], killer_record=[json_encode(killer_record)].")
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/// Observe the real inherited strike without replacing its selection/removal.
/mob/living/carbon/human/consistent/quality_corpse
	var/quality_strike_calls = 0
	var/quality_strike_result
	var/quality_block_source
	var/quality_block_result

/mob/living/carbon/human/consistent/quality_corpse/check_block(atom/hit_by, damage, attack_text = "the attack", attack_type = MELEE_ATTACK, armour_penetration = 0, damage_type = BRUTE)
	. = ..()
	quality_block_source = "[hit_by?.type]/[REF(hit_by)]"
	quality_block_result = .

/mob/living/carbon/human/consistent/quality_corpse/dismembering_strike(mob/living/attacker, dam_zone)
	quality_strike_calls++
	. = ..()
	quality_strike_result = .

/datum/unit_test/player_quality/minion_objective_authorization/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-minion-goal-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/master = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/basic/mouse/minion = allocate(/mob/living/basic/mouse)
	var/mob/living/basic/mouse/sibling = allocate(/mob/living/basic/mouse)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent)
	master.mind_initialize()
	minion.mind_initialize()
	victim.mind_initialize()
	bystander.mind_initialize()
	master.mind.key = "qualitycullmaster"
	minion.mind.key = "qualitycullminion"
	victim.mind.key = "qualityculltarget"
	bystander.mind.key = "qualitycullbystander"
	var/datum/antagonist/heretic_monster/monster = allocate(/datum/antagonist/heretic_monster)
	monster.owner = minion.mind
	minion.mind.antag_datums = list(monster)
	monster.set_owner(master.mind)
	var/datum/objective/heretic_crew_cull/goal = allocate(/datum/objective/heretic_crew_cull)
	goal.owner = minion.mind
	goal.completed = TRUE
	monster.objectives += goal
	master.add_beastmaster_minion(sibling)
	victim.mind.assigned_role = SSjob.get_job_type(/datum/job/vampire/citizen)
	var/list/station_levels = SSmapping.levels_by_trait(ZTRAIT_STATION)
	if(length(station_levels))
		victim.forceMove(locate(1, 1, station_levels[1]))
	else
		Fail("The cull regression requires a loaded station level for the real victim-set predicate.")
	// This reproduces lock_tear's own minion goal after its actual set_owner call.
	victim.adjust_attributed_damage(500, OXY, minion)
	require_death_settlement(victim)
	var/list/record = controller.store.read("qualitycullmaster")
	if(record["karma"])
		Fail("A bound monster's explicit cull target must waive its responsible owner's debit.")
	victim.revive(ADMIN_HEAL_ALL)
	victim.adjust_attributed_damage(500, OXY, master)
	require_death_settlement(victim)
	record = controller.store.read("qualitycullmaster")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("A minion's cull goal must not waive the owner's direct unrelated actions.")
	victim.revive(ADMIN_HEAL_ALL)
	victim.adjust_attributed_damage(500, OXY, sibling)
	require_death_settlement(victim)
	record = controller.store.read("qualitycullmaster")
	if(record["karma"] != -2 * CONFIG_GET(number/karma_player_kill_penalty))
		Fail("A minion's explicit goal must not waive a sibling summon's actions.")
	bystander.mind.assigned_role = null
	bystander.adjust_attributed_damage(500, OXY, minion)
	require_death_settlement(bystander)
	record = controller.store.read("qualitycullmaster")
	if(record["karma"] != -3 * CONFIG_GET(number/karma_player_kill_penalty))
		Fail("The same bound monster must still cost its owner Karma for a non-target player death.")
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/objective_kill_rules/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-objectives-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/actor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent)
	actor.mind_initialize()
	target.mind_initialize()
	bystander.mind_initialize()
	actor.mind.key = "qualityantagonist"
	target.mind.key = "qualitytarget"
	bystander.mind.key = "qualitybystander"
	var/datum/antagonist/custom/antag = allocate(/datum/antagonist/custom)
	antag.owner = actor.mind
	actor.mind.antag_datums = list(antag)
	var/datum/objective/assassinate/murder = allocate(/datum/objective/assassinate)
	murder.owner = actor.mind
	murder.target = target.mind
	antag.objectives = list(murder)
	if(!quality_objective_kill(actor.mind, target.mind, target) || quality_objective_kill(actor.mind, bystander.mind, bystander))
		Fail("Assassination must waive only the explicit victim, never unrelated players.")
	// Capture target identity at death; later objective edits must not rewrite it.
	target.adjust_attributed_damage(500, OXY, actor)
	murder.target = bystander.mind
	require_death_settlement(target)
	var/list/record = controller.store.read("qualityantagonist")
	if(record["karma"])
		Fail("A valid kill target must retain its death-time waiver after retargeting.")
	murder.target = target.mind
	bystander.adjust_attributed_damage(500, OXY, actor)
	require_death_settlement(bystander)
	record = controller.store.read("qualityantagonist")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("Having an antagonist murder objective must still penalize a non-target player kill.")
	var/datum/objective/protect/protect = allocate(/datum/objective/protect)
	protect.target = target.mind
	var/datum/objective/custom/text_goal = allocate(/datum/objective/custom)
	text_goal.explanation_text = "Kill everyone on the station."
	antag.objectives = list(protect, text_goal)
	if(quality_objective_kill(actor.mind, target.mind, target))
		Fail("Protection and arbitrary free text must never grant a murder waiver.")
	var/datum/objective/accept_no_substitutes/clone_goal = allocate(/datum/objective/accept_no_substitutes)
	clone_goal.target_name = target.real_name
	antag.objectives = list(clone_goal)
	if(!quality_objective_kill(actor.mind, target.mind, target))
		Fail("The clone objective must use its real target-name contract rather than a missing target mind.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/objective_kill_quotas/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/old_ended = controller.round_ended
	var/path = "data/pq-quota-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.round_ended = FALSE
	var/mob/living/carbon/human/actor = allocate(/mob/living/carbon/human/consistent)
	actor.mind_initialize()
	actor.mind.key = "qualityquota"
	var/datum/antagonist/heretic/heretic = allocate(/datum/antagonist/heretic)
	heretic.owner = actor.mind
	actor.mind.antag_datums = list(heretic)
	var/datum/objective/minor_sacrifice/goal = allocate(/datum/objective/minor_sacrifice)
	goal.owner = actor.mind
	goal.target_amount = 1
	heretic.objectives = list(goal)
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	first.mind_initialize()
	second.mind_initialize()
	first.mind.key = "qualityquotafirst"
	second.mind.key = "qualityquotasecond"
	heretic.sac_targets = list(first, second)
	// Both events capture authorization in one tick, before either can settle.
	first.adjust_attributed_damage(500, OXY, actor)
	second.adjust_attributed_damage(500, OXY, actor)
	require_death_settlement(first)
	require_death_settlement(second)
	var/list/record = controller.store.read("qualityquota")
	if(record["karma"] != -CONFIG_GET(number/karma_player_kill_penalty))
		Fail("A one-victim quota must waive exactly one of two simultaneous eligible deaths.")
	heretic.total_sacrifices = 1
	if(quality_objective_kill(actor.mind, first.mind, first))
		Fail("Actual completed sacrifice progress must stop granting new kill authorizations.")
	qdel(controller.store)
	controller.store = old_store
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/surgery_persistence/Run()
	var/path = "data/pq-surgery-store-unit-[world.realtime]-[rand(1, 1000000)].json"
	var/datum/player_quality_store/store = new(path)
	var/now = world.realtime
	if(!store.award_surgery("surgeon", "patient", 0.1, "first", now) || store.award_surgery("surgeon", "patient", 0.1, "second", now + 1 MINUTES))
		Fail("A patient pair must reward once and retain its one-hour cooldown across rounds.")
	if(store.award_surgery("surgeon", "surgeon", 0.1, "first", now))
		Fail("Self surgery must never earn Karma.")
	var/expected_deadline = now + 1 HOURS
	var/list/record = store.read("surgeon")
	var/list/patients = record["surgery_patients"]
	var/list/pair = patients["patient"]
	if(!istext(pair["next_award"]) || text2num(pair["next_award"]) != expected_deadline)
		Fail("The real-clock surgery deadline must be stored as lossless decimal text.")
	var/list/roundtrip = json_decode(json_encode(pair))
	if(!istext(roundtrip["next_award"]) || text2num(roundtrip["next_award"]) != expected_deadline)
		Fail("JSON serialization must preserve the exact large real-clock deadline.")
	store.database.set_key("legacy", list("surgery_patients" = list("oldpatient" = list("awards" = 1, "next_award" = expected_deadline))))
	sleep(2)
	qdel(store)
	store = new(path)
	record = store.read("surgeon")
	patients = record["surgery_patients"]
	pair = patients["patient"]
	if(!istext(pair["next_award"]) || text2num(pair["next_award"]) != expected_deadline)
		Fail("Database reload must preserve the exact large real-clock surgery deadline.")
	if(store.award_surgery("legacy", "oldpatient", 0.1, "third", now + 1 MINUTES))
		Fail("Existing numeric surgery deadlines must retain their cooldown rather than resetting on read.")
	if(store.award_surgery("surgeon", "patient", 0.1, "third", now + 59 MINUTES) || !store.award_surgery("surgeon", "patient", 0.1, "third", now + 1 HOURS))
		Fail("The cooldown must survive disk reload and expire at exactly one hour.")
	record = store.read("surgeon")
	if(abs(record["karma"] - 0.15) > 0.001)
		Fail("The second award for the same patient must diminish from 0.1 to 0.05.")
	if(!store.award_surgery("surgeon", "another", 0.1, "third", now + 1 HOURS))
		Fail("A different patient must have a separate persistent cooldown and repeat count.")
	qdel(store)
	fdel(path)
	fdel("[path].savebac")

/datum/unit_test/player_quality/surgery_completion/Run()
	var/datum/controller/subsystem/player_quality/controller = SSplayer_quality
	var/datum/player_quality_store/old_store = controller.store
	var/list/old_sessions = controller.karma_sessions
	var/old_ended = controller.round_ended
	var/path = "data/pq-surgery-live-unit-[world.realtime]-[rand(1, 1000000)].json"
	controller.store = new(path)
	controller.karma_sessions = list()
	controller.round_ended = FALSE
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/quality_test/surgeon_client = allocate(/datum/client_interface/quality_test, "qualitysurgeon")
	var/datum/client_interface/quality_test/patient_client = allocate(/datum/client_interface/quality_test, "qualitysurgerypatient")
	surgeon.mock_client = surgeon_client
	patient.mock_client = patient_client
	surgeon_client.mob = surgeon
	patient_client.mob = patient
	surgeon.mind_initialize()
	patient.mind_initialize()
	surgeon.mind.key = surgeon_client.key
	patient.mind.key = patient_client.key
	ADD_TRAIT(surgeon, TRAIT_IGNORE_SURGERY_MODIFIERS, TRAIT_GENERIC)
	var/obj/item/organ/liver/liver = patient.get_organ_slot(ORGAN_SLOT_LIVER)
	var/obj/item/bodypart/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	ADD_TRAIT(chest, TRAIT_READY_TO_OPERATE, TRAIT_GENERIC)
	chest.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_ORGANS_CUT|SURGERY_BONE_SAWED)
	patient.set_body_position(LYING_DOWN)
	var/obj/item/scalpel/tool = allocate(/obj/item/scalpel)
	surgeon.put_in_active_hand(tool)
	var/datum/surgery_operation/organ/repair/hepatectomy/operation = allocate(/datum/surgery_operation/organ/repair/hepatectomy)
	operation.time = 0
	liver.set_organ_damage(liver.maxHealth * 0.8)
	var/result = operation.try_perform(liver, surgeon, tool, list(OPERATION_TARGET_ZONE = BODY_ZONE_CHEST, OPERATION_FORCE_FAIL = TRUE))
	var/list/record = controller.store.read("qualitysurgeon")
	if(!(result & ITEM_INTERACT_FAILURE) || record["karma"])
		Fail("An actual failed operation must not earn surgical Karma.")
	result = operation.try_perform(liver, surgeon, tool, list(OPERATION_TARGET_ZONE = BODY_ZONE_CHEST))
	record = controller.store.read("qualitysurgeon")
	if(!(result & ITEM_INTERACT_SUCCESS) || abs(record["karma"] - CONFIG_GET(number/karma_help_reward)) > 0.001)
		Fail("A real completed restorative surgery must reward its connected surgeon after its effects.")
	var/list/healthy = quality_surgery_snapshot(operation, patient, liver)
	if(controller.record_surgery(surgeon, patient, operation, healthy, liver))
		Fail("A successful no-op on an already repaired organ must not reward Karma.")
	var/datum/surgery_operation/limb/amputate/amputation = allocate(/datum/surgery_operation/limb/amputate)
	if(quality_surgery_snapshot(amputation, patient, chest))
		Fail("A notable harmful operation must not qualify as restorative surgery.")
	patient.quality_harm_history = list("qualitysurgeon" = world.time)
	if(controller.record_surgery(surgeon, patient, operation, list("organ_damage" = liver.maxHealth), liver))
		Fail("A surgeon must not farm surgical rewards from damage they caused.")
	var/datum/quality_karma_session/session = controller.karma_session("qualitysurgeon")
	session.help_awards = 10
	if(controller.record_surgery_account("qualitysurgeon", "unrelatedpatient"))
		Fail("Surgery and medical packs must share the ten-reward round ceiling.")
	sleep(2)
	qdel(controller.store)
	controller.store = old_store
	controller.karma_sessions = old_sessions
	controller.round_ended = old_ended
	fdel(path)
	fdel("[path].savebac")
#endif
