/// Snapshot authorized accounts before death handlers can delete/retarget a victim.
/proc/quality_objective_killers(mob/living/victim)
	. = list()
	var/list/checked = list()
	for(var/datum/antagonist/antag as anything in GLOB.antagonists)
		var/datum/mind/actor = antag.owner
		if(!actor || checked[REF(actor)])
			continue
		checked[REF(actor)] = TRUE
		var/mob/living/source_actor = actor.current
		var/account = source_actor?.quality_responsible_account() || ckey(actor.key)
		if(!account)
			continue
		var/list/matches = quality_objective_matches(actor, victim.mind, victim)
		for(var/datum/objective/objective as anything in matches)
			var/datum/quality_kill_authorization/authorization = new
			authorization.quota = objective.quality_kill_quota()
			authorization.limit = authorization.quota?.limit
			// A bound minion's own orders authorize that minion's actions only.
			// They do not grant its owner or sibling summons a blanket waiver.
			if(source_actor?.quality_summoner_account)
				authorization.actor_token = REF(source_actor)
			if(!islist(.[account]))
				.[account] = list()
			var/list/authorizations = .[account]
			authorizations += authorization

/proc/quality_objective_kill(datum/mind/actor, datum/mind/victim, mob/living/body)
	return !!length(quality_objective_matches(actor, victim, body))

/proc/quality_objective_matches(datum/mind/actor, datum/mind/victim, mob/living/body)
	. = list()
	if(!actor || !victim || actor == victim)
		return .
	var/list/objectives = actor.get_all_objectives()
	for(var/datum/antagonist/antag as anything in actor.antag_datums)
		var/datum/team/team = antag.get_team()
		if(team && (actor in team.members))
			objectives |= team.objectives
	for(var/datum/objective/objective as anything in objectives)
		if(objective.quality_murder_target(actor, victim, body))
			. |= objective

/// A quota snapshot survives its objective being deleted after the victim dies.
/// Settlement is synchronous, so simultaneous deaths cannot exceed the limit.
/datum/quality_kill_quota
	var/claimed = 0
	var/limit = 0

/datum/quality_kill_authorization
	var/datum/quality_kill_quota/quota
	var/limit
	var/actor_token

/datum/quality_kill_authorization/proc/claim(source_token)
	if(actor_token && source_token != actor_token)
		return FALSE
	if(!quota)
		return TRUE
	if(quota.claimed >= limit)
		return FALSE
	quota.claimed++
	return TRUE

/datum/objective
	var/datum/quality_kill_quota/quality_quota

/datum/objective/proc/quality_kill_quota()
	return null

/// A target or an antagonist flag alone never authorizes murder.
/datum/objective/proc/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return FALSE

/datum/objective/assassinate/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	// The laughter demon reuses this class for a nonlethal hug objective.
	return target && target == victim && !actor.has_antag_datum(/datum/antagonist/slaughter/laughter)

/datum/objective/mutiny/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target && target == victim

/datum/objective/maroon/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target && target == victim

/datum/objective/debrain/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target && target == victim

/datum/objective/destroy/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target && target == victim

/datum/objective/sacrifice/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target && target == victim

/datum/objective/accept_no_substitutes/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return target_name && body.real_name == target_name

/datum/objective/minor_sacrifice/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	var/datum/antagonist/heretic/heretic = actor.has_antag_datum(/datum/antagonist/heretic)
	return !completed && heretic && heretic.total_sacrifices < target_amount && (body in heretic.sac_targets)

/datum/objective/minor_sacrifice/quality_kill_quota()
	var/datum/antagonist/heretic/heretic = owner?.has_antag_datum(/datum/antagonist/heretic)
	if(!quality_quota)
		quality_quota = new
	quality_quota.limit = target_amount
	quality_quota.claimed = max(quality_quota.claimed, heretic?.total_sacrifices || 0)
	return quality_quota

/datum/objective/major_sacrifice/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	var/datum/antagonist/heretic/heretic = actor.has_antag_datum(/datum/antagonist/heretic)
	return !completed && heretic && heretic.high_value_sacrifices < target_amount && (body in heretic.sac_targets) && (victim.assigned_role?.departments_bitflags & DEPARTMENT_BITFLAG_COMMAND)

/datum/objective/major_sacrifice/quality_kill_quota()
	var/datum/antagonist/heretic/heretic = owner?.has_antag_datum(/datum/antagonist/heretic)
	if(!quality_quota)
		quality_quota = new
	quality_quota.limit = target_amount
	quality_quota.claimed = max(quality_quota.claimed, heretic?.high_value_sacrifices || 0)
	return quality_quota

/datum/objective/blood_worm/kill/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return !!(victim.assigned_role?.departments_bitflags & DEPARTMENT_BITFLAG_COMMAND)

/datum/objective/destroy_nation/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	var/datum/antagonist/separatist/enemy = victim.has_antag_datum(/datum/antagonist/separatist)
	return target_team && enemy?.nation?.department == target_team.department

/// Match the same people who actually obstruct this objective's shuttle check.
/datum/objective/elimination/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	if(!SSshuttle.emergency?.shuttle_areas[get_area(body)] || issilicon(body) || isanimal_or_basicmob(body) || isbrain(body) || istype(get_area(body), /area/shuttle/escape/brig))
		return FALSE
	if(!length(victim.antag_datums))
		return TRUE
	var/prevents = FALSE
	for(var/datum/antagonist/antag as anything in victim.antag_datums)
		if(antag.can_elimination_hijack == ELIMINATION_ENABLED)
			return FALSE
		if(antag.can_elimination_hijack == ELIMINATION_PREVENT)
			prevents = TRUE
	return prevents

/datum/objective/elimination/highlander/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return !isbrain(body) && SSshuttle.emergency?.shuttle_areas[get_area(body)]

/datum/objective/block/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return (body.mob_biotypes & MOB_ORGANIC) && SSshuttle.emergency?.shuttle_areas[get_area(body)]

/datum/objective/purge/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	if(!ishuman(body) || !SSshuttle.emergency?.shuttle_areas[get_area(body)])
		return FALSE
	var/mob/living/carbon/human/human = body
	return human.dna.species.id != SPECIES_HUMAN

/// Known server-authored mass-kill goals get explicit types, never text parsing.
/datum/objective/slaughter_everyone
	no_failure = TRUE

/datum/objective/slaughter_everyone/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return actor.has_antag_datum(/datum/antagonist/slaughter) && !actor.has_antag_datum(/datum/antagonist/slaughter/laughter)

/datum/objective/heretic_crew_cull

/datum/objective/heretic_crew_cull/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	return ishuman(body) && is_station_level(body.z) && victim.assigned_role && !IS_HERETIC_OR_MONSTER(body)

/datum/objective/heretic_arena_escape

/datum/objective/heretic_arena_escape/quality_murder_target(datum/mind/actor, datum/mind/victim, mob/living/body)
	for(var/obj/effect/abstract/heretic_arena/field as anything in GLOB.heretic_arenas)
		if((actor.current in field.arena.contained_mobs) && (body in field.arena.contained_mobs))
			return TRUE
	return FALSE
