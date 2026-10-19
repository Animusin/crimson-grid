/datum/config_entry/number/karma_player_kill_penalty
	default = 1
	min_val = 0

/datum/config_entry/number/karma_roleplay_reward
	default = 0.1
	min_val = 0

/datum/config_entry/number/karma_help_reward
	default = 0.1
	min_val = 0

/datum/config_entry/number/karma_defense_reward
	default = 1
	min_val = 0

/// All limits follow the account, including death, reconnects and body transfers.
/datum/quality_karma_session
	var/list/seen_text = list()
	var/roleplay_characters = 0
	var/roleplay_awards = 0
	var/next_roleplay_award = 0
	var/list/helped_patients = list()
	var/list/healing_progress = list()
	var/help_awards = 0
	var/list/defended_points = list()
	var/list/defended_opponents = list()
	var/defense_awards = 0

/datum/quality_death_event
	var/victim_account
	var/attacker_account
	var/attacker_token
	var/attack_time
	var/death_time
	var/event_token
	var/suicide = FALSE
	var/objective_exempt = FALSE
	var/list/objective_exempt_accounts
	var/settled = FALSE

/datum/quality_death_event/Destroy()
	for(var/account in objective_exempt_accounts)
		var/list/authorizations = objective_exempt_accounts[account]
		QDEL_LIST(authorizations)
	objective_exempt_accounts = null
	return ..()

/mob/living
	var/quality_last_attacker
	var/quality_last_attacker_token
	var/quality_last_attack_time = -INFINITY
	var/datum/weakref/quality_summoner_mind
	var/quality_summoner_account
	var/list/quality_harm_history
	var/quality_self_harm_time = -INFINITY
	var/quality_last_death_time = -INFINITY
	var/quality_death_number = 0
	var/datum/quality_death_event/quality_pending_death

/datum/controller/subsystem/player_quality/proc/register_karma_signals()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_player_death))
	// String contract keeps the business and progression PRs independently buildable.
	RegisterSignal(SSdcs, "city_business_defended", PROC_REF(on_business_defended))

/datum/controller/subsystem/player_quality/proc/karma_session(account)
	account = ckey(account)
	if(!account)
		return null
	var/datum/quality_karma_session/session = karma_sessions[account]
	if(!session)
		session = new
		karma_sessions[account] = session
	return session

/// A disconnected player's character still counts; NPCs without a player mind do not.
/proc/quality_player_account(mob/living/body)
	return istype(body) ? ckey(body.mind?.key) : null

/// Summoning ownership is explicit, rather than inferred from factions/friends.
/mob/living/proc/quality_set_summon_owner(mob/living/summoner)
	quality_summoner_mind = summoner?.mind ? WEAKREF(summoner.mind) : null
	quality_summoner_account = quality_player_account(summoner)

/mob/living/proc/quality_responsible_mind()
	if(quality_summoner_account)
		return quality_summoner_mind?.resolve()
	return mind

/mob/living/proc/quality_responsible_account()
	return quality_summoner_account || ckey(quality_responsible_mind()?.key)

/datum/controller/subsystem/player_quality/proc/karma_is_active()
	return store && !round_ended && SSticker.IsRoundInProgress()

/// Called only after actual non-stamina damage from a known actor has been applied.
/datum/controller/subsystem/player_quality/proc/record_harm(mob/living/victim, mob/living/attacker, amount, damage_type)
	if(!karma_is_active() || !isnum(amount) || amount <= 0 || damage_type == STAMINA)
		return FALSE
	var/datum/quality_death_event/pending = victim.quality_pending_death
	var/victim_account = quality_player_account(victim)
	if(!victim_account && pending && pending.death_time == world.time)
		victim_account = pending.victim_account
	var/attacker_account = attacker?.quality_responsible_account()
	if(!victim_account || !attacker_account)
		return FALSE
	if(victim == attacker || victim_account == attacker_account)
		victim.quality_self_harm_time = world.time
		victim.quality_last_attacker = null
		victim.quality_last_attacker_token = null
		victim.quality_last_attack_time = -INFINITY
		if(victim.quality_pending_death && !victim.quality_pending_death.settled && victim.quality_pending_death.death_time == world.time)
			victim.quality_pending_death.attacker_account = null
			victim.quality_pending_death.attacker_token = null
		return FALSE
	RegisterSignal(victim, COMSIG_LIVING_REVIVE, PROC_REF(on_player_revived), override = TRUE)
	LAZYSET(victim.quality_harm_history, attacker_account, world.time)
	victim.quality_last_attacker = attacker_account
	victim.quality_last_attacker_token = REF(attacker)
	victim.quality_last_attack_time = world.time
	// apply_damage() may kill synchronously before it returns its real damage.
	// The death report is settled next tick, allowing that lethal hit to be attributed.
	if(pending && !pending.settled && pending.death_time == world.time)
		pending.attacker_account = attacker_account
		pending.attacker_token = REF(attacker)
		pending.attack_time = world.time
	return TRUE

/datum/controller/subsystem/player_quality/proc/on_player_revived(mob/living/victim)
	SIGNAL_HANDLER
	victim.quality_last_attacker = null
	victim.quality_last_attacker_token = null
	victim.quality_last_attack_time = -INFINITY
	victim.quality_last_death_time = -INFINITY
	// Keep the captured death event alive: reviving does not undo a real kill.
	victim.quality_pending_death = null

/// Explicit executions do not apply damage. Call immediately before the branch
/// that kills a living character, never for examining or processing a corpse.
/// Recording the actor is separate from settlement: only a real DEATH pays out.
/datum/controller/subsystem/player_quality/proc/record_execution(mob/living/victim, mob/living/executioner)
	if(!karma_is_active() || !istype(victim) || victim.stat == DEAD)
		return FALSE
	var/victim_account = quality_player_account(victim)
	var/executioner_account = executioner?.quality_responsible_account()
	if(!victim_account || !executioner_account)
		return FALSE
	RegisterSignal(victim, COMSIG_LIVING_REVIVE, PROC_REF(on_player_revived), override = TRUE)
	// Self-execution must not inherit an opponent's earlier hit.
	if(victim == executioner || victim_account == executioner_account)
		victim.quality_last_attacker = null
		victim.quality_last_attacker_token = null
		victim.quality_last_attack_time = -INFINITY
		return TRUE
	LAZYSET(victim.quality_harm_history, executioner_account, world.time)
	victim.quality_last_attacker = executioner_account
	victim.quality_last_attacker_token = REF(executioner)
	victim.quality_last_attack_time = world.time
	return TRUE

/// Items carry a direct source for melee and projectiles. Thrown attacks pass their
/// original thrower explicitly at the impact call; a floor item is not its owner.
/datum/controller/subsystem/player_quality/proc/record_item_harm(mob/living/victim, obj/item/weapon, amount, damage_type)
	var/mob/living/attacker
	if(istype(weapon, /obj/projectile))
		var/obj/projectile/projectile = weapon
		attacker = projectile.firer
	else if(ismob(weapon?.loc))
		attacker = weapon.loc
	if(isliving(attacker))
		return record_harm(victim, attacker, amount, damage_type)
	return FALSE

/// Preserve direct adjust_*_loss semantics (no new armor or wound modifiers)
/// while giving offensive powers a real, explicit damage source.
/mob/living/proc/adjust_attributed_damage(amount, damage_type, mob/living/attacker)
	var/was_alive = stat != DEAD
	switch(damage_type)
		if(BRUTE)
			. = -adjust_brute_loss(amount)
		if(BURN)
			. = -adjust_fire_loss(amount)
		if(TOX)
			. = -adjust_tox_loss(amount)
		if(OXY)
			. = -adjust_oxy_loss(amount)
		if(AGGRAVATED)
			. = -adjust_agg_loss(amount)
	if(was_alive)
		SSplayer_quality?.record_harm(src, attacker, ., damage_type)
	return .

/datum/controller/subsystem/player_quality/proc/on_player_death(datum/source, mob/living/victim, gibbed)
	SIGNAL_HANDLER
	if(!karma_is_active() || !quality_player_account(victim) || victim.quality_last_death_time == world.time)
		return
	victim.quality_last_death_time = world.time
	var/datum/quality_death_event/event = new
	event.victim_account = quality_player_account(victim)
	event.attacker_account = victim.quality_last_attacker
	event.attacker_token = victim.quality_last_attacker_token
	event.attack_time = victim.quality_last_attack_time
	event.death_time = world.time
	event.event_token = "kill:[REF(victim)]:[++victim.quality_death_number]:[world.time]"
	event.suicide = HAS_TRAIT(victim, TRAIT_SUICIDED)
	event.objective_exempt_accounts = quality_objective_killers(victim)
	victim.quality_pending_death = event
	// Retain account data rather than the dying mob: gibbing/deletion is safe.
	addtimer(CALLBACK(src, PROC_REF(settle_death), event), 1)

/datum/controller/subsystem/player_quality/proc/settle_death(datum/quality_death_event/event)
	if(!event || event.settled)
		return FALSE
	event.settled = TRUE
	var/awarded = FALSE
	if(store && !event.suicide && event.attacker_account && event.attacker_account != event.victim_account && event.death_time - event.attack_time <= 2 MINUTES)
		for(var/datum/quality_kill_authorization/authorization as anything in event.objective_exempt_accounts?[event.attacker_account])
			if(authorization.claim(event.attacker_token))
				event.objective_exempt = TRUE
		if(!event.objective_exempt)
			awarded = store.award_karma(event.attacker_account, -CONFIG_GET(number/karma_player_kill_penalty), event.event_token, round_token)
	qdel(event)
	return awarded

/// The old build accumulated say-log characters. Here distinct text must be
/// shared locally with another active player, and rewards have a strict ceiling.
/datum/controller/subsystem/player_quality/proc/record_roleplay(mob/living/speaker, message, message_range = 7)
	if(!karma_is_active() || !speaker.client || speaker.stat >= SOFT_CRIT || IS_UNCONSCIOUS(speaker) || speaker.client.is_afk())
		return FALSE
	var/account = quality_player_account(speaker)
	if(!account || speaker.ckey != account)
		return FALSE
	var/witnessed = FALSE
	for(var/mob/living/listener in view(min(7, message_range), speaker))
		if(listener != speaker && listener.client && listener.stat < SOFT_CRIT && !IS_UNCONSCIOUS(listener) && !listener.client.is_afk() && quality_player_account(listener) && listener.ckey != account)
			witnessed = TRUE
			break
	if(!witnessed)
		return FALSE
	return record_roleplay_text(account, message)

/// Separate deterministic accounting from the live player/witness checks above.
/datum/controller/subsystem/player_quality/proc/record_roleplay_text(account, message)
	var/datum/quality_karma_session/session = karma_session(account)
	if(!session || session.roleplay_awards >= 10 || !istext(message))
		return FALSE
	var/normalized = LOWER_TEXT(trim(html_decode(strip_html(message))))
	if(length_char(normalized) < 20 || length(session.seen_text) >= 1000)
		return FALSE
	var/fingerprint = md5(normalized)
	if(session.seen_text[fingerprint])
		return FALSE
	session.seen_text[fingerprint] = TRUE
	session.roleplay_characters += min(300, length_char(normalized))
	if(session.roleplay_characters < 1500 || world.time < session.next_roleplay_award)
		return FALSE
	// No banked backlog: past text cannot buy later rewards with a token message.
	session.roleplay_characters = 0
	session.next_roleplay_award = world.time + 5 MINUTES
	session.roleplay_awards++
	return store.award_karma(account, CONFIG_GET(number/karma_roleplay_reward), "roleplay:[session.roleplay_awards]", round_token)

/// Medical packs report real restored limb damage, not use count or nominal power.
/// Self-treatment, dead/NPC patients and harm by the healer cannot generate Karma.
/datum/controller/subsystem/player_quality/proc/record_help(mob/living/healer, mob/living/patient, amount)
	var/client/healing_client = GET_CLIENT(healer)
	var/client/patient_client = GET_CLIENT(patient)
	if(!karma_is_active() || !healing_client || healing_client.is_afk() || !patient_client || healer.stat >= SOFT_CRIT || IS_UNCONSCIOUS(healer) || patient.stat == DEAD || !isnum(amount) || amount <= 0)
		return FALSE
	var/account = quality_player_account(healer)
	var/patient_account = quality_player_account(patient)
	if(!account || !patient_account || account == patient_account || patient.quality_harm_history?[account] || world.time - patient.quality_self_harm_time <= 10 MINUTES)
		return FALSE
	return record_help_amount(account, patient_account, amount)

/datum/controller/subsystem/player_quality/proc/record_help_amount(account, patient_account, amount)
	account = ckey(account)
	patient_account = ckey(patient_account)
	var/datum/quality_karma_session/session = karma_session(account)
	if(!session || !patient_account || account == patient_account || amount <= 0 || session.help_awards >= 10 || session.helped_patients[patient_account])
		return FALSE
	session.healing_progress[patient_account] = (session.healing_progress[patient_account] || 0) + amount
	if(session.healing_progress[patient_account] < 20)
		return FALSE
	session.helped_patients[patient_account] = TRUE
	session.help_awards++
	return store.award_karma(account, CONFIG_GET(number/karma_help_reward), "help:[patient_account]", round_token)

/// A completed notable operation, after its successful effects have executed.
/// Incisions, failed attempts and other preparatory steps do not count.
/datum/controller/subsystem/player_quality/proc/record_surgery(mob/living/surgeon, mob/living/patient, datum/surgery_operation/operation, list/before, atom/movable/operating_on)
	if(!operation || !(operation.operation_flags & OPERATION_NOTABLE) || !islist(before))
		return FALSE
	var/list/after = quality_surgery_snapshot(operation, patient, operating_on)
	var/improved = FALSE
	for(var/condition in before)
		if(islist(after) && isnum(after[condition]) && after[condition] < before[condition])
			improved = TRUE
	if(!improved)
		return FALSE
	var/client/surgeon_client = GET_CLIENT(surgeon)
	var/client/patient_client = GET_CLIENT(patient)
	var/account = quality_player_account(surgeon)
	var/patient_account = quality_player_account(patient)
	if(!karma_is_active() || !account || !patient_account || !surgeon_client || surgeon_client.ckey != account || surgeon_client.is_afk() || !patient_client || patient_client.ckey != patient_account || surgeon.stat >= SOFT_CRIT || IS_UNCONSCIOUS(surgeon) || patient.stat == DEAD || account == patient_account || patient.quality_harm_history?[account] || world.time - patient.quality_self_harm_time <= 10 MINUTES)
		return FALSE
	return record_surgery_account(account, patient_account)

/datum/controller/subsystem/player_quality/proc/record_surgery_account(account, patient_account)
	account = ckey(account)
	patient_account = ckey(patient_account)
	var/datum/quality_karma_session/session = karma_session(account)
	if(!session || !patient_account || account == patient_account || session.help_awards >= 10)
		return FALSE
	if(!store.award_surgery(account, patient_account, CONFIG_GET(number/karma_help_reward), round_token))
		return FALSE
	session.help_awards++
	return TRUE

/// One synchronous write keeps the reward, cooldown and repeat ledger atomic.
/// Extra fields survive the existing store's normal read/migration path.
/datum/player_quality_store/proc/award_surgery(account, patient_account, base_reward, round_token, current_time = world.realtime)
	account = ckey(account)
	patient_account = ckey(patient_account)
	if(!account || !patient_account || account == patient_account || !isnum(base_reward) || base_reward <= 0 || !round_token)
		return FALSE
	var/list/record = read(account)
	var/list/patients = record["surgery_patients"]
	if(!islist(patients))
		patients = list()
	var/list/pair = patients[patient_account]
	if(!islist(pair))
		pair = list("awards" = 0, "next_award" = 0)
	var/next_award = pair["next_award"]
	if(istext(next_award))
		next_award = text2num(next_award)
	if(!isnum(next_award))
		next_award = 0
	if(current_time < next_award)
		return FALSE
	var/prior_awards = isnum(pair["awards"]) ? max(0, pair["awards"]) : 0
	var/reward = round(base_reward / (prior_awards + 1), 0.01)
	if(reward <= 0)
		return FALSE
	if(record["karma_round"] != round_token)
		record["karma_round"] = round_token
		record["karma_events"] = list()
	var/list/events = record["karma_events"]
	var/event_token = "surgery:[patient_account]:[prior_awards + 1]"
	if(events[event_token])
		return FALSE
	events[event_token] = TRUE
	record["karma"] = round(record["karma"] + reward, 0.01)
	pair["awards"] = prior_awards + 1
	// JSON numbers retain too few significant digits for world.realtime.
	// Text preserves the existing clock's exact deadline across disk reloads.
	pair["next_award"] = num2text(current_time + 1 HOURS, 20)
	patients[patient_account] = pair
	record["surgery_patients"] = patients
	database.set_key(account, record)
	log_game("Karma: [account] +[reward] for [event_token] (round [round_token]).")
	return TRUE

/// Only restorative operations expose measurable medical improvement here.
/// This intentionally excludes organ removal, amputations, hostile/cosmetic work.
/proc/quality_surgery_snapshot(datum/surgery_operation/operation, mob/living/patient, atom/movable/operating_on)
	if(QDELETED(patient))
		return null
	if(istype(operation, /datum/surgery_operation/basic/revival))
		return list("dead" = patient.stat == DEAD)
	if(istype(operation, /datum/surgery_operation/limb/prosthetic_replacement) || istype(operation, /datum/surgery_operation/limb/replace_limb))
		if(!iscarbon(patient))
			return null
		var/mob/living/carbon/carbon = patient
		var/intact = 0
		var/damage = 0
		for(var/obj/item/bodypart/limb as anything in carbon.bodyparts)
			if(!IS_STUMP(limb))
				intact++
			damage += limb.get_damage()
		return list("missing_limbs" = -intact, "limb_damage" = damage)
	if(QDELETED(operating_on))
		return null
	if(istype(operation, /datum/surgery_operation/organ/repair) && isorgan(operating_on))
		var/obj/item/organ/organ = operating_on
		var/traumas = 0
		if(istype(organ, /obj/item/organ/brain))
			var/obj/item/organ/brain/brain = organ
			traumas = length(brain.traumas)
		return list("organ_damage" = organ.damage, "traumas" = traumas,
			"blind" = !!patient.is_blind(), "deaf" = HAS_TRAIT(patient, TRAIT_DEAF))
	if(istype(operation, /datum/surgery_operation/organ/fix_wings) && istype(operating_on, /obj/item/organ/wings/moth))
		var/obj/item/organ/wings/moth/wings = operating_on
		return list("burnt" = wings.burnt)
	if(istype(operation, /datum/surgery_operation/organ/stomach_pump))
		var/toxins = 0
		for(var/datum/reagent/toxin/toxin in patient.reagents?.reagent_list)
			toxins += toxin.volume
		return list("toxins" = toxins)
	return null

/datum/controller/subsystem/player_quality/proc/on_business_defended(datum/source, mob/living/defender, territory_id, attack_token, attacking_faction)
	SIGNAL_HANDLER
	var/account = quality_player_account(defender)
	var/client/defending_client = GET_CLIENT(defender)
	if(!karma_is_active() || !account || !defending_client || defending_client.ckey != account || defender.stat >= SOFT_CRIT || IS_UNCONSCIOUS(defender) || defending_client.is_afk())
		return
	record_defense(account, territory_id, attack_token, attacking_faction)

/datum/controller/subsystem/player_quality/proc/record_defense(account, territory_id, attack_token, attacking_faction)
	var/datum/quality_karma_session/session = karma_session(account)
	if(!session || !istext(territory_id) || !length(territory_id) || !attack_token || !istext(attacking_faction) || !length(attacking_faction) || session.defense_awards >= 2 || session.defended_points[territory_id] || session.defended_opponents[attacking_faction])
		return FALSE
	session.defended_points[territory_id] = TRUE
	session.defended_opponents[attacking_faction] = TRUE
	session.defense_awards++
	return store.award_karma(account, CONFIG_GET(number/karma_defense_reward), "defense:[territory_id]:[attack_token]", round_token)
