// Account progression: the component scores remain independently auditable.
/datum/config_entry/flag/player_quality_enabled
	default = TRUE

/datum/config_entry/number/rcp_human_reward
	default = 1
	min_val = 0

/datum/config_entry/number/rcp_ghoul_reward
	default = 0.5
	min_val = 0

/datum/config_entry/number/rcp_kinfolk_reward
	default = 0.5
	min_val = 0

/datum/config_entry/number/rcp_minimum_minutes
	default = 45
	min_val = 1

/// Ratwood-2.0's post-rework commendation bands and automatic PQ ceiling.
/datum/config_entry/number/pq_commend_softcap
	default = 100
	min_val = 0

/datum/config_entry/number/pq_commend_cap
	default = 500
	min_val = 0

/// Account-level data only; never keyed by a character's mutable name or slot.
/datum/player_quality_store
	var/datum/json_database/database

/datum/player_quality_store/New(path = "data/player_quality.json")
	database = new(path)

/datum/player_quality_store/Destroy()
	QDEL_NULL(database)
	return ..()

/datum/player_quality_store/proc/read(account)
	account = ckey(account)
	if(!account)
		return null
	var/list/record = database.get_key(account)
	record = islist(record) ? deep_copy_list(record) : list()
	// Preserve previous scores and giver counts; new praise uses the donor policy.
	record["version"] = 3
	for(var/metric in list("pq", "rcp", "karma"))
		if(!isnum(record[metric]))
			record[metric] = 0
	if(!islist(record["commends"]))
		record["commends"] = list()
	return record

/// Linear account score. All three components retain their positive/negative sign.
/proc/calculate_respect(pq, rcp, karma)
	return pq + rcp / 4 + karma

/datum/player_quality_store/proc/respect(account)
	var/list/record = read(account)
	return record ? calculate_respect(record["pq"], record["rcp"], record["karma"]) : 0

/// The current-round ledger survives reloads but cannot grow across every round.
/datum/player_quality_store/proc/award_karma(account, amount, event_token, round_token)
	account = ckey(account)
	if(!account || !isnum(amount) || !amount || !event_token || !round_token)
		return FALSE
	var/list/record = read(account)
	if(record["karma_round"] != round_token)
		record["karma_round"] = round_token
		record["karma_events"] = list()
	var/list/events = record["karma_events"]
	if(events[event_token])
		return FALSE
	events[event_token] = TRUE
	record["karma"] = round(record["karma"] + amount, 0.01)
	database.set_key(account, record)
	log_game("Karma: [account] [amount > 0 ? "+" : ""][amount] for [event_token] (round [round_token]).")
	return TRUE

/// Ratwood-2.0 add_commend(): below 100 PQ only a new giver awards +1.
/// At/above 100 a new giver awards +0.5, a repeat giver +0.05. Counts persist.
/datum/player_quality_store/proc/commend(recipient, giver)
	recipient = ckey(recipient)
	giver = ckey(giver)
	if(!recipient || !giver || recipient == giver)
		return FALSE
	var/list/record = read(recipient)
	var/list/commends = record["commends"]
	var/previous = commends[giver] || 0
	commends[giver] = previous + 1
	var/reward = record["pq"] >= CONFIG_GET(number/pq_commend_softcap) ? (previous ? 0.05 : 0.5) : (previous ? 0 : 1)
	// The ceiling applies to automatic praise. Administrative reductions/overrides
	// remain independent and never reset the ledger or clamp existing saved PQ.
	if(reward && record["pq"] < CONFIG_GET(number/pq_commend_cap))
		record["pq"] = round(min(record["pq"] + reward, CONFIG_GET(number/pq_commend_cap)), 0.01)
	database.set_key(recipient, record)
	return TRUE

/// A synchronous checked debit, with an optional persistent retry token.
/// Exact retries succeed without charging again; mismatched/failed requests do
/// not change the record. Unlock state and payment must use one separate write.
/datum/player_quality_store/proc/spend_karma(account, amount, reason, actor, transaction_token = null)
	account = ckey(account)
	actor = ckey(actor)
	if(!account || !actor || !isnum(amount) || amount < 0.01 || amount != round(amount, 0.01) || !istext(reason) || !length(trim(reason)))
		return FALSE
	if(!isnull(transaction_token) && (!istext(transaction_token) || !length(transaction_token)))
		return FALSE
	var/list/record = read(account)
	var/list/transactions = record["karma_transactions"]
	if(transaction_token && islist(transactions))
		var/list/previous = transactions[transaction_token]
		if(islist(previous))
			return previous["amount"] == amount && previous["reason"] == reason && previous["actor"] == actor
	if(record["karma"] < amount)
		return FALSE
	record["karma"] = round(record["karma"] - amount, 0.01)
	if(transaction_token)
		if(!islist(transactions))
			transactions = list()
			record["karma_transactions"] = transactions
		transactions[transaction_token] = list("amount" = amount, "reason" = reason, "actor" = actor)
	database.set_key(account, record)
	log_game("Karma debit: [account] -[amount], actor [actor], reason [reason], transaction [transaction_token || "none"].")
	return TRUE

/datum/player_quality_store/proc/award_rcp(account, amount, round_token)
	if(!ckey(account) || !isnum(amount) || amount <= 0 || !round_token)
		return FALSE
	var/list/record = read(account)
	if(record["last_rcp_round"] == round_token)
		return FALSE
	record["rcp"] += amount
	record["last_rcp_round"] = round_token
	database.set_key(ckey(account), record)
	return TRUE

/datum/player_quality_store/proc/admin_adjust(account, amount, administrator, reason, metric = "pq")
	if(!ckey(account) || !isnum(amount) || !administrator || !length(reason) || !(metric in list("pq", "rcp", "karma")))
		return FALSE
	var/list/record = read(account)
	record[metric] += amount
	database.set_key(ckey(account), record)
	log_admin("[administrator] adjusted [ckey(account)] [metric] by [amount]: [reason]")
	message_admins("[administrator] adjusted [ckey(account)] [metric] by [amount]: [html_encode(reason)]")
	return TRUE

/datum/quality_participant
	var/character_name
	var/active_time = 0
	var/list/role_time = list()

SUBSYSTEM_DEF(player_quality)
	name = "Player Quality"
	wait = 10 SECONDS
	runlevels = RUNLEVEL_GAME
	var/datum/player_quality_store/store
	var/list/participants = list()
	var/list/voters = list()
	var/round_ended = FALSE
	var/round_token
	var/last_sample = 0
	/// Contribution and pair limits are account-scoped, surviving bodies and reconnects.
	var/list/karma_sessions = list()

/datum/controller/subsystem/player_quality/Initialize()
	if(!CONFIG_GET(flag/player_quality_enabled))
		return SS_INIT_NO_NEED
	store = new
	round_token = "[world.realtime]-[rand(1, 1000000)]"
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(round_starting))
	RegisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED, PROC_REF(round_finished))
	register_karma_signals()
	RegisterSignal(SSdcs, "city_antagonist_admission", PROC_REF(on_antagonist_admission))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/player_quality/Recover()
	ss_flags |= SS_NO_INIT
	initialized = SSplayer_quality.initialized
	store = SSplayer_quality.store
	SSplayer_quality.store = null
	participants = SSplayer_quality.participants
	voters = SSplayer_quality.voters
	round_ended = SSplayer_quality.round_ended
	round_token = SSplayer_quality.round_token
	last_sample = SSplayer_quality.last_sample
	karma_sessions = SSplayer_quality.karma_sessions
	if(store)
		RegisterSignal(SSticker, COMSIG_TICKER_ROUND_STARTING, PROC_REF(round_starting))
		RegisterSignal(SSticker, COMSIG_TICKER_ROUND_ENDED, PROC_REF(round_finished))
		register_karma_signals()
		RegisterSignal(SSdcs, "city_antagonist_admission", PROC_REF(on_antagonist_admission))

/datum/controller/subsystem/player_quality/Destroy()
	QDEL_NULL(store)
	return ..()

/datum/controller/subsystem/player_quality/proc/round_starting()
	SIGNAL_HANDLER
	last_sample = world.time

/datum/controller/subsystem/player_quality/fire(resumed)
	if(!store || round_ended || !SSticker.IsRoundInProgress())
		return
	sample_players()

/// Record connected, living, non-AFK play; ghosts and lobby time cannot earn RCP.
/// Each interval keeps its splat, so a late transformation cannot claim an entire
/// vampire round at the human rate. Dead/disconnected players retain earned time.
/datum/controller/subsystem/player_quality/proc/sample_players()
	var/elapsed = last_sample ? clamp(world.time - last_sample, 0, wait) : 0
	last_sample = world.time
	for(var/client/player as anything in GLOB.clients)
		var/mob/living/carbon/human/body = player.mob
		if(!istype(body) || !body.mind?.assigned_role || !body.ckey)
			continue
		var/datum/quality_participant/participant = participants[player.ckey]
		if(!participant)
			participant = new
			participants[player.ckey] = participant
		participant.character_name = body.real_name
		if(body.stat == DEAD || player.is_afk())
			continue
		var/bucket = participation_bucket(body)
		participant.active_time += elapsed
		participant.role_time[bucket] = (participant.role_time[bucket] || 0) + elapsed

/datum/controller/subsystem/player_quality/proc/participation_bucket(mob/living/carbon/human/body)
	if(body.get_splat(/datum/splat/vampire/kindred) || body.get_splat(/datum/splat/werewolf/shifter))
		return "supernatural"
	if(body.get_splat(/datum/splat/vampire/ghoul))
		return "ghoul"
	if(body.get_splat(/datum/splat/werewolf/kinfolk))
		return "kinfolk"
	if(length(body.splats))
		return "supernatural"
	return "human"

/// One configurable grant per completed round, weighted by actual played time.
/datum/controller/subsystem/player_quality/proc/participation_reward(datum/quality_participant/participant)
	if(participant.active_time < CONFIG_GET(number/rcp_minimum_minutes) MINUTES)
		return 0
	var/weighted = (participant.role_time["human"] || 0) * CONFIG_GET(number/rcp_human_reward)
	weighted += (participant.role_time["ghoul"] || 0) * CONFIG_GET(number/rcp_ghoul_reward)
	weighted += (participant.role_time["kinfolk"] || 0) * CONFIG_GET(number/rcp_kinfolk_reward)
	return round(weighted / participant.active_time, 0.01)

/datum/controller/subsystem/player_quality/proc/round_finished()
	SIGNAL_HANDLER
	if(!store || round_ended)
		return
	sample_players()
	round_ended = TRUE
	for(var/account in participants)
		var/datum/quality_participant/participant = participants[account]
		var/reward = participation_reward(participant)
		if(reward)
			store.award_rcp(account, reward, round_token)
	for(var/client/player as anything in GLOB.clients)
		if(participants[player.ckey])
			to_chat(player, span_notice("You can now commend one player through OOC → Commend player. Use Player quality to see your PQ, RCP, Karma and Respect."))

/datum/controller/subsystem/player_quality/proc/can_vote(account, recipient)
	account = ckey(account)
	recipient = ckey(recipient)
	var/datum/quality_participant/voter = participants[account]
	var/datum/quality_participant/recipient_participant = participants[recipient]
	return store && round_ended && voter?.active_time >= 5 MINUTES && recipient_participant?.active_time >= 5 MINUTES && account != recipient && !voters[account]

/datum/controller/subsystem/player_quality/proc/submit_vote(account, recipient)
	if(!can_vote(account, recipient))
		return FALSE
	// Reserve before any persistence or UI work; multiple dialogs cannot double-vote.
	voters[ckey(account)] = TRUE
	store.commend(recipient, account)
	log_game("PQ: [ckey(account)] commended [ckey(recipient)].")
	return TRUE

GAME_VERB(/client, commend_player, "Commend player", "OOC")
	var/datum/quality_participant/voter = SSplayer_quality.participants[ckey]
	if(!SSplayer_quality.store || !SSplayer_quality.round_ended || !voter || voter.active_time < 5 MINUTES || SSplayer_quality.voters[ckey])
		to_chat(src, span_warning("After five active minutes of play, you may commend one other eligible participant after the round ends."))
		return
	var/list/choices = list()
	var/index = 0
	for(var/account in SSplayer_quality.participants)
		if(account == ckey)
			continue
		var/datum/quality_participant/participant = SSplayer_quality.participants[account]
		if(participant.active_time < 5 MINUTES)
			continue
		choices["[participant.character_name] ([++index])"] = account
	if(!length(choices))
		to_chat(src, span_warning("There are no other eligible participants to commend."))
		return
	var/selection = tgui_input_list(mob, "Who contributed to your experience this round?", "Commend a player", choices)
	if(!selection)
		return
	if(SSplayer_quality.submit_vote(ckey, choices[selection]))
		to_chat(src, span_notice("Your commendation has been recorded."))

GAME_VERB(/client, player_quality, "Player quality", "OOC")
	if(!SSplayer_quality.store)
		return
	var/list/record = SSplayer_quality.store.read(ckey)
	var/cap = respect_age_cap(ckey)
	var/kindred_access = cap < 0 ? "Kindred require [CONFIG_GET(number/respect_fledgling_threshold)] Respect; mortals and ghouls remain available." : "Kindred age available: up to [cap] years since Embrace."
	var/garou_cap = respect_garou_rank_cap(ckey)
	var/garou_access = garou_cap < 0 ? "Garou require [CONFIG_GET(number/respect_garou_cub_threshold)] Respect; kinfolk remain available." : "Garou rank available: up to [fera_rank_name(garou_cap, SPLAT_GAROU)]."
	to_chat(src, span_notice("Player Quality: [record["pq"]]. Round Contribution Points: [record["rcp"]] (Respect contribution [record["rcp"] / 4]). Karma: [record["karma"]]. Respect: [round(SSplayer_quality.store.respect(ckey), 0.01)]. [kindred_access] [garou_access]"))

ADMIN_VERB(adjust_player_quality, R_ADMIN, "Adjust player quality", "View or adjust an account's PQ, RCP or Karma with an audited reason.", ADMIN_CATEGORY_GAME)
	if(!SSplayer_quality.store)
		return
	var/account = ckey(tgui_input_text(user.mob, "Account ckey", "Adjust progression"))
	if(!account)
		return
	var/list/record = SSplayer_quality.store.read(account)
	to_chat(user, span_notice("[account]: PQ [record["pq"]], RCP [record["rcp"]], Karma [record["karma"]], Respect [round(SSplayer_quality.store.respect(account), 0.01)]. Cancel to finish viewing."))
	var/metric = tgui_input_list(user.mob, "Score to adjust", "Adjust progression", list("pq", "rcp", "karma"))
	if(!metric)
		return
	var/amount = tgui_input_number(user.mob, "[metric] change (negative values remove points)", "Adjust progression")
	if(isnull(amount))
		return
	var/reason = tgui_input_text(user.mob, "Reason for adjustment", "Adjust progression", max_length = 500)
	if(!reason || !check_rights_for(user, R_ADMIN))
		return
	SSplayer_quality.store.admin_adjust(account, amount, user.ckey, reason, metric)
